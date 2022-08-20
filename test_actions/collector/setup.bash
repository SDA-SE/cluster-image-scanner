#!/bin/bash
set -e
DEPLOYMENT_PATH=../../deployment

source ${HOME}/.clusterscanner/secrets
source ../library.bash

sed -i "s~###VERSION###~${VERSION}~g" application/deployment.yaml
sed -i "s~###VERSION###~${VERSION}~g" job.yml
sed -i "s~###GITHUB_TARGET_REPOSITORY###~${GITHUB_TARGET_REPOSITORY}~g" job.yml

kubectl apply -k ./application
wait_for_pods_ready "test deployment of image" "shire" 1 10 120




sed -i "s#GITHUB_APP_ID_PLACEHOLDER#$GITHUB_APP_ID_PLACEHOLDER#" configmap.yaml
sed -i "s#GITHUB_APP_LOGIN_PLACEHOLDER#$GITHUB_APP_LOGIN_PLACEHOLDER#" configmap.yaml
sed -i "s#GITHUB_INSTALLATION_ID_PLACEHOLDER#$GITHUB_INSTALLATION_ID_PLACEHOLDER#" configmap.yaml

kubectl apply -k .

kubectl create secret generic github --from-file="keyfile=${GH_PRIVATE_KEY_PATH}" -n cluster-image-scanner-image-collector

wait_for_pods_completed "collector" "cluster-image-scanner-image-collector" 1 10 120


