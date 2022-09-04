#!/bin/bash
set -e
# shellcheck disable=SC2026,SC2154

source ./library.bash

if [ "${SECRETS_PATH}" != "" ]; then
  source ${SECRETS_PATH}
elif [ "${DD_TOKEN_SECRET}" == "" ]; then
  echo "Error, SECRETS_PATH doesn't exists and env variables not set";
  exit 1;
fi


for pid in $(ps -ef | grep port-forward | grep "svc/argo-server\|svc/minio-hl"  | awk '{print $2}');do kill $pid;done

if [ "${IS_MINIKUBE}" == "true" ]; then
  minikube delete
  minikube start --memory=4384 --cpus=8 --vm-driver kvm2 --disk-size 25GB
  #echo "Maybe you want to run 'minikube addons configure registry-creds' with registry 'https://index.docker.io/v1/', press any key to continue"
  #read -n 1 -s
fi


echo "clusterImageScannerImageTag: ${VERSION}"
sed -i "s~###clusterImageScannerImageTag###~${VERSION}~g" ../argo-main.yml


DEPLOYMENT_PATH=../deployment
sed -i "s#ACCESS_KEY#testtesttest#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/s3.env
sed -i "s#SECRET_KEY#testtesttest#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/s3.env

sed -i "s#DD_TOKEN_SECRET#${DD_TOKEN_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/defectdojo.secret.env
sed -i "s#DD_URL_PLACEHOLDER#${DD_URL_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/defectdojo.cm.env
sed -i "s#DD_USER_PLACEHOLDER#${DD_USER_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/defectdojo.cm.env
sed -i "s#DD_TEST_TOKEN_SECRET#${DD_TEST_TOKEN_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/defectdojo-test.secret.env
sed -i "s#DD_TEST_URL_PLACEHOLDER#${DD_TEST_URL_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/defectdojo-test.cm.env
sed -i "s#DD_TEST_USER_PLACEHOLDER#${DD_TEST_USER_PLACEHOLDER}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/defectdojo-test.cm.env

echo "test-all=${GIT_SOURCE_REPOSITORY}" > ${DEPLOYMENT_PATH}/overlays/test-local/config-source/repolist.env

sed -i "s#SLACK_CLI_TOKEN_SECRET#${SLACK_CLI_TOKEN_SECRET}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/slack.env

sed -i "s#GH_APP_ID_PLACEHOLDER#${GH_APP_ID}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env
sed -i "s#GH_APP_LOGIN_PLACEHOLDER#${GH_APP_LOGIN}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env
sed -i "s#GH_INSTALLATION_ID_PLACEHOLDER#${GH_INSTALLATION_ID}#" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github.env

if [ -f ${GH_PRIVATE_KEY_PATH} ] && [ "${GH_PRIVATE_KEY_BASE64}" == "" ]; then
  cp "${GH_PRIVATE_KEY_PATH}" ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github_private_key.pem
  export GH_PRIVATE_KEY_PATH=$(realpath "${DEPLOYMENT_PATH}/overlays/test-local/config-source/github_private_key.pem")
fi
if [ "${GH_PRIVATE_KEY_BASE64}" != "" ]; then
  echo "Found GH_PRIVATE_KEY_BASE64, putting it"
  echo "${GH_PRIVATE_KEY_BASE64}" | base64 -d > ${DEPLOYMENT_PATH}/overlays/test-local/config-source/github_private_key.pem
  export GH_PRIVATE_KEY_PATH="$(realpath ""${DEPLOYMENT_PATH}/overlays/test-local/config-source/github_private_key.pem")
fi

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
echo "Installation argowf"
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

cd collector
./setup.bash
cd ..
sleep 10
echo "adding port-forward"
kubectl -n clusterscanner port-forward svc/argo-server 2746:2746 &
kubectl -n clusterscanner port-forward svc/minio-hl 9000:9000 &

sleep 2

mc alias set local http://127.0.0.1:9000 testtesttest testtesttest || true
mc mb local/local || true

echo "submitting argo-main.yml"
argo submit -n clusterscanner ../argo-main.yml

if [ "${IS_MINIKUBE}" == "true" ]; then
  echo "Token:"
  server=$(kubectl get pods -n clusterscanner | grep argo-server | awk '{print $1}');
  kubectl -n clusterscanner exec pod/$server -- argo auth token
  echo "server=\$(kubectl get pods -n clusterscanner | grep argo-server | awk '{print \$1}'); kubectl -n clusterscanner exec pod/\$server -- argo auth token"
  echo "${server}"
fi

sleep 5
argo list workflows -A
workflow=$(argo -n clusterscanner list | grep orchestration | awk '{print $1}')
echo "will wait for workflow ${workflow}"

until [[ $(argo list -A | grep ${workflow} | grep Running | wc -l) -ne "1" ]]
do
  for i in $(argo list -A | awk '{print $2}'| grep -v "^NAME"); do
    argo get --no-utf8 $i -n clusterscanner;
    echo "######################################################################################################## argo get"
  done
#  for pod in $(kubectl get pod -n clusterscanner | grep -v ContainerCreating  | grep -v Pending | grep -v Completed | grep -v NAME | awk '{print $1}'); do
#      echo "######################################################################################################## pod logs $pod"
#      kubectl logs ${pod} -n clusterscanner || true
#  done
  sleep 60;
done
argo list workflows -A
if [ $(argo list workflows -A | grep -c -i "Error\|Failed") -ne 0 ]; then
  echo "ERRORs during workflow execution"
  for pod in $(kubectl get pod -n clusterscanner | grep -v "Completed" | awk '{print $1}'); do
      echo "######################################################################################################## pod logs ${pod}"
      kubectl logs ${pod} -n clusterscanner || true
  done
  exit 1
fi
rm -Rf ./tmp || true

