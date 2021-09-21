#!/bin/bash
set -e

ls -la
jq -cMr '.[] | @base64' /clusterscanner/imageList.json > /clusterscanner/imageListSeparated.json
totalCount=$(cat  /clusterscanner/imageList.json | jq '.[].image' | wc -l)
counter=0
while read -r line; do
  DATA_JSON=$(echo "${line}" | base64 -d | jq -cM .)
  if [[ "$(echo "${DATA_JSON}" | jq -r '.skip')" == "true" ]]; then
    echo "Skipping Image: $(echo ${DATA_JSON} | jq -r '.image') Namespace: $(echo ${DATA_JSON} | jq -r '.namespace') Environment: $(echo ${DATA_JSON} | jq -r '.environment')"
    continue
  fi
  IS_SCAN_BASEIMAGE_LIFETIME=$(echo "${DATA_JSON}" | jq -r '.is_scan_baseimage_lifetime' | sed 's#null#true#')
  IS_SCAN_NEW_VERSION=$(echo "${DATA_JSON}" | jq -r '.is_scan_new_version' | sed 's#null#true#')
  cp /clusterscanner/workflow.template.yml /clusterscanner/template.yml
  sed -i "s~###REGISTRY_SECRET###~${REGISTRY_SECRET}~" /clusterscanner/template.yml
  sed -i "s~###DEPENDENCY_SCAN_CM###~${DEPENDENCY_SCAN_CM}~" /clusterscanner/template.yml
  sed -i "s~###DEFECTDOJO_CM###~${DEFECTDOJO_CM}~" /clusterscanner/template.yml
  sed -i "s~###DEFECTDOJO_SECRETS###~${DEFECTDOJO_SECRETS}~" /clusterscanner/template.yml
  sed -i "s~###SCAN_ID###~${SCAN_ID}~" /clusterscanner/template.yml
  sed -i "s~###dependencyCheckSuppressionsConfigMapName###~${dependencyCheckSuppressionsConfigMapName}~" /clusterscanner/template.yml
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
  sed -i "s~###is_scan_baseimage_lifetime###~${IS_SCAN_BASEIMAGE_LIFETIME}~" /clusterscanner/template.yml
  sed -i "s~###is_scan_distroless###~$(echo "${DATA_JSON}" | jq -r .is_scan_distroless)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_malware###~$(echo "${DATA_JSON}" | jq -r .is_scan_malware)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_dependency_check###~$(echo "${DATA_JSON}" | jq -r .is_scan_dependency_check)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_runasroot###~$(echo "${DATA_JSON}" | jq -r .is_scan_runasroot)~" /clusterscanner/template.yml
  sed -i "s~###is_scan_new_version###~${IS_SCAN_NEW_VERSION}~" /clusterscanner/template.yml
  sed -i "s~###scan_lifetime_max_days###~$(echo "${DATA_JSON}" | jq -r .scan_lifetime_max_days)~" /clusterscanner/template.yml
  sed -i "s~###new_version_image_filter###~${NEW_VERSION_IMAGE_FIILTER}~" /clusterscanner/template.yml
  sed -i "s~###baseImageName###~${baseImageName}~" /clusterscanner/template.yml
  sed -i "s~###defectDojoClientImageName###~${defectDojoClientImageName}~" /clusterscanner/template.yml
  sed -i "s~###scanDistrolessImageName###~${scanDistrolessImageName}~" /clusterscanner/template.yml
  sed -i "s~###scanDependencyCheckImageName###~${scanDependencyCheckImageName}~" /clusterscanner/template.yml
  sed -i "s~###scanMalwareImageName###~${scanMalwareImageName}~" /clusterscanner/template.yml
  sed -i "s~###scanRootImageName###~${scanRootImageName}~" /clusterscanner/template.yml
  sed -i "s~###scanLifetimeImageName###~${scanLifetimeImageName}~" /clusterscanner/template.yml
  sed -i "s~###scanNewVersionImageName###~${scanNewVersionImageName}~" /clusterscanner/template.yml

  cat /clusterscanner/template.yml
  kubectl create -n clusterscanner -f /clusterscanner/template.yml

  for outdatedJob in $(argo list --running -n clusterscanner --prefix scanjob | grep "Running *1h" | awk '{print $1}'); do
    echo "stopping ${outdatedJob} because it is running since over an hour without getting done"
    argo stop "${outdatedJob}" -n clusterscanner
  done
  counter=$((counter+1))
  echo "Job Status (Submitted Jobs/Total Jobs): ${counter}/${totalCount}"

  if [ "${MAX_RUNNING_JOBS_IN_QUEUE}" != "" ]; then
    # argo list --status Pending,Running results in Running only, maybe this will be fixed one day
    while [[ "$(argo list -n clusterscanner | grep scanjob | grep "Pending\|Running" | wc -l)" -gt ${MAX_RUNNING_JOBS_IN_QUEUE} ]]; do # this should be shifted to argo workflows, as soon as there is a solution for a cluster wide argo workflows setup
      echo "There are more than ${MAX_RUNNING_JOBS_IN_QUEUE} workflows pending/running, waiting 10 seconds until there are less"
      sleep 10
    done
  fi
done < /clusterscanner/imageListSeparated.json
while [[ "$(argo list --running -n clusterscanner -l "clusterscanner.sda.se/scan-id=${SCAN_ID}" | tail --lines=+2 | wc -l)" -gt 0 ]]; do
  echo "There are still scans running, waiting another 10 seconds"
  sleep 10
done
echo "All scans have finished"
