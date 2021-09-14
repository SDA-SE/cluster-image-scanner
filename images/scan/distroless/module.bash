#!/bin/bash

set -e
# checks if an image appears to be distroless
# by looking for a shell
#
# Usage example
# export ARTIFACTS_PATH=/path/to/output/dir"
# ./module.bash

source /clusterscanner/scan-common.bash

scan_result_pre

_shell_found=0
potentialBashs=("bin/sh" "bin/bash" "bin/dash" "bin/zsh" "bin/ash")
for sh in ${potentialBashs[@]}; do
    if [[ -e "${IMAGE_UNPACKED_DIRECTORY}/${sh}" ]]; then
      echo $sh
        echo "${sh} found"
        JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ".shells += [\"${sh}\"]")
        _shell_found=1
    fi
done

if [[ ${_shell_found} -eq 1 ]]; then
    cp /clusterscanner/distroless.csv "${ARTIFACTS_PATH}/distroless.csv"
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": true, \"infoText\": \"${infoText}\"}")
else
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": false}")
fi

scan_result_post

exit  0
