#!/bin/bash
set -e

mkdir -p "${IMAGE_UNPACKED_DIRECTORY}" || true
cd "${IMAGE_UNPACKED_DIRECTORY}"
tar xf "${IMAGE_TAR_PATH}"
cd /clusterscanner