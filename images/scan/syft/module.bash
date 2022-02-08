#!/bin/bash

set -e
source /clusterscanner/scan-common.bash
scan_result_pre

/syft "$@"

scan_result_post

exit  0
