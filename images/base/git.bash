#!/bin/bash
set -e
git config --global user.email ""
git config --global user.name "ClusterImageScanner"
createJWT() {
  if [ "${GITHUB_KEY_FILE_PATH}" == "" ]; then
    export GITHUB_KEY_FILE_PATH="/etc/github/keyfile"
  fi
  if [ ! -e "${GITHUB_KEY_FILE_PATH}" ] || [ "$(wc -l "${GITHUB_KEY_FILE_PATH}")" == "" ]; then
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
  # shellcheck disable=SC2155
  export GITHUB_TOKEN=$(curl -X POST -H "Authorization: Bearer ${CLUSTER_SCAN_JWT}" -H "Accept: application/vnd.github.machine-man-preview+json" "https://api.github.com/app/installations/${GITHUB_INSTALLATION_ID}/access_tokens" | jq '.token' | tr -d \")
  if [ "${GITHUB_TOKEN}" == "null" ]; then
    echo "GITHUB_TOKEN is null"
    exit 44
  fi
}

gitSshAuth() {
  SSH_TARGET_PATH="$HOME/.ssh"
  mkdir -p "${SSH_TARGET_PATH}"
  chmod 770 "${SSH_TARGET_PATH}"
  TARGET_SSH_KEY_PATH="${SSH_TARGET_PATH}/id_rsa"

  if [ -e /.ssh/id_rsa/ssh-privatekey ]; then
    cat /.ssh/id_rsa/ssh-privatekey > "${TARGET_SSH_KEY_PATH}"
  elif [ -e /clusterscanner/github/github_private_key.pem ]; then # same path is used for github private key
    cat /clusterscanner/github/github_private_key.pem > "${TARGET_SSH_KEY_PATH}"
  fi
  if [ $(wc -l "${TARGET_SSH_KEY_PATH}" | awk '{print $1}') -eq 0 ]; then
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
  id=$(id -u)
  echo "openshift:x:${id}:0:openshift user:/home/code:/sbin/nologin" >> /etc/passwd || true
  # for key generated with openssh version<7.6, see https://serverfault.com/questions/854208/ssh-suddenly-returning-invalid-format/960647
  # shellcheck disable=SC2001
  _ssh_repository_host_no_port=$(echo "${GIT_SSH_REPOSITORY_HOST}" | sed 's#:.*##g')
  # shellcheck disable=SC2001
  _ssh_repository_host_port=$(echo "${GIT_SSH_REPOSITORY_HOST}" | sed 's#.*:##g')

  ssh-keyscan -t rsa -p "${_ssh_repository_host_port}" -H "${_ssh_repository_host_no_port}" >> "${SSH_TARGET_PATH}/known_hosts"
  chmod 400 "${TARGET_SSH_KEY_PATH}"
}

gitAuth() {
  if [ "${GITHUB_REPOSITORY}" != "SET-ME" ] && [ "${GITHUB_APP_ID}" != "" ] ; then
    echo "github detected"
    githubAuth
    CLONE_URL="https://x-access-token:${GITHUB_TOKEN}@${GITHUB_REPOSITORY}"
  elif [ "${GIT_SSH_REPOSITORY_HOST}" != "SET-ME" ]; then
    echo "ssh detected"
    gitSshAuth
  else
    echo "ERROR: Git parameters are missing"
    exit 42
  fi
}

gitFetch() {
  rm -Rf /tmp/clusterscanner-remote || true
  echo "CLONE_URL: ${CLONE_URL}"
  git clone "${CLONE_URL}" /tmp/clusterscanner-remote
  echo "fetched to /tmp/clusterscanner-remote"
}
