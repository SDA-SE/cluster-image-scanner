#!/bin/bash

set -e
# checks if an image appears to be distroless
# by looking for a shell
#
# Usage example
# export IMAGE_TAR_PATH=/path/to/image.tar"
# export ARTIFACTS_PATH=/path/to/output/dir"
# ./module.bash

source /clusterscanner/scan-common.bash

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
  distroPackageUpdateCommands=("apt.*upgrade" "yum.*update" "apk.*upgrade" "zypper.*update")
  imageHistory=$(skopeo inspect --config ${SKOPEO_INSPECT_PARAMETER} "docker://${IMAGE_BY_HASH}" | jq -r '.history')
  for updateCommand in ${distroPackageUpdateCommands[@]}; do
    if [ "${dt1}" == "" ] || [ "${dt1}" == "null" ]; then
      dt1=$(echo ${imageHistory} | jq -r '.[] | select(.created_by != null) | select(.created_by | match("'${updateCommand}'")) | .created' | tail -n 1)
      break
    fi
  done
  if [ "${dt1}" == "" ] || [ "${dt1}" == "null" ]; then
    dt1=$(echo ${imageHistory} | jq -r '.[0] | if has("created") then .created else if has("Created") then .Created else "NODATE" end end')
  fi
  sed -i 's#Image#BaseImage#g' /clusterscanner/lifetime.csv
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
if [[ "${dt1}" == "1970-01-01T00:00:00Z" ]]; then
    reproducibleBuild=true
fi
#\"reproducibleBuild\": ${reproducibleBuild},
JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"buildDate\": \"${dt1}\", \"maxAge\": ${MAX_IMAGE_LIFETIME_IN_DAYS}, \"age\": ${dDiff}, \"imageType\": \"${IMAGE_TYPE}\"}")

if [ "${dDiff}" -gt "${MAX_IMAGE_LIFETIME_IN_DAYS}" ]; then
    infoText="${IMAGE_TYPE} is ${dDiff} days old"
    if [[ ${reproducibleBuild} ]]; then
      infoText="Could not determine ${IMAGE_TYPE} age due to ${IMAGE_TYPE} creation date of 1970 (happens for reproducible builds)"
    fi
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": true, \"infoText\": \"${infoText}\"}")
    cp /clusterscanner/lifetime.csv "${ARTIFACTS_PATH}/lifetime.csv"
    sed -i "s/###INFOTEXT###/${infoText}/" "${ARTIFACTS_PATH}/lifetime.csv"
    sed -i "s/###SEVERITY###/Medium/" "${ARTIFACTS_PATH}/lifetime.csv"
    sed -i "s/###MAXLIFETIME###/${MAX_IMAGE_LIFETIME_IN_DAYS}/" "${ARTIFACTS_PATH}/lifetime.csv"
    sed -i "s/###BUILDDATE###/${dt1}/" "${ARTIFACTS_PATH}/lifetime.csv"
else
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": false}")
fi

scan_result_post

exit  0

