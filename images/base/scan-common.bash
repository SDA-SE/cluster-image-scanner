#!/bin/bash

function scan_result_post {
  if ${IS_USE_CACHE} ; then
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"cachedUsedAt\": \"$(date --rfc-3339=ns)\"}")
  else
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"finishedAt\": \"$(date --rfc-3339=ns)\"}")
  fi

  cat <<<"$(echo "{}" | jq ".\"${MODULE_NAME}\" = $(echo "${JSON_RESULT}")")" > "${ARTIFACTS_PATH}/module_${MODULE_NAME}.json"
  echo "${JSON_RESULT}"
}

IS_USE_CACHE=false
function scan_result_pre {
  if [ "${RESULT_CACHING_HOURS}" == "" ]; then RESULT_CACHING_HOURS=4; fi
  RESULT_CACHING_MIN=$( expr ${RESULT_CACHING_HOURS} \* 60)

  RESULT_FILE="${ARTIFACTS_PATH}/module_${MODULE_NAME}.json"
  if [ -f "${RESULT_FILE}" ]; then
    lastStatus=$(cat "${RESULT_FILE}" | jq -r ".${MODULE_NAME} | .status" || true)
    if [ "${lastStatus}" == "skipped" ] && [ "${IS_SCAN}" == "true" ]; then
      echo "Removing ${RESULT_FILE} because this scan changed from skip=true to skip=false"
      rm "${RESULT_FILE}"
    fi
    if [[ $(find "${RESULT_FILE}" -mmin -${RESULT_CACHING_MIN} -print) ]]; then
      echo "Scan has been performed, already, using old result"
      IS_USE_CACHE=true
      JSON_RESULT=$(cat "${RESULT_FILE}" | jq ".\"${MODULE_NAME}\"")
      scan_result_post
      exit 0
    fi
  fi
  JSON_RESULT=$(echo "{}" | jq -Sc ".+= {\"startedAt\": \"$(date --rfc-3339=ns)\"}")
  echo "mkdir ${ARTIFACTS_PATH}"
  mkdir -p "${ARTIFACTS_PATH}" || true
}

