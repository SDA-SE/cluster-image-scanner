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
