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
skopeo inspect docker://"${IMAGE_BY_HASH}" > /dev/null || exit=true
if [ "${exit}" == "true" ]; then
    JSON_RESULT=$(echo ${JSON_RESULT} | jq -Sc ". += {\"status\": \"failed\"}")
    JSON_RESULT=$(echo ${JSON_RESULT} | jq -Sc ".errors += [{\"errorText\": \"skopeo inspect failed for image\", \"command\": \"skopeo inspect docker://${IMAGE_BY_HASH}\"}]")
    scan_result_post
    exit 1
fi

# build date
dt1=$(skopeo inspect docker://"${IMAGE_BY_HASH}" | jq 'if has("created") then .created else if has("Created") then .Created else "NODATE" end end' | sed 's/"//g')


# check for invalid dates
if [[ "xX${dt1}" == "xXNODATE" ]]; then
    JSON_RESULT=$(echo ${JSON_RESULT} | jq -Sc ". += {\"status\": \"failed\", \"infoText\": \"Image build date invalid\"}")
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
let "tDiff=${t2}-${t1}"
# hour difference
let "hDiff=${tDiff}/3600" || true

# day difference
let "dDiff=${hDiff}/24" || true

JSON_RESULT=$(echo ${JSON_RESULT} | jq -Sc ". += {\"buildDate\": \"${dt1}\", \"maxAge\": ${MAX_IMAGE_LIFETIME_IN_DAYS}, \"age\": ${dDiff}}")

if [ ${dDiff} -gt "${MAX_IMAGE_LIFETIME_IN_DAYS}" ]; then
    infoText="Image is too old"
    if [[ "${dt1}" == "1970-01-01T00:00:00Z" ]]; then
      infoText="Could not determine image age due to image creation date of 1970 (happens for reproducible builds)"
    fi
    JSON_RESULT=$(echo ${JSON_RESULT} | jq -Sc ". += {\"status\": \"completed\", \"finding\": true, \"infoText\": \"${infoText}\"}")
    cp /clusterscanner/ddTemplate.csv "${ARTIFACTS_PATH}/lifetime.csv"
    sed -i "s/###INFOTEXT###/${infoText}/" "${ARTIFACTS_PATH}/lifetime.csv"
    sed -i "s/###SEVERITY###/High/" "${ARTIFACTS_PATH}/lifetime.csv"
    sed -i "s/###MAXLIFETIME###/${MAX_IMAGE_LIFETIME_IN_DAYS}/" "${ARTIFACTS_PATH}/lifetime.csv"
    sed -i "s/###BUILDDATE###/${dt1}/" "${ARTIFACTS_PATH}/lifetime.csv"
else
    JSON_RESULT=$(echo ${JSON_RESULT} | jq -Sc ". += {\"status\": \"completed\", \"finding\": false}")
fi

scan_result_post

exit  0
