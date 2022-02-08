#!/bin/bash

set -e

scan_result_pre

/syft "$@"

scan_result_post

exit  0
