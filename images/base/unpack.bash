#!/bin/bash
set -e

if [ -d "${IMAGE_UNPACKED_DIRECTORY}" ]; then
  echo "IMAGE_UNPACKED_DIRECTORY ${IMAGE_UNPACKED_DIRECTORY} exists"
else
  echo "Unpacking ${IMAGE_TAR_PATH} to ${IMAGE_UNPACKED_DIRECTORY}"
  mkdir -p "${IMAGE_UNPACKED_DIRECTORY}" || true
  cd "${IMAGE_UNPACKED_DIRECTORY}"
  tar xf "${IMAGE_TAR_PATH}"
  cd -
fi
