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

scan_result_pre

_shell_found=0

for sh in "bin/sh$" "bin/bash$" "bin/dash$" "bin/zsh$" "bin/ash$"; do
    if tar -tf "${IMAGE_TAR_PATH}" | grep -q ${sh}; then
        _sh_name=$(echo "${sh}" | rev | cut -c2- | rev)
        echo "${_sh_name} found"
        JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ".shells += [\"${_sh_name}\"]")
        _shell_found=1
    fi
done

if [[ ${_shell_found} -eq 1 ]]; then
    cp /clusterscanner/distroless.json "${ARTIFACTS_PATH}/distroless.json"
    #infoText should be part of the environment at this point. Failing otherwise
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": true, \"infoText\": \"${infoText:?}\"}")
else
    JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": false}")
fi

scan_result_post

exit  0
