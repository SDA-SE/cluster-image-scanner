#!/bin/bash

set -e

# shellcheck source=../../base/scan-common.bash
source /clusterscanner/scan-common.bash

scan_result_pre
echo "Checking image exists ${IMAGE_BY_HASH}"
if [ "${SKOPEO_INSPECT_PARAMETER}" != "" ]; then
  SKOPEO_CONFIG="--config \"${SKOPEO_INSPECT_PARAMETER}\""
else
  SKOPEO_CONFIG=""
fi
skopeo inspect ${SKOPEO_CONFIG} "docker://${IMAGE_BY_HASH}" > /dev/null || exit="true"
if [ "${exit}" == "true" ]; then
    echo "skopeo inspect ${SKOPEO_CONFIG} \"docker://${IMAGE_BY_HASH}\""
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"failed\"}")
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ".errors += [{\"errorText\": \"skopeo inspect failed for image\", \"command\": \"skopeo inspect docker://${IMAGE_BY_HASH}\"}]")
    scan_result_post
    exit 1
fi

echo "get User from docker manifest"
_imageUser=$(skopeo inspect "${SKOPEO_CONFIG}" docker://"${IMAGE_BY_HASH}" | jq '.config.User // "ROOT"' | tr -d \")

if [[ "xX${_imageUser,,}" =~ ^xX(root|0) ]]; then
    cp /clusterscanner/runAsRoot.json "${ARTIFACTS_PATH}/runAsRoot.json"
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc  ". += {\"status\": \"completed\", \"finding\": true, \"infoText\": \"Image is potentially running as root\"}")
else
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc  ". += {\"status\": \"completed\", \"finding\": false}")
fi

scan_result_post

exit  0
