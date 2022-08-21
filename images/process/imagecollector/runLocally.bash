#!/bin/bash

export ENVIRONMENT_NAME="minikube"
export IMAGE_JSON_FILE=/tmp/cluster-scan/output.json
export IS_FETCH_DESCRIPTION="true"
export TEAM_MAPPING='[{ "namespace_filter": "verdaccio-", "team": "operations", "description": "verdaccio is about..." }]'

DESCRIPTION_ANNOTATION="sdase.org/description"
export NAMESPACE_TO_SCAN_ANNOTATION="clusterscanner.sdase.org/namespace_filter"
export DEFAULT_SKIP="false"
export DEFAULT_SCAN_LIFETIME="true"
export DEFAULT_SCAN_DISTROLESS="true"
export DEFAULT_SCAN_MALWARE="false"
export DEFAULT_SCAN_DEPENDENCY_CHECK="true"
export DEFAULT_SCAN_RUNASROOT="true"
export DEFAULT_SCAN_BASEIMAGE_LIFETIME="true"
export DEFAULT_SCAN_DEPENDENCY_TRACK="false"
export DEFAULT_CONTAINER_TYPE="application"
export SCAN_LIFETIME_ANNOTATION="clusterscanner.sdase.org/is-scan-lifetime"
export SCAN_DISTROLESS_ANNOTATION="clusterscanner.sdase.org/is-scan-distroless"
export SCAN_MALWARE_ANNOTATION="clusterscanner.sdase.org/is-scan-malware"
export SCAN_DEPENDENCY_CHECK_ANNOTATION="clusterscanner.sdase.org/is-scan-dependency-check"
export SCAN_RUNASROOT_ANNOTATION="clusterscanner.sdase.org/is-scan-runasroot"
#export NAMESPACE_SKIP_REGEX="\-pr\-"
export DEFAULT_TEAM_NAME="test"
export DEFAULT_SLACK_POSTFIX="-security"
mkdir /tmp/cluster-scan
export DEFAULT_SCAN_LIFETIME_MAX_DAYS=14
export NAMESPACE_MAPPINGS='{
      "teams": [
        {
          "namespaces": [
            {"namespace_filter": "argo", "description": "used for deployment"},
            {"namespace_filter": "kube-", "description": "kube-system is the namespace for objects created by the Kubernetes system, containing services which are needed to run Kubernetes"}
          ],
          "configurations": {
            "team": "operations",
            "is_scan_lifetime": "true",
            "is_scan_baseimage_lifetime": "false",
            "is_scan_distroless": "false",
            "is_scan_malware": "false",
            "is_scan_dependency_check": "false",
            "is_scan_runasroot": "false"
          }
        }
      ]
    }'

source "pods.bash"

getPods "${IMAGE_JSON_FILE}" "${ENVIRONMENT_NAME}" ${DESCRIPTION_JSON_FILE}
