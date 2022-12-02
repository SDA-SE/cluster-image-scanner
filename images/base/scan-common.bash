#!/bin/bash

echo "IMAGE: ${IMAGE}, IMAGE_ID: ${IMAGE_ID}"

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
  echo "MODULE_NAME: ${MODULE_NAME}"
  if [ "${IS_SCAN}" == "true" ]; then
    if [ "${RESULT_CACHING_HOURS}" == "" ]; then RESULT_CACHING_HOURS=4; fi
    RESULT_CACHING_MIN=$( expr ${RESULT_CACHING_HOURS} \* 60)

    RESULT_FILE="${ARTIFACTS_PATH}/module_${MODULE_NAME}.json"
    if [ -f "${RESULT_FILE}" ]; then
      lastStatus=$(cat "${RESULT_FILE}" | jq -r '.["'${MODULE_NAME}'"] | .status' 2>/dev/null || true)
      if [ "${lastStatus}" != "completed" ]; then
        echo "lastStatus: ${lastStatus}"
        echo "Removing ${ARTIFACTS_PATH}/* because last scan is not 'completed' (e.g. skipped, failed)"
        rm "${ARTIFACTS_PATH}"/* || echo "ERROR: No artifacts are there" # true: for the case that no files are there
      fi
      if [[ $(find "${RESULT_FILE}" -mmin -${RESULT_CACHING_MIN} -print 2>/dev/null) ]]; then
        echo "Scan has been performed, already, using old result (RESULT_CACHING_MIN ${RESULT_CACHING_MIN}), ARTIFACTS_PATH ${ARTIFACTS_PATH}:"
        ls -la "${ARTIFACTS_PATH}"
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

function parse_and_set_image_variables {
    field=1
    if [ $(echo {{ workflow.parameters.image }} | sed 's#/.*##' | tr ':' '\n' | wc -l) -eq 1 ]; then # no port
      field=2
    fi
    export IMAGE_NAME=$(echo "${IMAGE}" | cut -d: -f${field})
    export IMAGE_NAME_CLEANED=$(echo "${IMAGE_NAME}" | sed -e "s#/#__#g")
    if [ $(echo {{ workflow.parameters.image }} | sed 's#/.*##' | tr ':' '\n' | wc -l) -eq 1 ]; then # no port
      field=2
    else
      field=3
    fi
    export IMAGE_TAG=$(echo "${IMAGE}" | cut -d: -f${field})
    if [ "${IMAGE_ID}" == "" ]; then
        IMAGE_ID="${IMAGE_BY_HASH}"
    fi
    export IMAGE_HASH=$(echo "${IMAGE_ID}" | sed -e "s#/#__#g" | cut -d: -f${field})
}










