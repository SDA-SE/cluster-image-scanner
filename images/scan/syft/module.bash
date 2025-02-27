#!/bin/bash

set -e

# shellcheck source=../../base/scan-common.bash
source /clusterscanner/scan-common.bash

scan_result_pre

echo "Starting Syft with parameter '$*'"
/syft "$@"
ls -la /clusterscanner/data
if ! [ -f /clusterscanner/data/bom.json ]; then
  echo  "/clusterscanner/data/bom.json doesn't exists"
  exit 2
fi
scan_result_post

exit  0
