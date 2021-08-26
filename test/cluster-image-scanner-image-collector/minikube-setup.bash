#!/bin/bash

DEPLOYMENT_PATH=../../deployment

source ${HOME}/.clusterscanner/secrets

sed -i "s#GITHUB_APP_ID_PLACEHOLDER#$GITHUB_APP_ID_PLACEHOLDER#" configmap.yaml
sed -i "s#GITHUB_APP_LOGIN_PLACEHOLDER#$GITHUB_APP_LOGIN_PLACEHOLDER#" configmap.yaml
sed -i "s#GITHUB_INSTALLATION_ID_PLACEHOLDER#$GITHUB_INSTALLATION_ID_PLACEHOLDER#" configmap.yaml


kubectl apply -k .

kubectl create secret generic github --from-file="keyfile=/home/tpagel/.clusterscanner/cluster-scan.2021-08-23.private-key.pem" -n cluster-image-scanner-image-collector

kubectl apply -k wordpress/
