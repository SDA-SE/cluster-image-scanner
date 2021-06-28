#!/bin/bash
set -e

ls -la
jq -cMr '.[] | @base64' /clusterscanner/imageList.json > /clusterscanner/imageListSeparated.json
while read -r line; do
  DATA_JSON=$(echo "${line}" | base64 -d | jq -cM .)
  if [[ "$(echo "${DATA_JSON}" | jq -r '.skip')" == "true" ]]; then
    echo "Skipping Image: $(echo ${DATA_JSON} | jq -r '.image') Namespace: $(echo ${DATA_JSON} | jq -r '.namespace') Environment: $(echo ${DATA_JSON} | jq -r '.environment')"
    continue
  fi
  cp /clusterscanner/workflow.template.yml /clusterscanner/template.yml
  sed -i "s~###REGISTRY_SECRET###~${REGISTRY_SECRET}~" /clusterscanner/template.yml
  sed -i "s~###DEPENDENCY_SCAN_CM###~${DEPENDENCY_SCAN_CM}~" /clusterscanner/template.yml
  sed -i "s~###DEFECTDOJO_CM###~${DEFECTDOJO_CM}~" /clusterscanner/template.yml
  sed -i "s~###DEFECTDOJO_SECRETS###~${DEFECTDOJO_SECRETS}~" /clusterscanner/template.yml
  sed -i "s~###SCAN_ID###~${SCAN_ID}~" /clusterscanner/template.yml
  sed -i "s~###team###~$(echo "${DATA_JSON}" | jq -r .team)~" /clusterscanner/template.yml
  sed -i "s~###appname###~$(echo "${DATA_JSON}" | jq -r .app_kubernetes_io_name)~" /clusterscanner/template.yml
  sed -i "s~###environment###~$(echo "${DATA_JSON}" | jq -r .environment)~" /clusterscanner/template.yml
  sed -i "s~###namespace###~$(echo "${DATA_JSON}" | jq -r .namespace)~" /clusterscanner/template.yml
  sed -i "s~###scm_source_branch###~$(echo "${DATA_JSON}" | jq -r .scm_source_branch)~" /clusterscanner/template.yml
  sed -i "s~###image###~$(echo "${DATA_JSON}" | jq -r .image)~" /clusterscanner/template.yml
  sed -i "s~###image_id###~$(echo "${DATA_JSON}" | jq -r .image_id)~" /clusterscanner/template.yml
  sed -i "s~###slack###~$(echo "${DATA_JSON}" | jq -r .slack)~" /clusterscanner/template.yml
  sed -i "s~###email###~$(echo "${DATA_JSON}" | jq -r .email)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_lifetime###~$(echo "${DATA_JSON}" | jq -r .is_scan_lifetime)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_distroless###~$(echo "${DATA_JSON}" | jq -r .is_scan_distroless)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_malware###~$(echo "${DATA_JSON}" | jq -r .is_scan_malware)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_dependency_check###~$(echo "${DATA_JSON}" | jq -r .is_scan_dependency_check)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_runasroot###~$(echo "${DATA_JSON}" | jq -r .is_scan_runasroot)~" /clusterscanner/template.yml
  sed -i "s~###scan_lifetime_max_days###~$(echo "${DATA_JSON}" | jq -r .scan_lifetime_max_days)~" /clusterscanner/template.yml
  cat /clusterscanner/template.yml
  kubectl create -n clusterscanner -f /clusterscanner/template.yml
  for outdatedJob in $(argo list --running -n clusterscanner --prefix scanjob | grep "Running *1h" | awk '{print $1}'); do # this is a workaround for a mount problem and should be solved
    echo "stopping ${outdatedJob} because it is running since over an hour without getting done"
    argo stop "${outdatedJob}" -n clusterscanner
  done
done < /clusterscanner/imageListSeparated.json
while [[ "$(argo list --running -n clusterscanner -l "clusterscanner.sda.se/scan-id=${SCAN_ID}" | tail --lines=+2 | wc -l)" -gt 0 ]]; do
  echo "There are still scans running, waiting another 10 seconds"
  sleep 10
done
echo "All scans have finished"
