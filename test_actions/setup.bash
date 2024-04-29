#!/bin/bash
set -e
# shellcheck disable=SC2026,SC2154

source ./library.bash

if [ "${SECRETS_PATH}" != "" ]; then
  source "${SECRETS_PATH}"
elif [ "${DD_TOKEN_SECRET}" == "" ]; then
  echo "Error, SECRETS_PATH doesn't exists and env variables not set";
  exit 1;
fi


for pid in $(ps -ef | grep port-forward | grep "svc/argo-server\|svc/minio"  | awk '{print $2}');do kill $pid;done

if [ "${IS_MINIKUBE}" == "true" ]; then
  minikube delete
  minikube start --memory=4384 --cpus=8 --vm-driver kvm2 --disk-size 25GB
  #echo "Maybe you want to run 'minikube addons configure registry-creds' with registry 'https://index.docker.io/v1/', press any key to continue"
  #read -n 1 -s
  kubectl config use-context minikube
  if [ "${DOCKER_SECRET}" != "" ]; then
    minikube ssh  "docker login --password \"${DOCKER_SECRET}\" --username ${DOCKER_USER}"
  fi
fi

current_context=$(kubectl config current-context)
k8s_contexts=("minikube docker-for-desktop")

found=0
for context in "${k8s_contexts[@]}"; do
    # Check if the current context matches the target context
    if [ "$context" == "$current_context" ]; then
        found=1
        break
    fi
done
if [ "$found" -eq 1 ]; then
    echo "Current Kubernetes context ($current_context) is allowed."
else
    echo "Current Kubernetes context ($current_context) is not allowed."
fi

echo "clusterImageScannerImageTag: ${VERSION}"
rm -Rf ./tmp || true
mkdir tmp
cp variables.yaml tmp/variables.yaml
sed -i.bak "s~###VERSION###~${VERSION}~g" tmp/variables.yaml



export DEPLOYMENT_PATH=$(realpath ../deployment)

kubectl apply -k argocd
wait_for_pods_ready "argocd" "argocd" 5 10 120

kubectl apply -f argocd.project.yml

# kustomize is not supported
echo "Installation argowf"

kubectl apply -k argowf
curl -sL --output ./tmp/namespace-install.yaml "https://github.com/argoproj/argo-workflows/releases/download/v3.3.8/namespace-install.yaml"
kubectl apply -f ./tmp/namespace-install.yaml -n clusterscanner


kubectl apply -k minio

#wait_for_pods_ready "minio" "minio-operator" 2 10 120
wait_for_pods_ready "workflow-controller" "clusterscanner" 3 10 60

helm install -f $HOME/.clusterscanner/variables.secret.yaml -f tmp/variables.yaml -f variables.base.yaml cis-base ${DEPLOYMENT_PATH}/helm/cluster-image-scanner-orchestrator-base/ -n clusterscanner
helm install -f $HOME/.clusterscanner/variables.secret.yaml -f tmp/variables.yaml cis-orchestrator ${DEPLOYMENT_PATH}/helm/cluster-image-scanner-orchestrator/ -n clusterscanner

if ! which argo > /dev/null 2>&1; then
  curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.3.8/argo-linux-amd64.gz
  gunzip argo-linux-amd64.gz
  chmod +x argo-linux-amd64
  mv ./argo-linux-amd64 ./tmp/argo
  argo=./tmp/argo
  PATH=$PATH:./tmp
fi

kubectl kustomize --load-restrictor LoadRestrictionsNone base > tmp.yml
kubectl apply -f tmp.yml
rm tmp.yml

sleep 30

cp -a collector tmp
sed -i.bak "s~###VERSION###~${VERSION}~g" ./tmp/collector/application/deployment.yaml
cd tmp/collector
./setup.bash
cd ../..
sleep 10
echo "adding port-forward"
kubectl -n clusterscanner port-forward svc/argo-server 2746:2746 &
pod=$(kubectl get pods -n clusterscanner  | grep minio | awk '{print $1}')
kubectl port-forward pod/$pod 9000 9090 -n clusterscanner &
sleep 2

if ! which mc > /dev/null 2>&1; then
  curl https://dl.min.io/client/mc/release/linux-amd64/mc \
    --create-dirs \
    -o ./tmp/mc

  chmod +x ./tmp/mc
  export PATH=$PATH:./tmp/
fi

mc alias set local http://127.0.0.1:9000 minioadmin minioadmin  || true
mc mb local/local || true


echo "submitting argo-main.yml"
cp ../argo-main.yml tmp
sed -i.bak "s~###clusterImageScannerImageTag###~${VERSION}~g" tmp/argo-main.yml
argo submit -n clusterscanner tmp/argo-main.yml

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
echo "Listing all workflows"
argo list workflows -A
if [ $(argo list workflows -A | grep -c -i "Error\|Failed") -ne 0 ]; then
  echo "ERRORs during workflow execution"
  for pod in $(kubectl get pod -n clusterscanner | grep -v "Completed" | awk '{print $1}'); do
      echo "######################################################################################################## pod logs ${pod}"
      kubectl logs ${pod} -n clusterscanner || true
  done
  if [ "${IS_MINIKUBE}" == "true" ]; then
    echo "Token:"
    server=$(kubectl get pods -n clusterscanner | grep argo-server | awk '{print $1}');
    kubectl -n clusterscanner exec pod/$server -- argo auth token
    echo "server=\$(kubectl get pods -n clusterscanner | grep argo-server | awk '{print \$1}'); kubectl -n clusterscanner exec pod/\$server -- argo auth token"
    echo "${server}"
  fi
  exit 1
fi

exit 0
