#!/bin/bash
set -e
# shellcheck disable=SC2026,SC2154

if [ "${IS_MINIKUBE}" == "true" ]; then
  minikube delete
  minikube start --memory=29384 --cpus=8 --vm-driver kvm2 --disk-size 150GB
  echo "Maybe you want to run 'minikube addons configure registry-creds' with registry 'https://index.docker.io/v1/', press any key to continue"
  read -n 1 -s
fi


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

if [ ! -e ${SECRETS_PATH} ]; then echo "Error, SECRETS_PATH doesn't exists"; exit 1; fi
source ${SECRETS_PATH}

DEPLOYMENT_PATH=../deployment
sed -i "s#ACCESS_KEY#testtesttest#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/s3.env
sed -i "s#SECRET_KEY#testtesttest#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/s3.env

sed -i "s#DD_TOKEN_SECRET#${DD_TOKEN_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/defectdojo.env
sed -i "s#http://localhost:8081#${DD_URL_SECRET}#" base/kustomization.yml
sed -i "s#DD_USER: \"clusterscanner\"#DD_USER: \"${DD_USER_SECRET}\"#" base/kustomization.yml

sed -i "s#SLACK_CLI_TOKEN_SECRET#${SLACK_TOKEN}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/slack.env

sed -i "s#GITHUB_APP_ID_PLACEHOLDER#${GH_APP_ID}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env
sed -i "s#GITHUB_APP_LOGIN_PLACEHOLDER#${GITHUB_APP_LOGIN_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env
sed -i "s#GITHUB_INSTALLATION_ID_PLACEHOLDER#${GH_INSTALLATION_ID}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env
echo "${GH_PRIVATE_KEY}" > ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github_private_key.pem

sed -i "s#DEPSCAN_DB_DRIVER_PLACEHOLDER#${DEPSCAN_DB_DRIVER_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_USERNAME_PLACEHOLDER#${DEPSCAN_DB_USERNAME_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_PASSWORD_PLACEHOLDER#${DEPSCAN_DB_PASSWORD_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_CONNECTSRING_PLACEHOLDER#${DEPSCAN_DB_CONNECTSRING_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/depcheck.env

sed -i "s#smtp_SECRET#${smtp_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/email.env
sed -i "s#smtp_auth_SECRET#${smtp_auth_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/email.env
sed -i "s#smtp_auth-user_SECRET#${smtp_auth_user_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/email.env
sed -i "s#smtp_auth-password_SECRET#${smtp_auth_password_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/email.env

sed -i "s#DEPENDENCY_TRACK_URL_PLACEHOLDER#${DEPENDENCY_TRACK_URL_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/dependency-track.cm.env
sed -i "s#DEPENDENCY_TRACK_KEY_PLACEHOLDER#${DEPENDENCY_TRACK_KEY_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/dependency-track.secret.env

kubectl apply -k argocd
wait_for_pods_ready "argocd" "argocd" 5 10 120

kubectl apply -f argocd.project.yml

# kustomize is not supported
mkdir tmp || true
kubectl apply -k argowf
curl -sL --output ./tmp/namespace-install.yaml "https://github.com/argoproj/argo-workflows/releases/download/v3.3.8/namespace-install.yaml"
kubectl apply -f ./tmp/namespace-install.yaml -n clusterscanner


kubectl apply -k minio

wait_for_pods_ready "minio" "minio-operator" 2 10 120
wait_for_pods_ready "argo-workflow" "clusterscanner" 2 10 120

kubectl kustomize --load-restrictor LoadRestrictionsNone base > tmp.yml
kubectl apply -f tmp.yml
rm tmp.yml

if ! which mc > /dev/null 2>&1; then
  curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc --output ./tmp/mc
  chmod +x ./tmp/mc
  PATH=$PATH:./tmp
fi

if ! which argo > /dev/null 2>&1; then
  curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.3.8/argo-linux-amd64.gz
  gunzip argo-linux-amd64.gz
  chmod +x argo-linux-amd64
  mv ./argo-linux-amd64 ./tmp/argo
  argo=./tmp/argo
  PATH=$PATH:./tmp
fi

sleep 30

wait_for_pods_ready "minio tenant" "clusterscanner" 3 10 120

sleep 10

echo "adding port-forward"
kubectl -n clusterscanner port-forward svc/argo-server 2746:2746 &
kubectl -n clusterscanner port-forward svc/minio-hl 9000:9000 &

sleep 2

mc alias set local http://127.0.0.1:9000 testtesttest testtesttest || true
mc mb local/local || true

echo "submitting argo-main.yml"
argo submit -n clusterscanner ../argo-main.yml

sleep 5
workflow=$(argo -n clusterscanner list | grep orchestration | awk '{print $1}')
argo -n clusterscanner wait "${workflow}"

rm -Rf ./tmp || true

if [ "${IS_MINIKUBE}" == "true" ]; then
  echo "Token:"
  server=$(kubectl get pods -n clusterscanner | grep argo-server | awk '{print $1}'); kubectl -n clusterscanner exec pod/$server -- argo auth token
  echo "server=\$(kubectl get pods -n clusterscanner | grep argo-server | awk '{print \$1}'); kubectl -n clusterscanner exec pod/\$server -- argo auth token"
  echo "${server}"
fi
