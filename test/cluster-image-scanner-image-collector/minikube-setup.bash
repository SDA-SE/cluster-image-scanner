#!/bin/bash

DEPLOYMENT_PATH=../../deployment

source ${HOME}/.clusterscanner/secrets

sed -i "s#GITHUB_APP_ID_PLACEHOLDER#$GITHUB_APP_ID_PLACEHOLDER#" configmap.yaml
sed -i "s#GITHUB_APP_LOGIN_PLACEHOLDER#$GITHUB_APP_LOGIN_PLACEHOLDER#" configmap.yaml
sed -i "s#GITHUB_INSTALLATION_ID_PLACEHOLDER#$GITHUB_INSTALLATION_ID_PLACEHOLDER#" configmap.yaml

GITHUB_KEY=$(cat ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github_private_key.pem | base64 -w 0)
sed -i "s#GITHUB_KEY#${GITHUB_KEY}#" configmap.yaml

