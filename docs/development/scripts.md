# Helper Scripts for Development / Operations
## ClusterImageScanner Orchestration
```
# Delete all jobs
argo delete --all -n clusterscanner

# Delete all jobs, but not the orchestration
argo delete --prefix jobs -n clusterscanner

# Perform changes and submit a local job with argo-main
argo delete --all -n clusterscanner ; kubectl apply -f ../deployment/base-template/scanjob.yml ; argo submit ../argo-main.yml  -n clusterscanner

# As alternativ to argo-main, use an existing cronjob
argo submit --from cronwf/XXX-clusterscanner-main -n clusterscanner

```
## ClusterImageScanner Collector
```
# Re-Start a cluster-scan-collector job
kubectl get job cluster-scan-collector-1630994400 -n cluster-scan -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | kubectl replace --force -f -
```
