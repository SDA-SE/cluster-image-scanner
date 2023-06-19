#!/bin/bash

kubectl delete ns argocd
kubectl delete ns minio-operator
kubectl delete ns clusterscanner
kubectl delete ns cluster-image-scanner-image-collector
