#!/bin/bash
set -e
DEPLOYMENT_PATH=../../deployment

if [ "${SECRETS_PATH}" != "" ]; then
  source ${SECRETS_PATH}
fi
source ../library.bash

if [ "${BRANCH}" == "master" ]; then
  sed -i "s~###VERSION###~2.0.225~g" application/deployment.yaml
else
  sed -i "s~###VERSION###~${VERSION}~g" application/deployment.yaml
fi
sed -i "s~###VERSION###~${VERSION}~g" job.yml
sed -i "s~###GIT_COLLECTOR_REPOSITORY###~${GIT_COLLECTOR_REPOSITORY}~g" job.yml

kubectl apply -k ./application
wait_for_pods_ready "test deployment of image" "shire" 1 10 120

sed -i "s#GH_APP_ID_PLACEHOLDER#${GH_APP_ID}#" configmap.yaml
sed -i "s#GH_APP_LOGIN_PLACEHOLDER#${GH_APP_LOGIN}#" configmap.yaml
sed -i "s#GH_INSTALLATION_ID_PLACEHOLDER#${GH_INSTALLATION_ID}#" configmap.yaml

kubectl apply -k .
if [ -f "${GH_PRIVATE_KEY_PATH}" ]; then
  kubectl create secret generic github --from-file="keyfile=${GH_PRIVATE_KEY_PATH}" -n cluster-image-scanner-image-collector
else
  kubectl create secret generic github --from-literal="keyfile=not-existing" -n cluster-image-scanner-image-collector
fi


wait_for_pods_completed "collector" "cluster-image-scanner-image-collector" 1 10 120
kubectl get pods -n cluster-image-scanner-image-collector
if [ $(kubectl get pods -n cluster-image-scanner-image-collector | grep -c Completed) -lt 1 ]; then
  echo "Collector is broken"
  exit 1
fi

#kubectl delete namespace shire