set -e

if [ "${IMAGE_SKIP_NEGATIVE_LIST}" != "" ]; then
  SKIP_NEGATIVE_LIST_FILE=/home/code/config/imageNegativeList.json
  cp ${SKIP_NEGATIVE_LIST_FILE} /tmp/negative.json
  echo ${IMAGE_SKIP_NEGATIVE_LIST} > /tmp/negative2.json
  jq -s '. | add' /tmp/negative.json /tmp/negative2.json > ${SKIP_NEGATIVE_LIST_FILE}
fi

getPods() {
    echo "In getPods()"
    ENVIRONMENT_NAME=$2
    IMAGE_JSON_FILE=$1

    if [ "$CONTACT_ANNOTATION_PREFIX" == "" ]; then
      CONTACT_ANNOTATION_PREFIX="contact.sdase.org"
    fi
    if [ "$SKIP_ANNOTATION" == "" ]; then
      SKIP_ANNOTATION="clusterscanner.sdase.org/skip"
    fi
    if [ "$TEAM_ANNOTATION" == "" ]; then
      TEAM_ANNOTATION="$CONTACT_ANNOTATION_PREFIX/team"
    fi
    if [ "$SKIP_REGEX_ANNOTATION" == "" ]; then
      SKIP_REGEX_ANNOTATION="clusterscanner.sdase.org/skip_regex"
    fi
    if [ "$SKIP_REGEX_DEFAULT" == "" ]; then
      SKIP_REGEX_DEFAULT=""
    fi
    if [ "$DEFAULT_TEAM_NAME" == "" ]; then
      DEFAULT_TEAM_NAME="nobody"
    fi
    if [ "$SCM_URL_ANNOTATION" == "" ]; then
      SCM_URL_ANNOTATION="scm.sdase.org/source_url"
    fi
    if [ "$SCM_BRANCH_ANNOTATION=" == "" ]; then
      SCM_BRANCH_ANNOTATION="scm.sdase.org/source_branch"
    fi
    if [ "$SCM_RELEASE_ANNOTATION=" == "" ]; then
      SCM_RELEASE_ANNOTATION="scm.sdase.org/release"
    fi

    echo "[" > ${IMAGE_JSON_FILE}

    # iteration needed due to memory limits in large deployments
    namespaces=$(kubectl get namespaces -o=jsonpath='{.items[*].metadata.name}')
    #namespaces="kube-system" # for testing
    for namespace in $namespaces; do
      echo "Processing namespace $namespace"
      execution=true
      namespaceAnnotations=$(kubectl get namespace $namespace -o jsonpath='{.metadata.annotations}' || execution=false)
      if [ "${execution}" == "false" ]; then
        echo "Namespace ${namespace} doesn't exists anymore"
        continue
      fi

      team=$(echo $namespaceAnnotations | jq -r '."'$TEAM_ANNOTATION'"' )
      if [ "$team" == "" ] || [ "$team" == "null" ]; then
        team="$DEFAULT_TEAM_NAME"
      fi
      #echo "getting namespaceContact"
      namespaceContactSlack=$(echo $namespaceAnnotations | jq -r '."'$CONTACT_ANNOTATION_PREFIX'/slack"')
      if [ "$namespaceContactSlack" == "" ] || [ "$namespaceContactSlack" == "null" ]; then
        namespaceContactSlack="#${team}${DEFAULT_SLACK_POSTFIX}"
      fi
      namespaceContactEmail=$(echo $namespaceAnnotations | jq -r '."'$CONTACT_ANNOTATION_PREFIX'/email"')
      if [ "$namespaceContactEmail" == "" ] || [ "$namespaceContactEmail" == "null" ]; then
        if [ "$CONTACT_DEFAULT_EMAIL" != "" ]; then
            namespaceContactEmail="$CONTACT_DEFAULT_EMAIL"
        else
          namespaceContactEmail=""
        fi
      fi
      skipNamespaceRegex=$(echo $namespaceAnnotations | jq -r '."'$SKIP_REGEX_ANNOTATION'"')
      if [ "$skipNamespaceRegex" == "" ] || [ "$skipNamespaceRegex" == "null" ]; then
        skipNamespaceRegex="NO-SKIP"
      fi
      skipNamespace=$(echo $namespaceAnnotations | jq -r '."'$SKIP_ANNOTATION'"')
      echo "namespace: ${namespace} (SKIP_REGEX_ANNOTATION ${SKIP_REGEX_ANNOTATION}), applying the following order: pod annotiation (not mentioned here), skipNamespaceRegex: ${skipNamespaceRegex} <- skipNamespace: ${skipNamespace} <- DEFAULT_SKIP: ${DEFAULT_SKIP}"

      isScanLifetime=$(echo $namespaceAnnotations | jq -r '."'$SCAN_LIFETIME_ANNOTATION'"' )
      if [ "$isScanLifetime" == "" ] || [ "$isScanLifetime" == "null" ]; then
        isScanLifetime="$DEFAULT_SCAN_LIFETIME"
      fi
      isScanDistroless=$(echo $namespaceAnnotations | jq -r '."'$SCAN_DISTROLESS_ANNOTATION'"' )
      if [ "$isScanDistroless" == "" ] || [ "$isScanDistroless" == "null" ]; then
        isScanDistroless="$DEFAULT_SCAN_DISTROLESS"
      fi
      isScanMalware=$(echo $namespaceAnnotations | jq -r '."'$SCAN_DISTROLESS_ANNOTATION'"' )
      if [ "$isScanMalware" == "" ] || [ "$isScanMalware" == "null" ]; then
        isScanMalware="$DEFAULT_SCAN_MALWARE"
      fi
      isScanDependencyCheck=$(echo $namespaceAnnotations | jq -r '."'$SCAN_DEPENDENCY_CHECK_ANNOTATION'"' )
      if [ "$isScanDependencyCheck" == "" ] || [ "$isScanDependencyCheck" == "null" ]; then
        isScanDependencyCheck="$DEFAULT_SCAN_DEPENDENCY_CHECK"
      fi
      isScanRunAsRoot=$(echo $namespaceAnnotations | jq -r '."'$SCAN_RUNASROOT_ANNOTATION'"' )
      if [ "$isScanRunAsRoot" == "" ] || [ "$isScanRunAsRoot" == "null" ]; then
        isScanRunAsRoot="$DEFAULT_SCAN_DEPENDENCY_CHECK"
      fi
      lifetimeMaxDays=$(echo $namespaceAnnotations | jq -r '."'$SCAN_LIFETIME_MAX_DAYS_ANNOTATION'"' )
      if [ "$lifetimeMaxDays" == "" ] || [ "$lifetimeMaxDays" == "null" ]; then
        lifetimeMaxDays="$DEFAULT_SCAN_LIFETIME_MAX_DAYS"
      fi


      # TODO in the future maybe not only running pods
      pods=$(kubectl get pods --namespace=$namespace --field-selector=status.phase=Running --output json)
      for pod in $(echo ${pods} | jq -rcM '.items[]? | @base64'); do
        echo "Pod in namespace $namespace"
        echo ${pod} | base64 -d | jq '{
          "email": .metadata.annotations["'$CONTACT_ANNOTATION_PREFIX/'email"],
          "slack": .metadata.annotations["'$CONTACT_ANNOTATION_PREFIX/'slack"],
          "scm_source_url": .metadata.annotations["'$SCM_URL_ANNOTATION'"],
          "scm_source_branch": .metadata.annotations["'$SCM_BRANCH_ANNOTATION'"],
          "scm_release": .metadata.annotations["'$SCM_RELEASE_ANNOTATION'"],
          "skip": .metadata.annotations["'$SKIP_ANNOTATION'"],
          "app_kubernetes_io_name": .metadata.labels["'$APP_NAME_LABEL'"],
          "app_version": .metadata.labels["'$APP_VERSION_LABEL'"],
          "team": "'$team'",
          "namespace": "'$namespace'",
          "container_running_as": "TODO",
          "environment": "'$ENVIRONMENT_NAME'",
          "is_scan_lifetime": .metadata.annotations["'$SCAN_LIFETIME_ANNOTATION'"],
          "is_scan_distroless": .metadata.annotations["'$SCAN_DISTROLESS_ANNOTATION'"],
          "is_scan_malware": .metadata.annotations["'$SCAN_MALWARE_ANNOTATION'"],
          "is_scan_dependency_check": .metadata.annotations["'$SCAN_DEPENDENCY_CHECK_ANNOTATION'"],
          "is_scan_runasroot": .metadata.annotations["'$SCAN_RUNASROOT_ANNOTATION'"],
          "scan_lifetime_max_days": .metadata.annotations["'$SCAN_LIFETIME_MAX_DAYS_ANNOTATION'"]
          }
          ' > /tmp/meta.json
        for container in $(echo $pod | base64 -d |  jq -rcM 'select(.status.containerStatuses != null) | .status.containerStatuses[] | @base64'); do
          echo "container in $namespace"
          image=$(echo "${container}" | base64 -d | jq -rcM ".image")
          imageTag=$(echo $image | sed 's#.*@sha256#sha256#' | sed 's#.*/.*:##')
          skip=${DEFAULT_SKIP}
          if [ "${skipNamespace}" == "true" ] || [ "${skipNamespace}" == "false" ]; then
            skip=${skipNamespace}
          fi
          for i in $(cat config/imageNegativeList.json | jq -rcM ".[]");do
            if [ $(echo "${image}" | grep ${i} | wc -l) -ne 0 ] && [ "${skip}" == "false" ]; then
              echo "skipping ${image} based on imageNegativeList with term ${i}"
              skip="true"
              break;
            fi
          done
          if [ "${IMAGE_SKIP_POSITIVE_LIST}" != "" ] && [ $(echo ${image} | grep ${IMAGE_SKIP_POSITIVE_LIST} | wc -l) -ne 1 ]; then
            echo "skipping ${image} based on IMAGE_SKIP_POSITIVE_LIST with regex ${IMAGE_SKIP_POSITIVE_LIST}"
            skip="true"
          fi
          echo ${container} | base64 -d | jq '{
            "image": .image,
            "image_id": .imageID
          }' > /tmp/container.json
          echo "will combine both in ${namespace}"
          cleanImage=$(echo ${image} | sed 's#:[[:alnum:].-]*$##' | sed 's#@.*##')
          jq -s '. | add |
          if .skip == null then (if .image|test("'${skipNamespaceRegex}'") then .skip=true else .skip='${skip}' end) else . end |
          if .app_kubernetes_io_name == null then .app_kubernetes_io_name="'${cleanImage}'" else . end |
          if .app_version == null then .app_version="'${imageTag}'" else . end |
          if .scm_release == null then .scm_release=.app_version else . end |
          if .email == null then .email="'${namespaceContactEmail}'" else . end |
          if .slack == null then .slack="'${namespaceContactSlack}'" else . end |
          if .is_scan_distroless == null then .is_scan_distroless="'${isScanDistroless}'" else . end |
          if .is_scan_lifetime == null then .is_scan_lifetime="'${isScanLifetime}'" else . end |
          if .is_scan_malware == null then .is_scan_malware="'${isScanMalware}'" else . end |
          if .is_scan_dependency_check == null then .is_scan_dependency_check="'${isScanDependencyCheck}'" else . end |
          if .is_scan_runasroot == null then .is_scan_runasroot="'${isScanRunAsRoot}'" else . end |
          if .scan_lifetime_max_days == null then .scan_lifetime_max_days="'${lifetimeMaxDays}'" else . end |
          if .image_id|startswith("docker://") then .image_id="\("sha256:")\(.image_id|split(":")[2])" else . end |
          if .image_id|startswith("docker-pullable://") then .image_id="\("sha256:")\(.image_id|split(":")[2])" else . end |
          if .image_id|startswith("sha256:") then .image_id="\(.image|split(":")[0])\("@sha256:")\(.image_id|split(":")[1])" else . end |
          if .image|test("sha256:") then .image_id=.image else . end |
          if .image_id == null then .image_id=.image else . end ' /tmp/container.json /tmp/meta.json >> ${IMAGE_JSON_FILE}
        done
      done
    done
    ls -lah ${IMAGE_JSON_FILE}

    # fix syntax between namespaces
    sed  -i -z 's#}\s{#},\n{#g' ${IMAGE_JSON_FILE}
    echo "]" >> ${IMAGE_JSON_FILE}
    jq 'unique' ${IMAGE_JSON_FILE} > ${IMAGE_JSON_FILE}.tmp
    mv ${IMAGE_JSON_FILE}.tmp ${IMAGE_JSON_FILE}
}
