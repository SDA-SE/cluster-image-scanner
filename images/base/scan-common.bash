#!/bin/bash

#echo "IMAGE: ${IMAGE}, IMAGE_ID: ${IMAGE_ID}"

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
    if [ $(echo "${IMAGE}" | sed 's#/.*##' | tr ':' '\n' | wc -l) -ne 1 ]; then # no port
      field=2
    fi
    export IMAGE_NAME=$(echo "${IMAGE}" | cut -d: -f${field})
    export IMAGE_NAME_CLEANED=$(echo "${IMAGE_NAME}" | sed -e "s#/#__#g")
    if [ $(echo "${IMAGE}" | sed 's#/.*##' | tr ':' '\n' | wc -l) -eq 1 ]; then # no port
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


function get_template {
cat <<"EOF"
{
    "findings": [
        {
            "date": "",
            "title": "",
            "severity": "",
            "description": {
                "infoText": "",
                "image": "",
                "cluster": "",
                "namespace": ""
            },
            "mitigation": "",
            "impact": "",
            "references": ""
        }
    ]
}
EOF
}


function add_json_field {

  if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    >&2 echo "${0}(): ERROR: called with invalid number of parameters"
    return 1
  fi

  local -r field=${1:?"${0}(): ERROR: Missing field name"}
  local -r value=${2:?"${0}(): ERROR: Missing value"}
  local -r json=${3:?"${0}(): ERROR: Missing input"}
  local    parent="${4:-nil}"

  if [ -z "${json}" ]; then 
    >&2 echo "${0}(): ERROR: missing input JSON"
    return 1
  fi
  
  if ! jq <<< "$json" &>/dev/null; then
    >&2 echo "${0}(): ERROR: input is not valid JSON"
    return 1
  fi

  if [ "${parent}" != "nil" ]; then
    parent=".${parent}"
  else 
    parent=''
  fi
  
  selector=".findings[]${parent}.${field}"

  if ! jq -e "$selector" <<< "$json" >> /dev/null; then
    >&2 echo "${0}(): ERROR: invalid selector: ${selector}"
    return 1
  fi

  result=$(jq --arg "${field}" "${value}" \
    "${selector} = \$${field}" \
    <<< "$json")
  jq_res=$?

  if [ $jq_res -eq 0 ]; then
    echo "$result"
  elif [ $jq_res -eq 4 ]; then
    # return clean template with error code 4
    get_template
  else
    echo "$json"
  fi

  return $jq_res
}


function safe_write_to_file {
  local -r json=${1:?"${0}(): ERROR: Missing content"}
  local -r file=${2:?"${0}(): ERROR: Missing file"}

  if [ -z "${json}" ]; then
    >&2 echo "${0}(): ERROR: missing content"
    return 1
  fi

  if ! [ -f "${file}" ]; then
    >&2 echo "${0}(): ERROR: ${file} does not exist"
    return 1
  fi

  tmpfile=$(mktemp)

  if ! echo "$json" > "$tmpfile"; then
    >&2 echo "${0}(): ERROR: cannot write to $tmpfile" 
  fi
  mv "$tmpfile" "$file"
  rm "$tmpfile"
  return 0
}


##
#  Will convert a size unit that can be passed to clamscan to its value in bytes
#  valid units can be K, and M for kilobytes and megabytes, respectively.
# 
#  returns a byte value for input like 40M or 400K, or the input unchanged if 
#  the unit is not M or K. 
##
function size2bytes {
  local size="$1"
  local unit="${size: -1}"
  local num="${size%?}"
  
  case "$unit" in
    M)
      echo "$((num * 1024 * 1024))"
      ;;
    K)
      echo "$((num * 1024))"
      ;;
    *)
      echo "$1"
      ;;
  esac
}

##
#  Will return a size in kilobytes for any input in bytes.
#  Kilobyte sizes are ceil'd to resemble block size on a disk 
##
function b2kb {
  echo $((($1+1024-1)/1024))
}
