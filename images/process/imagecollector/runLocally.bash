#!/bin/bash

export ENVIRONMENT_NAME="minikube"
export IMAGE_JSON_FILE=/tmp/clusterscanner/output.json

export DEFAULT_SKIP=false
export DEFAULT_SCAN_LIFETIME="true"
export DEFAULT_SCAN_DISTROLESS="true"
export DEFAULT_SCAN_MALWARE="false"
export DEFAULT_SCAN_DEPENDENCY_CHECK="true"
export DEFAULT_SCAN_RUNASROOT="true"
export SCAN_LIFETIME_ANNOTATION="clusterscanner.sdase.org/is-scan-lifetime"
export SCAN_DISTROLESS_ANNOTATION="clusterscanner.sdase.org/is-scan-distroless"
export SCAN_MALWARE_ANNOTATION="clusterscanner.sdase.org/is-scan-malware"
export SCAN_DEPENDENCY_CHECK_ANNOTATION="clusterscanner.sdase.org/is-scan-dependency-check"
export SCAN_RUNASROOT_ANNOTATION="clusterscanner.sdase.org/is-scan-runasroot"

mkdir /tmp/clusterscanner

source "pods.bash"

getPods "${IMAGE_JSON_FILE}" "${ENVIRONMENT_NAME}"
