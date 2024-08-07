#!/bin/bash
set -e

export HOME=/clusterscanner
export RESOURCE_PATH="$HOME"

echo "source env"
source "${HOME}/env.bash"

source "${HOME}/check-required-env.bash"

echo "debug: IS_SCAN: ${IS_SCAN}"
if [ "${IS_SCAN}" == "false" ]; then
  source "${RESOURCE_PATH}/scan-common.bash"
  message="Skipping ${MODULE_NAME} due to configuration in json from image collector"
  echo "${message}"
  scan_result_pre
  JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"skipped\", \"infoText\": \"${message}\"}")
  scan_result_post
  exit 0
fi

source "${HOME}/cache.bash"

echo "Run module ${MODULE_NAME}"
source "${HOME}/module.bash"
