#!/bin/bash
# shellcheck disable=SC2154 # variables come via env, so they are not assigned
set -ex

source ./scan-common.bash

if [ "${SERVICE_ACCOUNT_NAME}" == "" ]; then
  SERVICE_ACCOUNT_NAME="clusterscanner"
fi

#filter out amazon images
echo "Filtering out Amazon ECR images"
FILTERED_LIST=$(jq '.[] | select(.image|test("public\\.ecr\\.aws")|not)' </clusterscanner/imageList.json)
echo "$FILTERED_LIST" > /tmp/imageListFiltered.json


jq -cMr '.[] | @base64' /clusterscanner/imageList.json > /tmp/imageListSeparated.json
totalCount=$(cat /tmp/imageListFiltered.json | jq '.[].image' | wc -l)
counter=0
echo "Found ${totalCount} entries in /tmp/imageListFiltered.json"
while read -r line; do
  echo "Will read line"
  DATA_JSON=$(echo "${line}" | base64 -d | jq -cM .)
  if [[ "$(echo "${DATA_JSON}" | jq -r '.skip')" == "true" ]]; then
    echo "Skipping Image due to skip=true: $(echo "${DATA_JSON}" | jq -r '.image') Namespace: $(echo "${DATA_JSON}" | jq -r '.namespace') Environment: $(echo "${DATA_JSON}" | jq -r '.environment')"
    continue
  fi
  if [[ "$(echo "${DATA_JSON}" | jq -r '.image')" == "" ]] || [[ "$(echo "${DATA_JSON}" | jq -r '.image')" == "null" ]]; then
    echo "Skipping Image: $(echo "${DATA_JSON}" | jq -r '.image') Namespace: $(echo "${DATA_JSON}" | jq -r '.namespace') Environment: $(echo "${DATA_JSON}" | jq -r '.environment') because it is null"
    continue
  fi

  env

  if [ -n "$OVERRIDE_IS_SCAN_BASEIMAGE_LIFETIME" ]; then
    IS_SCAN_BASEIMAGE_LIFETIME="$OVERRIDE_IS_SCAN_BASEIMAGE_LIFETIME"
  else
    IS_SCAN_BASEIMAGE_LIFETIME=$(echo "${DATA_JSON}" | jq -r '.is_scan_baseimage_lifetime' | sed 's#null#true#')
  fi

  if [ -n "$OVERRIDE_IS_SCAN_NEW_VERSION" ]; then
    IS_SCAN_NEW_VERSION="$OVERRIDE_IS_SCAN_NEW_VERSION"
  else
    IS_SCAN_NEW_VERSION=$(echo "${DATA_JSON}" | jq -r '.is_scan_new_version' | sed 's#null#true#')
  fi

  if [ -n "$OVERRIDE_IS_SCAN_DEPENDENCY_TRACK" ]; then
    IS_SCAN_DEPENDENCY_TRACK="$OVERRIDE_IS_SCAN_DEPENDENCY_TRACK"
  else
    IS_SCAN_DEPENDENCY_TRACK=$(echo "${DATA_JSON}" | jq -r '.is_scan_dependency_track' | sed 's#null#true#')
  fi

  if [ -n "$OVERRIDE_IS_SCAN_LIFETIME" ]; then
    IS_SCAN_LIFETIME="$OVERRIDE_IS_SCAN_LIFETIME"
  else
    IS_SCAN_LIFETIME=$(echo "${DATA_JSON}" | jq -r '.is_scan_lifetime' | sed 's#null#true#')
  fi

  if [ -n "$OVERRIDE_IS_SCAN_DISTROLESS" ]; then
    IS_SCAN_DISTROLESS="$OVERRIDE_IS_SCAN_DISTROLESS"
  else
    IS_SCAN_DISTROLESS=$(echo "${DATA_JSON}" | jq -r .is_scan_distroless | sed 's#null#true#')
  fi

  if [ -n "$OVERRIDE_IS_SCAN_MALWARE" ]; then
    IS_SCAN_MALWARE="$OVERRIDE_IS_SCAN_MALWARE"
  else
    IS_SCAN_MALWARE=$(echo "${DATA_JSON}" | jq -r .is_scan_malware | sed 's#null#true#')
  fi

  if [ -n "$OVERRIDE_IS_SCAN_RUNASROOT" ]; then
    IS_SCAN_RUNASROOT="$OVERRIDE_IS_SCAN_RUNASROOT"
  else
    IS_SCAN_RUNASROOT=$(echo "${DATA_JSON}" | jq -r .is_scan_runasroot | sed 's#null#true#')
  fi


  containerType=$(echo "${DATA_JSON}" | jq -r '.container_type')
  namespace=$(echo "${DATA_JSON}" | jq -r .namespace)
  environment=$(echo "${DATA_JSON}" | jq -r .environment)
  team=$(echo "${DATA_JSON}" | jq -r .team)
  IMAGE=$(echo "${DATA_JSON}" | jq -r .image)
  IMAGE_ID=$(echo "${DATA_JSON}" | jq -r .image_id)
  export IMAGE_ID #used in parse_and_set_image_variables
  export IMAGE #used in parse_and_set_image_variables
  parse_and_set_image_variables
  
  
  appname=$(echo "${DATA_JSON}" | jq -r .app_kubernetes_io_name)
  
  if [ "${appname}" == "" ] || [ "${appname}" == "null" ]; then
    #IMAGE_NAME is exportet from parse_and_set_image_variables()
    appname="${IMAGE_NAME}"
    appname="${appname%@*}"
    appname="${appname%:*}"
    echo "app_kubernetes_io_name is empty, setting to: ${appname}"
  fi
  appversion=$(echo "${DATA_JSON}" | jq -r .app_kubernetes_io_version)
  if [ "${appversion}" == "" ] || [ "${appversion}" == "null" ]; then
    appversion="${IMAGE_TAG}"
  fi

  cp /clusterscanner/workflow.template.yml /tmp/template.yml
  scanjobPrefix="sj-"
  echo "Replacing placeholders in template, clusterImageScannerImageTag ${clusterImageScannerImageTag}, containerType: ${containerType}"
  sed -i "s~###SERVICE_ACCOUNT_NAME###~${SERVICE_ACCOUNT_NAME}~" /tmp/template.yml
  sed -i "s~###REGISTRY_SECRET###~${REGISTRY_SECRET}~" /tmp/template.yml
  sed -i "s~###DEPENDENCY_SCAN_CM###~${DEPENDENCY_SCAN_CM}~" /tmp/template.yml
  sed -i "s~###DEFECTDOJO_CM###~${DEFECTDOJO_CM}~" /tmp/template.yml
  sed -i "s~###DEFECTDOJO_SECRETS###~${DEFECTDOJO_SECRETS}~" /tmp/template.yml
  sed -i "s~###SCAN_ID###~${SCAN_ID}~" /tmp/template.yml
  sed -i "s~###team###~${team}~" /tmp/template.yml
  sed -i "s~###appname###~${appname}~" /tmp/template.yml
  sed -i "s~###appversion###~${appversion}~" /tmp/template.yml
  sed -i "s~###environment###~${environment}~" /tmp/template.yml
  sed -i "s~###namespace###~${namespace}~" /tmp/template.yml
  sed -i "s~###containerType###~${containerType}~" /tmp/template.yml
  sed -i "s~###scm_source_branch###~$(echo "${DATA_JSON}" | jq -r .scm_source_branch)~" /tmp/template.yml
  sed -i "s~###image###~$(echo "${DATA_JSON}" | jq -r .image)~" /tmp/template.yml
  sed -i "s~###image_id###~$(echo "${DATA_JSON}" | jq -r .image_id)~" /tmp/template.yml
  sed -i "s~###slack###~$(echo "${DATA_JSON}" | jq -r .slack)~" /tmp/template.yml
  sed -i "s~###email###~$(echo "${DATA_JSON}" | jq -r .email)~" /tmp/template.yml
  sed -i "s~###is_scan_lifetime###~${IS_SCAN_LIFETIME}~" /tmp/template.yml
  sed -i "s~###is_scan_baseimage_lifetime###~${IS_SCAN_BASEIMAGE_LIFETIME}~" /tmp/template.yml
  sed -i "s~###is_scan_distroless###~${IS_SCAN_DISTROLESS}~" /tmp/template.yml
  sed -i "s~###is_scan_malware###~${IS_SCAN_MALWARE}~" /tmp/template.yml
  sed -i "s~###is_scan_dependency_track###~${IS_SCAN_DEPENDENCY_TRACK}~" /tmp/template.yml
  sed -i "s~###is_scan_runasroot###~${IS_SCAN_RUNASROOT}~" /tmp/template.yml
  sed -i "s~###is_scan_new_version###~${IS_SCAN_NEW_VERSION}~" /tmp/template.yml
  sed -i "s~###scan_lifetime_max_days###~$(echo "${DATA_JSON}" | jq -r .scan_lifetime_max_days)~" /tmp/template.yml
  sed -i "s~###new_version_image_filter###~${NEW_VERSION_IMAGE_FIILTER}~" /tmp/template.yml
  sed -i "s~###imageRegistryBase###~${imageRegistryBase}~" /tmp/template.yml
  sed -i "s~###clusterImageScannerImageTag###~${clusterImageScannerImageTag}~" /tmp/template.yml
  sed -i "s~###slackTokenSecretName###~${slackTokenSecretName}~" /tmp/template.yml
  sed -i "s~###errorTargets###~${errorTargets}~" /tmp/template.yml


  echo "Setting workflow name"
  workflowGeneratedName="${scanjobPrefix}${environment:0:10}-${namespace:0:10}-${team:0:10}-"
  workflowGeneratedName="${workflowGeneratedName:0:50}"
  workflowGeneratedName=$(echo "${workflowGeneratedName:0:50}" | tr '[:upper:]' '[:lower:]') # argo workflows must be lower case
  sed -i "s~###workflow_name###~${workflowGeneratedName}~" /tmp/template.yml

  if [ "${IS_PRINT_TEMPLATE}" == "true" ]; then
    cat /tmp/template.yml
  fi
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
