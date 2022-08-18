#!/bin/bash
# shellcheck disable=SC2154 # variables come via env, so they are not assigned
set -e

if [ "${SERVICE_ACCOUNT_NAME}" == "" ]; then
  SERVICE_ACCOUNT_NAME="clusterscanner"
fi
jq -cMr '.[] | @base64' /clusterscanner/imageList.json > /tmp/imageListSeparated.json
totalCount=$(cat  /clusterscanner/imageList.json | jq '.[].image' | wc -l)
counter=0
echo "Found ${totalCount} entries in /clusterscanner/imageList.json"
while read -r line; do
  DATA_JSON=$(echo "${line}" | base64 -d | jq -cM .)
  if [[ "$(echo "${DATA_JSON}" | jq -r '.skip')" == "true" ]]; then
    echo "Skipping Image due to skip=true: $(echo ${DATA_JSON} | jq -r '.image') Namespace: $(echo ${DATA_JSON} | jq -r '.namespace') Environment: $(echo ${DATA_JSON} | jq -r '.environment')"
    continue
  fi
  if [[ "$(echo "${DATA_JSON}" | jq -r '.image')" == "" ]] || [[ "$(echo "${DATA_JSON}" | jq -r '.image')" == "null" ]]; then
    echo "Skipping Image: $(echo ${DATA_JSON} | jq -r '.image') Namespace: $(echo ${DATA_JSON} | jq -r '.namespace') Environment: $(echo ${DATA_JSON} | jq -r '.environment') because it is null"
    continue
  fi
  IS_SCAN_BASEIMAGE_LIFETIME=$(echo "${DATA_JSON}" | jq -r '.is_scan_baseimage_lifetime' | sed 's#null#true#')
  IS_SCAN_NEW_VERSION=$(echo "${DATA_JSON}" | jq -r '.is_scan_new_version' | sed 's#null#true#')
  is_scan_dependency_track=$(echo "${DATA_JSON}" | jq -r '.is_scan_dependency_track' | sed 's#null#false#') # Test-Mode
  dependencyTrackNotificationThresholds=$(echo "${DATA_JSON}" | jq -r '.dependencyTrackNotificationThresholds')
  if [ "${dependencyTrackNotificationThresholds}" == "null" ] || [ "${dependencyTrackNotificationThresholds}" == "" ]; then
    dependencyTrackNotificationThresholds="${DEPENDENCY_TRACK_NOTIFICATION_THRESHOLDS_DEFAULT}"
  fi
  namespace=$(echo "${DATA_JSON}" | jq -r .namespace)
  environment=$(echo "${DATA_JSON}" | jq -r .environment)
  team=$(echo "${DATA_JSON}" | jq -r .team)
  cp /clusterscanner/workflow.template.yml /tmp/template.yml
  scanjobPrefix="sj-"
  echo "Replacing placeholders in template, clusterImageScannerImageTag ${clusterImageScannerImageTag}, dependencyTrackNotificationThresholds: ${dependencyTrackNotificationThresholds}"
  sed -i "s~###SERVICE_ACCOUNT_NAME###~${SERVICE_ACCOUNT_NAME}~" /tmp/template.yml
  sed -i "s~###REGISTRY_SECRET###~${REGISTRY_SECRET}~" /tmp/template.yml
  sed -i "s~###DEPENDENCY_SCAN_CM###~${DEPENDENCY_SCAN_CM}~" /tmp/template.yml
  sed -i "s~###DEFECTDOJO_CM###~${DEFECTDOJO_CM}~" /tmp/template.yml
  sed -i "s~###DEFECTDOJO_SECRETS###~${DEFECTDOJO_SECRETS}~" /tmp/template.yml
  sed -i "s~###SCAN_ID###~${SCAN_ID}~" /tmp/template.yml
  sed -i "s~###dependencyCheckSuppressionsConfigMapName###~${dependencyCheckSuppressionsConfigMapName}~" /tmp/template.yml
  sed -i "s~###team###~${team}~" /tmp/template.yml
  sed -i "s~###appname###~$(echo "${DATA_JSON}" | jq -r .app_kubernetes_io_name)~" /tmp/template.yml
  sed -i "s~###appversion###~$(echo "${DATA_JSON}" | jq -r .app_version)~" /tmp/template.yml
  sed -i "s~###environment###~${environment}~" /tmp/template.yml
  sed -i "s~###namespace###~${namespace}~" /tmp/template.yml
  sed -i "s~###dependencyTrackNotificationThresholds###~${dependencyTrackNotificationThresholds}~" /tmp/template.yml
  sed -i "s~###scm_source_branch###~$(echo "${DATA_JSON}" | jq -r .scm_source_branch)~" /tmp/template.yml
  sed -i "s~###image###~$(echo "${DATA_JSON}" | jq -r .image)~" /tmp/template.yml
  sed -i "s~###image_id###~$(echo "${DATA_JSON}" | jq -r .image_id)~" /tmp/template.yml
  sed -i "s~###slack###~$(echo "${DATA_JSON}" | jq -r .slack)~" /tmp/template.yml
  sed -i "s~###rocketchat###~$(echo "${DATA_JSON}" | jq -r .rocketchat)~" /tmp/template.yml
  sed -i "s~###email###~$(echo "${DATA_JSON}" | jq -r .email)~" /tmp/template.yml
  sed -i "s~###is_scan_lifetime###~$(echo "${DATA_JSON}" | jq -r .is_scan_lifetime)~" /tmp/template.yml
  sed -i "s~###is_scan_baseimage_lifetime###~${IS_SCAN_BASEIMAGE_LIFETIME}~" /tmp/template.yml
  sed -i "s~###is_scan_distroless###~$(echo "${DATA_JSON}" | jq -r .is_scan_distroless)~" /tmp/template.yml
  sed -i "s~###is_scan_malware###~$(echo "${DATA_JSON}" | jq -r .is_scan_malware)~" /tmp/template.yml
  sed -i "s~###is_scan_dependency_^check###~$(echo "${DATA_JSON}" | jq -r .is_scan_dependency_check)~" /tmp/template.yml
  sed -i "s~###is_scan_dependency_track###~${is_scan_dependency_track}~" /tmp/template.yml
  sed -i "s~###is_scan_runasroot###~$(echo "${DATA_JSON}" | jq -r .is_scan_runasroot)~" /tmp/template.yml
  sed -i "s~###is_scan_new_version###~${IS_SCAN_NEW_VERSION}~" /tmp/template.yml
  sed -i "s~###scan_lifetime_max_days###~$(echo "${DATA_JSON}" | jq -r .scan_lifetime_max_days)~" /tmp/template.yml
  sed -i "s~###new_version_image_filter###~${NEW_VERSION_IMAGE_FIILTER}~" /tmp/template.yml
  sed -i "s~###imageRegistryBase###~${imageRegistryBase}~" /tmp/template.yml
  sed -i "s~###clusterImageScannerImageTag###~${clusterImageScannerImageTag}~" /tmp/template.yml

  echo "Setting workflow name"
  workflowGeneratedName="${scanjobPrefix}${environment}-${namespace}-${team}-"
  workflowGeneratedName="${workflowGeneratedName:0:62}"
  sed -i "s~###workflow_name###~${workflowGeneratedName}~" /tmp/template.yml

  cat /tmp/template.yml
  kubectl create -n "${JOB_EXECUTION_NAMESPACE}" -f /tmp/template.yml

  for outdatedJob in $(argo list --running -n "${JOB_EXECUTION_NAMESPACE}" --prefix "${scanjobPrefix}" | grep "Running *1h" | awk '{print $1}'); do
    echo "stopping ${outdatedJob} because it is running since over an hour without getting done"
    argo stop "${outdatedJob}" -n "${JOB_EXECUTION_NAMESPACE}"
  done
  counter=$((counter+1))
  echo "Job Status (Submitted Jobs/Total Jobs): ${counter}/${totalCount}"

  if [ "${MAX_RUNNING_JOBS_IN_QUEUE}" != "" ]; then
    # argo list --status Pending,Running results in Running only, maybe this will be fixed one day
    while [[ "$(argo list -n "${JOB_EXECUTION_NAMESPACE}" | grep "${scanjobPrefix}" | grep -c "Pending\|Running")" -gt ${MAX_RUNNING_JOBS_IN_QUEUE} ]]; do # this should be shifted to argo workflows, as soon as there is a solution for a cluster wide argo workflows setup
      echo "There are more than ${MAX_RUNNING_JOBS_IN_QUEUE} workflows pending/running, waiting 10 seconds until there are less"
      sleep 10
    done
  fi
done < /tmp/imageListSeparated.json
while [[ "$(argo list --running -n "${JOB_EXECUTION_NAMESPACE}" -l "clusterscanner.sda.org/scan-id=${SCAN_ID}" | tail --lines=+2 | wc -l)" -gt 0 ]]; do
  echo "There are still scans running, waiting another 10 seconds"
  sleep 10
done
echo "All scans have finished"
