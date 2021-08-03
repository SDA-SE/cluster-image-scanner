#!/bin/bash

export MODULE_NAME="scan-lifetime"

if [ "${IS_BASE_IMAGE_LIFETIME_SCAN}" == "true" ]; then
  export MODULE_NAME="scan-baseimage-lifetime"
fi
