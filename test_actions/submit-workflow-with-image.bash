#!/bin/bash

WORKFLOW_FILE=/tmp/image-workflow.yml
cp ../images/process/workflow-runner/workflow.template.yml ${WORKFLOW_FILE}

IMAGE="quay.io/sdase/terminal-backend-public:1.34.2"
IMAGE_ID="${IMAGE}"

sed -i 's|###workflow_name###|test-scan|g' ${WORKFLOW_FILE}

sed -i 's|###REGISTRY_SECRET###|registry-default|g' ${WORKFLOW_FILE}
sed -i 's|###DEPENDENCY_SCAN_CM###|dependency-check-db|g' ${WORKFLOW_FILE}
sed -i 's|###DEFECTDOJO_CM###|defectdojo|g' ${WORKFLOW_FILE}
sed -i 's|###DEFECTDOJO_SECRETS###|defectdojo|g' ${WORKFLOW_FILE}
sed -i 's|###SCAN_ID###|test-workflow|g' ${WORKFLOW_FILE}
sed -i 's|###team###|test|g' ${WORKFLOW_FILE}
sed -i 's|###appname###|test|g' ${WORKFLOW_FILE}
sed -i 's|###appversion###|0.1|g' ${WORKFLOW_FILE}
sed -i 's|###environment###|test|g' ${WORKFLOW_FILE}
sed -i 's|###namespace###|test|g' ${WORKFLOW_FILE}
sed -i 's|###scm_source_branch###||g' ${WORKFLOW_FILE}
sed -i "s|###image###|${IMAGE}|g" ${WORKFLOW_FILE}
sed -i "s|###image_id###|${IMAGE_ID}|g" ${WORKFLOW_FILE}
sed -i 's|###slack###|#security-notifications-test|g' ${WORKFLOW_FILE}
sed -i 's|###rocketchat###||g' ${WORKFLOW_FILE}
sed -i 's|###email###||g' ${WORKFLOW_FILE}
sed -i 's|###is_scan_baseimage_lifetime###|true|g' ${WORKFLOW_FILE}
sed -i 's|###is_scan_lifetime###|true|g' ${WORKFLOW_FILE}
sed -i 's|###is_scan_distroless###|true|g' ${WORKFLOW_FILE}
sed -i 's|###is_scan_malware###|true|g' ${WORKFLOW_FILE}
sed -i 's|###is_scan_dependency_check###|true|g' ${WORKFLOW_FILE}
sed -i 's|###is_scan_runasroot###|true|g' ${WORKFLOW_FILE}
sed -i 's|###is_scan_new_version###|true|g' ${WORKFLOW_FILE}
sed -i 's|###is_scan_dependency_track###|true|g' ${WORKFLOW_FILE}
sed -i 's|###scan_lifetime_max_days###|14|g' ${WORKFLOW_FILE}
sed -i 's|###dependencyCheckSuppressionsConfigMapName###|suppressions-sda|g' ${WORKFLOW_FILE}
sed -i 's|###new_version_image_filter###|.*|g' ${WORKFLOW_FILE}
sed -i 's|###imageRegistryBase###|quay.io/sdase|g' ${WORKFLOW_FILE}
sed -i 's|###containerType###|application|g' ${WORKFLOW_FILE}
sed -i 's|###clusterImageScannerImageTag###|2|g' ${WORKFLOW_FILE}
sed -i 's|###slackTokenSecretName###|slacktoken|g' ${WORKFLOW_FILE}
sed -i 's|###errorTargets###|[{ "channel":"#security-notifications-test", "type": "slack"} ]|g' ${WORKFLOW_FILE}

argo submit -n clusterscanner ${WORKFLOW_FILE}