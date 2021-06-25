#!/bin/bash

ENVIRONMENT_NAME="minikube"
IMAGE_JSON_FILE=/tmp/clusterscanner/output.json

DEFAULT_SKIP=false
DEFAULT_SCAN_LIFETIME="true"
DEFAULT_SCAN_DISTROLESS="true"
DEFAULT_SCAN_MALWARE="false"
DEFAULT_SCAN_DEPENDENCY_CHECK="true"
DEFAULT_SCAN_RUNASROOT="true"
SCAN_LIFETIME_ANNOTATION="clusterscanner.sdase.org/is-scan-lifetime"
SCAN_DISTROLESS_ANNOTATION="clusterscanner.sdase.org/is-scan-distroless"
SCAN_MALWARE_ANNOTATION="clusterscanner.sdase.org/is-scan-malware"
SCAN_DEPENDENCY_CHECK_ANNOTATION="clusterscanner.sdase.org/is-scan-dependency-check"
SCAN_RUNASROOT_ANNOTATION="clusterscanner.sdase.org/is-scan-runasroot"

mkdir /tmp/clusterscanner

source "pods.bash"

getPods ${IMAGE_JSON_FILE} ${ENVIRONMENT_NAME}
