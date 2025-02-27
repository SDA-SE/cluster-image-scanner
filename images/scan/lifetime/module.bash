#!/bin/bash

set -e
# checks if an image appears to be distroless
# by looking for a shell
#
# Usage example
# export IMAGE_TAR_PATH=/path/to/image.tar"
# export ARTIFACTS_PATH=/path/to/output/dir"
# ./module.bash

# shellcheck source=../../base/scan-common.bash
source /clusterscanner/scan-common.bash

JSONFILE="${ARTIFACTS_PATH}/lifetime.json"

scan_result_pre

echo "Analysing IMAGE_BY_HASH: ${IMAGE_BY_HASH}"
skopeo inspect ${SKOPEO_INSPECT_PARAMETER} "docker://${IMAGE_BY_HASH}" > /dev/null || exit=true
if [ "${exit}" == "true" ]; then
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"failed\"}")
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ".errors += [{\"errorText\": \"skopeo inspect failed for image\", \"command\": \"skopeo inspect docker://${IMAGE_BY_HASH}\"}]")
    scan_result_post
    exit 1
fi

# build date
dt1=""
if [ "${IS_BASE_IMAGE_LIFETIME_SCAN}" == "true" ]; then
  # apt.* includes apt-get, apt.*upgrade includes dist-upgrade
  distroPackageUpdateCommands=("apt.*upgrade" "yum.*update" "apk.*upgrade" "zypper.*update" "dnf.*update")
  imageHistory=$(skopeo inspect --config ${SKOPEO_INSPECT_PARAMETER} "docker://${IMAGE_BY_HASH}" | jq -r '.history')
  for updateCommand in "${distroPackageUpdateCommands[@]}"; do
    if [ "${dt1}" == "" ] || [ "${dt1}" == "null" ]; then
      dt1=$(echo ${imageHistory} | jq -r '.[] | select(.created_by != null) | select(.created_by | match("'${updateCommand}'")) | .created' | tail -n 1)
      if [ "${dt1}" != "" ]; then
              break
      fi
    fi
  done
  if [ "${dt1}" == "" ] || [ "${dt1}" == "null" ]; then
    dt1=$(echo ${imageHistory} | jq -r '.[0] | if has("created") then .created else if has("Created") then .Created else "NODATE" end end')
  fi
  IMAGE_TYPE="BaseImage"
else
  dt1=$(skopeo inspect ${SKOPEO_INSPECT_PARAMETER} "docker://${IMAGE_BY_HASH}" | jq -r 'if has("created") then .created else if has("Created") then .Created else "NODATE" end end' | sed 's/"//g')
  IMAGE_TYPE="Image"
fi
echo $dt1



# check for invalid dates
if [[ "${dt1}" == "NODATE" ]]; then
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"failed\", \"infoText\": \"${IMAGE_TYPE} build date invalid\"}")
    scan_result_post
    exit 1
fi
# Compute the seconds since epoch for date 1
t1=$(date --date="${dt1}" +%s)

# Current date
dt2=$(date +%Y-%m-%d\ %H:%M:%S)
# Compute the seconds since epoch for date 2
t2=$(date --date="${dt2}" +%s)

# difference in dates in seconds
tDiff="$(( t2-t1 ))"
# hour difference
hDiff="$(( tDiff/3600 ))" || true
# day difference
dDiff="$(( hDiff/24 ))" || true
echo "dDiff: ${dDiff}"
reproducibleBuild=false

MIN_IMAGE_LIFETIME_IN_DAYS_TO_BE_REPRODUCIBLE=$((MIN_IMAGE_LIFETIME_IN_YEARS_TO_BE_REPRODUCIBLE * 365))
if [ "${dDiff}" -gt "${MIN_IMAGE_LIFETIME_IN_DAYS_TO_BE_REPRODUCIBLE}" ]; then
  reproducibleBuild=true
fi
JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"buildDate\": \"${dt1}\", \"maxAge\": ${MAX_IMAGE_LIFETIME_IN_DAYS}, \"age\": ${dDiff}, \"reproducibleBuild\": ${reproducibleBuild}, \"imageType\": \"${IMAGE_TYPE}\"}")

if [ "${dDiff}" -gt "${MAX_IMAGE_LIFETIME_IN_DAYS}" ]; then
  infoText="Image is too old"
  if [ "${reproducibleBuild}"  == "true" ]; then
    infoText="Could not determine ${IMAGE_TYPE} age due to ${IMAGE_TYPE} creation date of 1970 (happens for reproducible builds)"
  fi
  JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": true, \"infoText\": \"${infoText}\"}")
  cp /clusterscanner/lifetime.json "$JSONFILE"
  originalReferenceText=$(jq '.findings[].references')
  references=$(cat <<EOF
${IMAGE_TYPE} is ${dDiff} days old.
Builddate: ${dt1}
${originalReferenceText}
EOF
    )

  JSON=$(<"$JSONFILE")
  JSON=$(add_json_field references "$references" "$JSON")
  if [ "${reproducibleBuild}"  == "true" ]; then
    JSON=$(add_json_field title "${IMAGE_TYPE} Age > ${MAX_IMAGE_LIFETIME_IN_DAYS} Days due to reproducible build" "$JSON")
    JSON=$(add_json_field severity "Low" "$JSON")
  else
    JSON=$(add_json_field title "${IMAGE_TYPE} Age > ${MAX_IMAGE_LIFETIME_IN_DAYS} Days" "$JSON")
  fi

  if [ -z "$JSON" ]; then
    echo "failed to create JSON results"
    exit 1
  else
    echo "$JSON" > "$JSONFILE"
  fi
else
  JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": false}")
fi

scan_result_post

exit  0
