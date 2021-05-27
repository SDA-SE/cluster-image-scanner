#!/bin/bash
set -e

source $HOME/.clusterscanner/secrets

if [ "${QUAY_SECRET}" == "" ]; then
  echo "Please set $HOME/.clusterscanner/secrets"
  exit 1
fi

if [ "$IS_MINIKUBE" == "true" ]; then
  minikube delete
  minikube start --memory=29384 --cpus=8 --vm-driver kvm2 --disk-size 150GB
fi
DEPLOYMENT_PATH=../deployment

kubectl create namespace argocd || true
kubectl create namespace clusterscanner || true

sed -i "s#ACCESS_KEY#$ACCESS_KEY#" $DEPLOYMENT_PATH/overlays/test-local/config-source/s3.env
sed -i "s#SECRET_KEY#$SECRET_KEY#" $DEPLOYMENT_PATH/overlays/test-local/config-source/s3.env
sed -i "s#DD_TOKEN_SECRET#$DD_TOKEN_SECRET#" $DEPLOYMENT_PATH/overlays/test-local/config-source/defectdojo.env
sed -i "s#SLACK_CLI_TOKEN_SECRET#$SLACK_CLI_TOKEN_SECRET#" $DEPLOYMENT_PATH/overlays/test-local/config-source/slack.env

sed -i "s#GITHUB_APP_ID_PLACEHOLDER#$GITHUB_APP_ID_PLACEHOLDER#" $DEPLOYMENT_PATH/overlays/test-local/config-source/github.env
sed -i "s#GITHUB_APP_LOGIN_PLACEHOLDER#$GITHUB_APP_LOGIN_PLACEHOLDER#" $DEPLOYMENT_PATH/overlays/test-local/config-source/github.env
sed -i "s#GITHUB_INSTALLATION_ID_PLACEHOLDER#$GITHUB_INSTALLATION_ID_PLACEHOLDER#" $DEPLOYMENT_PATH/overlays/test-local/config-source/github.env
cp $HOME/.clusterscanner/github_private_key.pem $DEPLOYMENT_PATH/overlays/test-local/config-source/github_private_key.pem

sed -i "s#DEPSCAN_DB_DRIVER_PLACEHOLDER#$DEPSCAN_DB_DRIVER_PLACEHOLDER#" $DEPLOYMENT_PATH/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_USERNAME_PLACEHOLDER#$DEPSCAN_DB_USERNAME_PLACEHOLDER#" $DEPLOYMENT_PATH/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_PASSWORD_PLACEHOLDER#$DEPSCAN_DB_PASSWORD_PLACEHOLDER#" $DEPLOYMENT_PATH/overlays/test-local/config-source/depcheck.env
sed -i "s#DEPSCAN_DB_CONNECTSRING_PLACEHOLDER#$DEPSCAN_DB_CONNECTSRING_PLACEHOLDER#" $DEPLOYMENT_PATH/overlays/test-local/config-source/depcheck.env

sed -i "s#SLACK_CLI_TOKEN_SECRET#$SLACK_CLI_TOKEN_SECRET#" $DEPLOYMENT_PATH/overlays/test-local/config-source/slack.env

sed -i "s#smtp_SECRET#$smtp_SECRET#" $DEPLOYMENT_PATH/overlays/test-local/config-source/email.env
sed -i "s#smtp-auth_SECRET#$smtp_auth_SECRET#" $DEPLOYMENT_PATH/overlays/test-local/config-source/email.env
sed -i "s#smtp-auth-user_SECRET#$smtp_auth_user_SECRET#" $DEPLOYMENT_PATH/overlays/test-local/config-source/email.env
sed -i "s#smtp-auth-password_SECRET#$smtp_auth_password_SECRET#" $DEPLOYMENT_PATH/overlays/test-local/config-source/email.env


AUTH=$(cat $HOME/.docker/config.json | base64 -w 0)
cat << EOL >> /tmp/config.yaml
apiVersion: v1
data:
  .dockerconfigjson: AUTH
kind: Secret
metadata:
  name: clusterscanner-pull-registry
