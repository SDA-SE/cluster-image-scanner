#!/bin/bash
set -e
DEPLOYMENT_PATH=../../deployment

source ${HOME}/.clusterscanner/secrets
source ./library.bash

kubectl apply -k ./collector/application
wait_for_pods_ready "test deployment of image" "shire" 1 10 120

sed -i "s#GITHUB_APP_ID_PLACEHOLDER#$GITHUB_APP_ID_PLACEHOLDER#" configmap.yaml
sed -i "s#GITHUB_APP_LOGIN_PLACEHOLDER#$GITHUB_APP_LOGIN_PLACEHOLDER#" configmap.yaml
sed -i "s#GITHUB_INSTALLATION_ID_PLACEHOLDER#$GITHUB_INSTALLATION_ID_PLACEHOLDER#" configmap.yaml

kubectl create secret generic github --from-file="keyfile=/home/tpagel/.clusterscanner/cluster-scan.2021-08-23.private-key.pem" -n cluster-image-scanner-image-collector

kubectl apply -k .




