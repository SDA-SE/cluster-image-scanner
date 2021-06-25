#!/bin/bash

function scan_result_pre {
  JSON_RESULT=$(echo "{}" | jq -Sc ".+= {\"startedAt\": \"$(date --rfc-3339=ns)\"}")
  echo "mkdir ${ARTIFACTS_PATH}"
  mkdir -p "${ARTIFACTS_PATH}"
}

function scan_result_post {
  JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"finishedAt\": \"$(date --rfc-3339=ns)\"}")
  cat <<<"$(echo "{}" | jq ".\"${MODULE_NAME}\" = $(echo "${JSON_RESULT}")")" > "${ARTIFACTS_PATH}/module_${MODULE_NAME}.json"
  echo "${JSON_RESULT}"
}
