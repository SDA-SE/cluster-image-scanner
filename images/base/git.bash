#!/bin/bash
set -e

cd ${GIT_REPOSITORY_PATH} && git config user.email "" && git config user.name "ClusterImageScanner"

if [ $(echo "${GIT_REPOSITORY}" | grep -c "ssh://") -eq 1 ]; then
  export GIT_REPOSITORY_PATH=$(echo ${GIT_REPOSITORY} | sed 's#.*@##g')
  export GIT_REPOSITORY_PATH=$(echo ${GIT_REPOSITORY_PATH#*/})
  export GIT_REPOSITORY_PATH="/${GIT_REPOSITORY_PATH}"
  export GIT_SSH_REPOSITORY_HOST=$(echo ${GIT_REPOSITORY} | sed 's#.*@##g' | sed 's#/.*##g')
fi

createJWT() {
  echo "Creating JWT"
  if [ "${GH_KEY_FILE_PATH}" == "" ]; then
    export GH_KEY_FILE_PATH="/etc/github/keyfile"
  fi
  if [ ! -e "${GH_KEY_FILE_PATH}" ] || [ "$(wc -l "${GH_KEY_FILE_PATH}")" == "" ]; then
    echo "${GH_KEY_FILE_PATH} is empty"
    exit 45
  fi

  # Static header fields.
  header='{"alg": "RS256"}'

  payload=$(
    cat <<EOF
{
    "iss": ${GH_APP_ID}
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
  echo "GH_KEY_FILE_PATH ${GH_KEY_FILE_PATH}:"
  ls -la ${GH_KEY_FILE_PATH}
  signature=$(echo -n "${header_payload}" | openssl dgst -binary -sha256 -sign "${GH_KEY_FILE_PATH}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  export CLUSTER_SCAN_JWT="${header_payload}.${signature}"
  sleep 1 # time screw
}

githubAuth() {
  if [ -z "${GH_APP_ID}" ]; then
    echo "ERROR: variable GH_APP_ID is empty, exit"
    exit 1
  fi
  if [ -z "${GH_INSTALLATION_ID}" ]; then
    echo "ERROR: variable GH_INSTALLATION_ID is empty, exit"
    echo 'try       curl -H "Authorization: Bearer ##INSERT_CLUSTERSCANNER_JWT_HERE##" -H "Accept: application/vnd.github.machine-man-preview+json" https://api.github.com/app/installations | jq'
    exit 1
  fi

  createJWT

  echo "will fetch GH_TOKEN with GH_INSTALLATION_ID ${GH_INSTALLATION_ID}"
  # shellcheck disable=SC2155
  export GH_TOKEN=$(curl -X POST -H "Authorization: Bearer ${CLUSTER_SCAN_JWT}" -H "Accept: application/vnd.github.machine-man-preview+json" "https://api.github.com/app/installations/${GH_INSTALLATION_ID}/access_tokens" | jq '.token' | tr -d \")
  if [ "${GH_TOKEN}" == "null" ]; then
    echo "GH_TOKEN is null"
    exit 44
  fi
}

gitSshAuth() {
  SSH_TARGET_PATH="$HOME/.ssh"
  mkdir -p "${SSH_TARGET_PATH}"
  chmod -R 770 "${SSH_TARGET_PATH}"
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
  if [ "${GIT_REPOSITORY}" != "SET-ME" ] && [ "${GH_APP_ID}" != "" ] && [ "${GH_INSTALLATION_ID}" != "" ]; then
    echo "github detected"
    githubAuth
    CLONE_URL="https://x-access-token:${GH_TOKEN}@${GIT_REPOSITORY}"
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
  #echo "CLONE_URL: ${CLONE_URL}"
  git clone "${CLONE_URL}" /tmp/clusterscanner-remote
  echo "fetched to /tmp/clusterscanner-remote"
}
