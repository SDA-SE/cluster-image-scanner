#!/bin/bash

context=$(kubectl config current-context)
if [ "$context" != "minikube" ]; then
  echo "Context is not minikube"
  exit 1
fi

kubectl apply -f service-account-authorization.yaml
kubectl apply -f namespace.yaml
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml
kubectl apply -f cron-job.yml