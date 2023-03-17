#!/bin/bash

. ../../test_actions/secrets
. git.bash

GH_KEY_FILE_PATH="/Users/rolandschilling/Downloads/cluster-scan2.2023-03-17.private-key.pem"

gitAuth

echo $GH_TOKEN
