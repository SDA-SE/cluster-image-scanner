#!/bin/bash
set -e

createJWT() {
  GITHUB_KEY_FILE_PATH="/etc/github/keyfile"
  if [ $( wc -l "${GITHUB_KEY_FILE_PATH}") -eq 0 ]; then
    echo "${GITHUB_KEY_FILE_PATH} is empty"
    exit 45
  fi

  # Static header fields.
  header='{"alg": "RS256"}'

  payload=$(
    cat <<EOF
{
    "iss": ${GITHUB_APP_ID}
}
EOF
  )
  payload=$(
    echo "${payload}" | jq --arg time_str "$(date +%s)" \
      '
        ($time_str | tonumber) as $time_num
        | .iat=$time_num
        | .exp=($time_num + 600)
        '
  )

  header_base64=$(echo -n "${header}" | jq -c . | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  payload_base64=$(echo -n "${payload}" | jq -c . | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

  header_payload=$(echo -n "${header_base64}.${payload_base64}")
  signature=$(echo -n "${header_payload}" | openssl dgst -binary -sha256 -sign "${GITHUB_KEY_FILE_PATH}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  export CLUSTER_SCAN_JWT="${header_payload}.${signature}"
}

githubAuth() {
  if [ -z "${GITHUB_APP_ID}" ]; then
    echo "ERROR: variable GITHUB_APP_ID is empty, exit"
    exit 1
  fi
  if [ -z "${GITHUB_INSTALLATION_ID}" ]; then
    echo "ERROR: variable GITHUB_INSTALLATION_ID is empty, exit"
    echo 'try       curl -H "Authorization: Bearer ##INSERT_CLUSTERSCANNER_JWT_HERE##" -H "Accept: application/vnd.github.machine-man-preview+json" https://api.github.com/app/installations | jq'
    exit 1
  fi

  createJWT

  echo "will fetch github_token with GITHUB_INSTALLATION_ID ${GITHUB_INSTALLATION_ID}"
  export GITHUB_TOKEN=$(curl -X POST -H "Authorization: Bearer ${CLUSTER_SCAN_JWT}" -H "Accept: application/vnd.github.machine-man-preview+json" "https://api.github.com/app/installations/${GITHUB_INSTALLATION_ID}/access_tokens" | jq '.token' | tr -d \")
  if [ "${GITHUB_TOKEN}" == "null" ]; then
    echo "GITHUB_TOKEN is null"
    exit 44
  fi
}

gitSshAuth() {
  SSH_TARGET_PATH="/home/code/.ssh"
  mkdir -p "${SSH_TARGET_PATH}"
  chmod 750 "${SSH_TARGET_PATH}"
  TARGET_SSH_KEY_PATH="${SSH_TARGET_PATH}/id_rsa"
  cat /.ssh/id_rsa/ssh-privatekey >${TARGET_SSH_KEY_PATH}

  if [ ! -e ${TARGET_SSH_KEY_PATH} ]; then
    echo "ERROR: Var TARGET_SSH_KEY_PATH is not set, exit"
    exit 1
  fi
  if [ -z "${GIT_REPOSITORY_PATH}" ]; then
    echo "ERROR: variable GIT_SSH_REPOSITORY is empty, exit"
    exit 1
  fi
  if [ -z "${GIT_SSH_REPOSITORY_HOST}" ]; then
    echo "ERROR: variable GIT_SSH_REPOSITORY_HOST is empty, exit"
    exit 1
  fi

  if [ $(grep -c 'END' "${TARGET_SSH_KEY_PATH}") -eq 0 ]; then
    echo "-----END OPENSSH PRIVATE KEY-----" >> "${TARGET_SSH_KEY_PATH}"
  else
    echo "" >> "${TARGET_SSH_KEY_PATH}"
  fi
  CLONE_URL="ssh://git@${GIT_SSH_REPOSITORY_HOST}${GIT_REPOSITORY_PATH}"
  _id=$(id -u)
  echo "openshift:x:${_id}:0:openshift user:/home/code:/sbin/nologin" >> /etc/passwd
  # for key generated with openssh version<7.6, see https://serverfault.com/questions/854208/ssh-suddenly-returning-invalid-format/960647
  _ssh_repository_host_no_port=$(echo "${GIT_SSH_REPOSITORY_HOST}" | sed 's#:.*##g')
  _ssh_repository_host_port=$(echo "${GIT_SSH_REPOSITORY_HOST}" | sed 's#.*:##g')

  ssh-keyscan -t rsa -p "${_ssh_repository_host_port}" -H "${_ssh_repository_host_no_port}" >> "${SSH_TARGET_PATH}/known_hosts"
  chmod 400 "${TARGET_SSH_KEY_PATH}"
}

gitAuth() {
  if [ "${GITHUB_REPOSITORY}" != "SET-ME" ]; then
    githubAuth
    CLONE_URL="https://x-access-token:${GITHUB_TOKEN}@${GITHUB_REPOSITORY}"
  elif [ "${GIT_SSH_REPOSITORY_HOST}" != "SET-ME" ]; then
    gitSshAuth
  else
    echo "ERROR: Git parameters are missing"
    exit 42
  fi
}

gitFetch() {
  rm -Rf /tmp/cluster-scan || true
  echo "CLONE_URL: ${CLONE_URL}"
  git clone "${CLONE_URL}" /tmp/cluster-scan
  echo "fetched"
}
