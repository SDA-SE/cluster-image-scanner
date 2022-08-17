#!/bin/bash

export IMAGE=quay.io/sdase/cluster-image-scanner-imagecollector:2.0.339 # last Version
export IMAGE=quay.io/sdase/cluster-image-scanner-imagecollector:1.9.9
export IMAGE=quay.io/sdase/cluster-image-scanner-imagecollector:2.0.338
export IMAGE=dexidp/dex:v2.29.0
export IMAGE=quay.io/sdase/cluster-image-scanner-test-image:2.0.22
export IMAGE_SCAN_POSITIVE_FILTER="quay.io/sdase/|dexidp/dex"

docker run -v $(pwd)/module.bash:/clusterscanner/module.bash --env "IMAGE=${IMAGE}" -ti quay.io/sdase/cluster-image-scanner-scan-new-version:2

