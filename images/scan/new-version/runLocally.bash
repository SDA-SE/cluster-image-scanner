#!/bin/bash

export IMAGE=quay.io/sdase/cluster-image-scanner-imagecollector:2.0.339 # last Version
export IMAGE=quay.io/sdase/cluster-image-scanner-imagecollector:1.9.9
export IMAGE=quay.io/sdase/cluster-image-scanner-imagecollector:2.0.338
export IMAGE=dexidp/dex:v2.29.0
export IMAGE_SCAN_POSITIVE_FILTER="quay.io/sdase/|dexidp/dex"
source env.bash
cp ../../base/scan-common.bash .

export ARTIFACTS_PATH="/tmp/cluster-image-scanner/scan-new-version"

./module.bash

rm scan-common.bash
