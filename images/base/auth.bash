#!/bin/bash
set -e

createJWT() {
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
    echo "Creating Signature with header_payload ${header_payload} AND GH_KEY_FILE_PATH: $GH_KEY_FILE_PATH"
    signature=$(echo -n "${header_payload}" | openssl dgst -binary -sha256 -sign "${GH_KEY_FILE_PATH}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    export CLUSTER_SCAN_JWT="${header_payload}.${signature}"
}

sp_authorize() {
    if [ "${GH_APP_ID}" == "" ]; then
      echo "GH_APP_ID is empty, not creating github token"
      return 1
    fi
    createJWT
    echo "Creating GH_TOKEN"
    GH_TOKEN=$(curl -X POST -H "Authorization: Bearer ${CLUSTER_SCAN_JWT}" -H "Accept: application/vnd.github.machine-man-preview+json" https://api.github.com/app/installations/"${GH_INSTALLATION_ID}"/access_tokens | jq '.token' | tr -d \" || true)
    if [ ${GH_TOKEN} == "ghs*" ]; then
      echo "Created GH_TOKEN"
      return 0
    else
      echo "Couldn't create GH_TOKEN"
      echo "${GH_TOKEN}"
      return 1
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

    if [ "${GH_TOKEN}" != "" ]; then
      command="${command} --header \"Authorization: token ${GH_TOKEN}\""
    fi
    command="${command} \"${src}\""
    echo "debug: Using command ${command}"
    eval ${command}
}
