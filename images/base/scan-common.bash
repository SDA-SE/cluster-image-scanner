#!/bin/bash

function scan_result_post {
  JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"finishedAt\": \"$(date --rfc-3339=ns)\"}")
  cat <<<"$(echo "{}" | jq ".\"${MODULE_NAME}\" = $(echo "${JSON_RESULT}")")" > "${ARTIFACTS_PATH}/module_${MODULE_NAME}.json"
  echo "${JSON_RESULT}"
}

function scan_result_pre {
  if [ "${RESULT_CACHING_HOURS}" == "" ]; then RESULT_CACHING_HOURS=4; fi
  RESULT_CACHING_MIN=$( expr ${RESULT_CACHING_HOURS} \* 60)
  JSON_RESULT=$(echo "{}" | jq -Sc ".+= {\"startedAt\": \"$(date --rfc-3339=ns)\"}")
  echo "mkdir ${ARTIFACTS_PATH}"
  mkdir -p "${ARTIFACTS_PATH}" || true
  RESULT_FILE="${ARTIFACTS_PATH}/module_${MODULE_NAME}.json"
  if [ -f "${RESULT_FILE}" ] && [[ $(find "${RESULT_FILE}" -mmin -${RESULT_CACHING_MIN} -print) ]]; then
    echo "Scan has been performed, already, using old result"
    JSON_RESULT=$(cat "${RESULT_FILE}")
    scan_result_post
    exit 0
  fi
}

