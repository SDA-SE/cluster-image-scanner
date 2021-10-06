#!/bin/bash

kubectl apply -k argocd
sleep 5
until kubectl -n argocd get pods -o json | jq 'if (.items|length != 5) then 'false' else .items[].status.conditions[].status=="True" end' | grep -qv false
do
  echo "waiting for argocd to be up"
  sleep 5
done


kubectl apply -k argowf
sleep 5
until kubectl -n clusterscanner get pods -o json | jq 'if (.items|length != 2) then 'false' else .items[].status.conditions[].status=="True" end' | grep -qv false
do
  echo "waiting for workflow-controller to be up"
  sleep 5
done

kubectl kustomize --load-restrictor LoadRestrictionsNone base > tmp.yml
kubectl apply -f tmp.yml
rm tmp.yml

sleep 10