type: kubernetes.io/dockerconfigjson
EOL
sed -i "s#AUTH#$AUTH#g" /tmp/config.yaml
kubectl apply -f  /tmp/config.yaml -n default
kubectl apply -f  /tmp/config.yaml -n argocd
kubectl apply -f  /tmp/config.yaml -n clusterscanner

AUTH=$(cat $HOME/.docker/config.json | base64 -w 0)
cat << EOL >> /tmp/config.yaml
apiVersion: v1
data:
  auth.json: AUTH
kind: Secret
metadata:
  name: registry-sda-default
type: kubernetes.io/secret
EOL
sed -i "s#AUTH#$AUTH#g" /tmp/config.yaml
kubectl apply -f  /tmp/config.yaml -n clusterscanner
kubectl apply -f  serviceaccount.yml -n clusterscanner

if [ "$IS_MINIKUBE" == "true" ]; then
  kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "clusterscanner-pull-registry"}]}' || true
  kubectl patch serviceaccount clusterscanner -p '{"imagePullSecrets": [{"name": "clusterscanner-pull-registry"}]}' -n clusterscanner

fi
# to fetch argoworfklow images
wget -O /tmp/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
cat /tmp/install.yaml  | sed 's#containers:#imagePullSecrets:\n        - name: clusterscanner-pull-registry\n      containers:#' >  /tmp/install-pull.yaml
# maybe remove adjustment because serviceaccounts are enough
kubectl apply -n argocd -f /tmp/install-pull.yaml

if [ "$IS_MINIKUBE" == "true" ]; then
  for i in $(kubectl get serviceaccounts -n argocd | awk '{print $1}' | grep -v NAME); do
    echo $i
    kubectl patch serviceaccount $i -p '{"imagePullSecrets": [{"name": "clusterscanner-pull-registry"}]}' -n argocd
  done
fi

while [ $(kubectl get pods -n argocd  | grep "1/1" | wc -l) -ne 5 ]; do
  echo "waiting for 5 ready pods in argocd"
  kubectl get pods -n argocd
  sleep 3
done
sleep 60
kubectl patch deploy argocd-server -n argocd -p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]' --type json
sleep 50
for i in $(ps -ef | grep port-forward | grep svc/argocd-server | grep -v grep | awk '{print $2}'); do kill $i;done
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
sleep 20
argocd proj --server localhost:8080 --insecure create clusterscanner -d https://kubernetes.default.svc,clusterscanner
argocd proj --server localhost:8080 --insecure add-source clusterscanner "*"
argocd proj --server localhost:8080 --insecure allow-cluster-resource clusterscanner '*' '*'
argocd proj --server localhost:8080 --insecure deny-namespace-resource "clusterscanner" '*' '*' # needed for add
argocd proj --server localhost:8080 --insecure allow-namespace-resource  clusterscanner '*' '*'
sleep 1
argocd repo --server localhost:8080 --insecure add git@github.com:pagel-pro/clusterscanner-orchestration.git --ssh-private-key-path ~/.ssh/id_rsa

kubectl apply -f ./argoworkflow.yml
sleep 20

if [ "$IS_MINIKUBE" == "true" ]; then
  for i in $(kubectl get serviceaccounts -n clusterscanner | awk '{print $1}' | grep -v NAME); do
    kubectl patch serviceaccount $i -p '{"imagePullSecrets": [{"name": "clusterscanner-pull-registry"}]}' -n clusterscanner
  done
fi

kubectl apply -k $DEPLOYMENT_PATH/overlays/test-local/
# restart pods
for i in $(kubectl get pods -n clusterscanner | awk '{print $1}' | grep -v NAME); do
  kubectl delete pod $i -n clusterscanner
done
while [ $(kubectl get pods -n clusterscanner  | grep "1/1" | wc -l) -ne 2 ]; do
  echo "waiting for 2 ready pods in clusterscanner"
  kubectl get pods -n clusterscanner
  sleep 3
done
sleep 2
for i in $(ps -ef | grep port-forward | grep svc/argo-server | grep -v grep | awk '{print $2}'); do kill $i;done
kubectl -n clusterscanner port-forward svc/argo-server 2746:2746 &

argo submit ../argo-main.yml  -n clusterscanner

echo "reverting secret changes"
git checkout  $DEPLOYMENT_PATH/overlays/test-local/config-source || true

echo "please visit https://localhost:2746/"

