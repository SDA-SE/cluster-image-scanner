#!/bin/bash
set -e

createJWT() {
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

sp_authorize() {
    if [ "${GITHUB_APP_ID}" == "" ]; then
      echo "GITHUB_APP_ID is empty, not creating github token"
      return 1
    fi
    createJWT
    createdGithubToken=true
    GITHUB_TOKEN=$(curl -X POST -H "Authorization: Bearer ${CLUSTER_SCAN_JWT}" -H "Accept: application/vnd.github.machine-man-preview+json" https://api.github.com/app/installations/"${GITHUB_INSTALLATION_ID}"/access_tokens | jq '.token' | tr -d \" || createdGithubToken=false)
    if ${createdGithubToken} ]; then
      echo "Couldn't create GITHUB_TOKEN"
      return 1
    else
      echo "Created GITHUB_TOKEN"
      return 0
    fi
}

sp_getfile() {
    src=$1
    dst=$2
    accept=$3

    if [ "${accept}" == "" ]; then
      accept="application/vnd.github.v4.raw"
    fi

    command="curl -L --output \"${dst}\" --header \"Accept: ${accept}\""

    if [ "${GITHUB_TOKEN}" != "" ]; then
      command="${command} --header \"Authorization: token ${GITHUB_TOKEN}\""
    fi
    command="${command} \"${src}\""
    echo "debug: Using command ${command}"
    eval ${command}
}
