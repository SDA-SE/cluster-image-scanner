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
  if [ "${IS_SCAN}" == "true" ];then
    if [ "${RESULT_CACHING_HOURS}" == "" ]; then RESULT_CACHING_HOURS=4; fi
    RESULT_CACHING_MIN=$( expr ${RESULT_CACHING_HOURS} \* 60)

    RESULT_FILE="${ARTIFACTS_PATH}/module_${MODULE_NAME}.json"
    if [ -f "${RESULT_FILE}" ]; then
      lastStatus=$(cat "${RESULT_FILE}" | jq -r '.["'${MODULE_NAME}'"] | .status' 2>/dev/null || true)
      if [ "${lastStatus}" != "completed" ]; then
        echo "lastStatus: ${lastStatus}"
        echo "Removing ${ARTIFACTS_PATH}/* because last scan is not 'completed' (e.g. skipped, failed)"
        rm "${ARTIFACTS_PATH}/*"
      fi
      if [[ $(find "${RESULT_FILE}" -mmin -${RESULT_CACHING_MIN} -print 2>/dev/null) ]]; then
        echo "Scan has been performed, already, using old result (RESULT_CACHING_MIN ${RESULT_CACHING_MIN})"
        IS_USE_CACHE=true
        JSON_RESULT=$(cat "${RESULT_FILE}" | jq ".\"${MODULE_NAME}\"")
        scan_result_post
        exit 0
      fi
    fi
  fi
  JSON_RESULT=$(echo "{}" | jq -Sc ".+= {\"startedAt\": \"$(date --rfc-3339=ns)\"}")
  echo "mkdir ${ARTIFACTS_PATH}"
  mkdir -p "${ARTIFACTS_PATH}" || true
}

