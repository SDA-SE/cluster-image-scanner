#!/bin/bash

set -xe
source /clusterscanner/scan-common.bash
scan_result_pre

echo "Starting Syft with parameter '$@'"
/syft "$@"

scan_result_post

exit  0
