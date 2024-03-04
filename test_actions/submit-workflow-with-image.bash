#!/bin/bash

WORKFLOW_FILE=/tmp/image-workflow.yml
cp ../images/process/workflow-runner/workflow.template.yml ${WORKFLOW_FILE}

IMAGE="quay.io/sdase/cluster-image-scanner-test-image:2"
IMAGE_ID="${IMAGE}"

currentBranch=$(git branch --show-current)
echo "currentBranch ${currentBranch}"
if [ "${currentBranch}" == "master" ];then
    currentBranch="2"
fi

sed -i.bak 's|###workflow_name###|test-scan|g' ${WORKFLOW_FILE}

sed -i.bak 's|###REGISTRY_SECRET###|registry-default|g' ${WORKFLOW_FILE}
sed -i.bak 's|###DEFECTDOJO_CM###|defectdojo|g' ${WORKFLOW_FILE}
sed -i.bak 's|###DEFECTDOJO_SECRETS###|defectdojo|g' ${WORKFLOW_FILE}
sed -i.bak 's|###SCAN_ID###|test-workflow|g' ${WORKFLOW_FILE}
sed -i.bak 's|###team###|test|g' ${WORKFLOW_FILE}
sed -i.bak 's|###appname###|test|g' ${WORKFLOW_FILE}
sed -i.bak 's|###appversion###|0.1|g' ${WORKFLOW_FILE}
sed -i.bak 's|###environment###|test|g' ${WORKFLOW_FILE}
sed -i.bak 's|###namespace###|test|g' ${WORKFLOW_FILE}
sed -i.bak 's|###scm_source_branch###||g' ${WORKFLOW_FILE}
sed -i.bak "s|###image###|${IMAGE}|g" ${WORKFLOW_FILE}
sed -i.bak "s|###image_id###|${IMAGE_ID}|g" ${WORKFLOW_FILE}
sed -i.bak 's|###slack###|#security-notifications-test|g' ${WORKFLOW_FILE}
sed -i.bak 's|###email###||g' ${WORKFLOW_FILE}
sed -i.bak 's|###is_scan_baseimage_lifetime###|true|g' ${WORKFLOW_FILE}
sed -i.bak 's|###is_scan_lifetime###|true|g' ${WORKFLOW_FILE}
sed -i.bak 's|###is_scan_distroless###|true|g' ${WORKFLOW_FILE}
sed -i.bak 's|###is_scan_malware###|true|g' ${WORKFLOW_FILE}
sed -i.bak 's|###is_scan_runasroot###|true|g' ${WORKFLOW_FILE}
sed -i.bak 's|###is_scan_new_version###|true|g' ${WORKFLOW_FILE}
sed -i.bak 's|###is_scan_dependency_track###|true|g' ${WORKFLOW_FILE}
sed -i.bak 's|###scan_lifetime_max_days###|14|g' ${WORKFLOW_FILE}
sed -i.bak 's|###dependencyCheckSuppressionsConfigMapName###|suppressions-sda|g' ${WORKFLOW_FILE}
sed -i.bak 's|###new_version_image_filter###|.*|g' ${WORKFLOW_FILE}
sed -i.bak 's|###imageRegistryBase###|quay.io/sdase|g' ${WORKFLOW_FILE}
sed -i.bak 's|###containerType###|application|g' ${WORKFLOW_FILE}
sed -i.bak "s|###clusterImageScannerImageTag###|${currentBranch}|g" ${WORKFLOW_FILE}
sed -i.bak 's|###slackTokenSecretName###|slacktoken|g' ${WORKFLOW_FILE}
sed -i.bak 's|###errorTargets###|[{ "channel":"#security-notifications-test", "type": "slack"} ]|g' ${WORKFLOW_FILE}

argo submit -n clusterscanner ${WORKFLOW_FILE}
