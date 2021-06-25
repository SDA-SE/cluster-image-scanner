#!/bin/bash

if [ "xX${MODULE_NAME}" == "xX" ]; then
    echo "MODULE_NAME not set"
    exit 1;
fi
