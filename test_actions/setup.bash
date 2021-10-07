#!/bin/bash
# shellcheck disable=SC2026

wait_for_pods_ready () {
  local name="${1}"; shift
  local namespace="${1}"; shift
  local count="${1}"; shift
  local sleep="${1}"; shift
  local max_attempts="${1}"
  local attempt_num=0
  until [[ $(kubectl -n "${namespace}" get pods -o json | jq '.items | length') -ge "${count}" ]]
  do
    if [[ $(( attempt_num++ )) -ge "${max_attempts}" ]]
    then
      echo "max_attempts ${max_attempts} reached, aborting"
      kubectl get pods -A
      exit 1
    fi
    echo "waiting for ${name} to be created"
    sleep "${sleep}"
  done
  until [[ $(kubectl -n "${namespace}" get pods -o json | jq '.items[].status.conditions[].status=="True"' | grep -c false) -eq "0" ]]
  do
    if [[ $(( attempt_num++ )) -ge "${max_attempts}" ]]
    then
      echo "max_attempts ${max_attempts} reached, aborting"
      kubectl get pods -A
      exit 1
    fi
    echo "waiting for ${name} to be up"
    sleep "${sleep}"
  done
}

source secrets/env.env

DEPLOYMENT_PATH=../deployment
sed -i "s#ACCESS_KEY#testtesttest#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/s3.env
sed -i "s#SECRET_KEY#testtesttest#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/s3.env
sed -i "s#DD_TOKEN_SECRET#${DD_TOKEN}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/defectdojo.env
sed -i "s#SLACK_CLI_TOKEN_SECRET#${SLACK_TOKEN}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/slack.env

sed -i "s#GITHUB_APP_ID_PLACEHOLDER#${GH_APP_ID}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env
sed -i "s#GITHUB_APP_LOGIN_PLACEHOLDER#${GITHUB_APP_LOGIN_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env
sed -i "s#GITHUB_INSTALLATION_ID_PLACEHOLDER#${GH_INSTALLATION_ID}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env
echo "${GH_PRIVATE_KEY}" > ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github_private_key.pem

sed -i "s#DEPSCAN_DB_DRIVER_PLACEHOLDER#${DEPSCAN_DB_DRIVER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_USERNAME_PLACEHOLDER#${DEPSCAN_DB_USERNAME}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_PASSWORD_PLACEHOLDER#${DEPSCAN_DB_PASSWORD}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_CONNECTSRING_PLACEHOLDER#${DEPSCAN_DB_CONNECTSRING}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/depcheck.env

sed -i "s#smtp_SECRET#${smtp_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/email.env
sed -i "s#smtp_auth_SECRET#${smtp_auth_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/email.env
sed -i "s#smtp_auth-user_SECRET#${smtp_auth_user_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/email.env
sed -i "s#smtp_auth-password_SECRET#${smtp_auth_password_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/email.env

kubectl apply -k argocd
wait_for_pods_ready "argocd" "argocd" 5 10 120

kubectl apply -f argocd.project.yml

kubectl apply -k argowf
kubectl apply -k minio

wait_for_pods_ready "minio" "minio-operator" 2 10 120
wait_for_pods_ready "argo-workflow" "clusterscanner" 2 10 120

kubectl kustomize --load-restrictor LoadRestrictionsNone base > tmp.yml
kubectl apply -f tmp.yml
rm tmp.yml

wait_for_pods_ready "minio tenant" "clusterscanner" 3 10 120

[[ -f mc ]] || wget https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc

echo "adding port-forward"
kubectl -n clusterscanner port-forward svc/argo-server 2746:2746 &
kubectl -n clusterscanner port-forward svc/minio-hl 9000:9000 &

./mc alias set local http://127.0.0.1:9000 testtesttest testtesttest || true
./mc mb local/local || true

echo "submitting argo-main.yml"
argo submit -n clusterscanner ../argo-main.yml

workflow=$(argo -n clusterscanner list | grep orchestration | awk "{print $1}")
argo -n clusterscanner wait "${workflow}"
