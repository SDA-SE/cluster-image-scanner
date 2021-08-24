#!/bin/bash
# shellcheck disable=SC2086

# TODO This script needs to be refactored one day, in a way that only jsons are used (and no other env variables)

set -e

function setAttributes {
  snakeCaseVariableName=${1} # var_name
  camelCaseVariableName=$(echo "${snakeCaseVariableName}" | sed -r 's/(^|_)([a-z])/\U\2/g'| sed 's/\b\(.\)/\L&/g')

  value=$(echo $mapping | jq -r ".${snakeCaseVariableName}");
  echo "camelCaseVariableName: $camelCaseVariableName, ${value}"
  if [ "${value}" != "" ] && [ "${value}" != "null" ]; then
    setAttributesValue=${value}
  else
    setAttributesValue=""
  fi
}

if [ "${IMAGE_SKIP_NEGATIVE_LIST}" != "" ]; then
  SKIP_NEGATIVE_LIST_FILE=/home/code/config/imageNegativeList.json
  cp ${SKIP_NEGATIVE_LIST_FILE} /tmp/negative.json
  echo "${IMAGE_SKIP_NEGATIVE_LIST}" > /tmp/negative2.json
  jq -s '. | add' /tmp/negative.json /tmp/negative2.json > ${SKIP_NEGATIVE_LIST_FILE}
fi

if [ "${NAMESPACE_MAPPINGS}" != "" ] && [ -e config/namespace-mapping.json ]; then
  echo ${NAMESPACE_MAPPINGS} > /tmp/team-mapping.json
  NAMESPACE_MAPPINGS=$(jq -s '. | add' /tmp/team-mapping.json config/namespace-mapping.json)
fi

mappingNamespacesFlat="["
for teamStructure in $(echo $NAMESPACE_MAPPINGS | jq -rcM '.teams[] | @base64'); do
  content=$(echo $teamStructure | base64 -d);
  echo $content | jq '.configurations' > /tmp/configurations.json;
  for mappingNamespace in $(echo $content | jq -rcM '.namespaces[] | @base64'); do
    echo $mappingNamespace | base64 -d > /tmp/mappingNamespace.json ;
    mappingNamespacesFlat=${mappingNamespacesFlat}$(jq -s '.[0] * .[1]' /tmp/mappingNamespace.json /tmp/configurations.json)","
  done;
done

mappingNamespacesFlat=${mappingNamespacesFlat%?}; # remove last char ,
mappingNamespacesFlat="${mappingNamespacesFlat}]"
NAMESPACE_MAPPINGS=""

getPods() {
    echo "In getPods()"
    ENVIRONMENT_NAME=${2}
    IMAGE_JSON_FILE=${1}

    DESCRIPTION_JSON_FILE=/tmp/cluster-scan/description/service-description.json
    mkdir -p /tmp/cluster-scan/description/ || true

    if [ "${CONTACT_ANNOTATION_PREFIX}" == "" ]; then
      CONTACT_ANNOTATION_PREFIX="contact.sdase.org"
    fi
    if [ "${SKIP_ANNOTATION}" == "" ]; then
      SKIP_ANNOTATION="clusterscanner.sdase.org/skip"
    fi
    if [ "${TEAM_ANNOTATION}" == "" ]; then
      TEAM_ANNOTATION="$CONTACT_ANNOTATION_PREFIX/team"
    fi
    if [ "${NAMESPACE_SKIP_IMAGE_REGEX_ANNOTATION}" == "" ]; then
      NAMESPACE_SKIP_IMAGE_REGEX_ANNOTATION="clusterscanner.sdase.org/skip_regex"
    fi
    if [ "${SKIP_REGEX_DEFAULT}" == "" ]; then
      SKIP_REGEX_DEFAULT=""
    fi
    if [ "${DEFAULT_TEAM_NAME}" == "" ]; then
      DEFAULT_TEAM_NAME="nobody"
    fi
    if [ "${SCM_URL_ANNOTATION}" == "" ]; then
      SCM_URL_ANNOTATION="scm.sdase.org/source_url"
    fi
    if [ "${SCM_BRANCH_ANNOTATION}" == "" ]; then
      SCM_BRANCH_ANNOTATION="scm.sdase.org/source_branch"
    fi
    if [ "${SCM_RELEASE_ANNOTATION}" == "" ]; then
      SCM_RELEASE_ANNOTATION="scm.sdase.org/release"
    fi

    echo "[" > "${IMAGE_JSON_FILE}"
    echo "[]" > "${DESCRIPTION_JSON_FILE}"
    echo "\"Missing description on namespace:\"" > /tmp/cluster-scan/description/missing-service-description.txt

    # iteration needed due to memory limits in large deployments
    namespaces=$(kubectl get namespaces -o=jsonpath='{.items[*].metadata.name}')
    #namespaces="kube-system" # for testing
    for namespace in $namespaces; do
      description=""
      team=""
      email=""
      slack=""
      isScanLifetime=""
      isScanBaseimageLifetime=""
      isScanDistroless=""
      isScanMalware=""
      isScanDependencyCheck=""
      isScanRunasroot=""
      scanLifetimeMaxDays=""
      scanLifetimeMaxDays=""
      echo "Processing namespace ${namespace}"
      namespaceAnnotations=$(kubectl get namespace "${namespace}" -o jsonpath='{.metadata.annotations}' 2>&1 || true)
      if [ "$(echo "${namespaceAnnotations}" | grep -c "NotFound")" -gt 0 ]; then
        echo "Namespace ${namespace} doesn't exists anymore"
        continue
      fi

      descriptionMapping=""
      for mapping in $(echo ${mappingNamespacesFlat} | jq -rcM ".[] | @base64"); do
        mapping=$(echo ${mapping} | base64 -d)
        configurationsToMap=$(echo "${mapping}" | jq -r 'keys | .[]' | grep -v namespace_filter)
        export namespaceMapping=$(echo ${mapping} | jq -rcM '.namespace_filter')
        if [ $( echo "${namespace}" | grep "${namespaceMapping}" | wc -l) -ne 0 ]; then
          team=$(echo ${mapping} | jq -rcM '.team')
          descriptionMapping=$(echo ${mapping} | jq -rcM '.description')
          slack=$(echo ${mapping} | jq -rcM '.slack')
          for attributeName in ${configurationsToMap[@]}; do
              setAttributes ${attributeName}
              camelCaseVariableName=$(echo "${attributeName}" | sed -r 's/(^|_)([a-z])/\U\2/g'| sed 's/\b\(.\)/\L&/g')
              if [ "${setAttributesValue}" != "" ]; then
                declare "${camelCaseVariableName}=${setAttributesValue}" # would be create local variable in a function, therefore, it is not in the function
              fi
          done
        fi
      done

      if [ "${IS_FETCH_DESCRIPTION}" == "true" ]; then
        if [ "${description}" == "" ]; then
          description=$(echo "${namespaceAnnotations}" | jq -rcM ".[\"${DESCRIPTION_ANNOTATION}\"]" | sed -e 's#^null$##')
        fi
        namespaceInfo=$(echo "{\"namespace\": \""${namespace}"\", \"description\": \""${description}"\", \"team\": \"${team}\"}")
        newDescriptionFile=$(jq --argjson namespaceInfo "${namespaceInfo}" '. += [$namespaceInfo]' ${DESCRIPTION_JSON_FILE})
        echo ${newDescriptionFile} > ${DESCRIPTION_JSON_FILE}
        if [ "${description}" == "" ]; then
          echo "\"${namespace}\"" >> /tmp/cluster-scan/description/missing-service-description.txt
        fi
      fi

      if [ "${team}" == "" ] || [ "${team}" == "null" ]; then
        team=$(echo "${namespaceAnnotations}" | jq -r '."'${TEAM_ANNOTATION}'"' )
      fi
      if [ "${team}" == "" ] || [ "${team}" == "null" ]; then
        team="${DEFAULT_TEAM_NAME}"
      fi
      #echo "getting namespaceContact"
      if [ "${slack}" == "" ] || [ "${slack}" == "null" ]; then
        slack=$(echo "${namespaceAnnotations}" | jq -r '."'${CONTACT_ANNOTATION_PREFIX}'/slack"')
      fi
      if [ "${slack}" == "" ] || [ "${slack}" == "null" ]; then
          slack="#${team}${DEFAULT_SLACK_POSTFIX}"
      fi
      if [ "${email}" == "" ] || [ "${email}" == "null" ]; then
        email=$(echo "${namespaceAnnotations}" | jq -r '."'${CONTACT_ANNOTATION_PREFIX}'/email"')
      fi
      if [ "${email}" == "" ] || [ "${email}" == "null" ]; then
        if [ "${CONTACT_DEFAULT_EMAIL}" != "" ]; then
            email="${CONTACT_DEFAULT_EMAIL}"
        else
          email=""
        fi
      fi

      skipImageBasedOnNamespaceRegex=$(echo "${namespaceAnnotations}" | jq -r ".[\"${NAMESPACE_SKIP_IMAGE_REGEX_ANNOTATION}\"]")
      if [ "${skipImageBasedOnNamespaceRegex}" == "" ] || [ "${skipImageBasedOnNamespaceRegex}" == "null" ]; then
          skipImageBasedOnNamespaceRegex="NO-SKIP"
      fi

      skipNamespace=$(echo "${namespaceAnnotations}" | jq -r ".[\"${SKIP_ANNOTATION}\"]")
      echo "namespace: ${namespace} (NAMESPACE_SKIP_IMAGE_REGEX_ANNOTATION ${NAMESPACE_SKIP_IMAGE_REGEX_ANNOTATION}), applying the following order: pod annotation (not mentioned here), skipImageBasedOnNamespaceRegex: ${skipImageBasedOnNamespaceRegex} <- skipNamespace: ${skipNamespace} <- DEFAULT_SKIP: ${DEFAULT_SKIP}"

      if [ "${isScanLifetime}" == "" ] || [ "${isScanLifetime}" == "null" ]; then
        isScanLifetime=$(echo "${namespaceAnnotations}" | jq -r ".[\"${SCAN_LIFETIME_ANNOTATION}\"]")
      fi
      if [ "${isScanLifetime}" == "" ] || [ "${isScanLifetime}" == "null" ]; then
        isScanLifetime="${DEFAULT_SCAN_LIFETIME}"
      fi
      if [ "${isScanBaseimageLifetime}" == "" ] || [ "${isScanBaseimageLifetime}" == "null" ]; then
        isScanBaseimageLifetime=$(echo "${namespaceAnnotations}" | jq -r ".[\"${SCAN_BASEIMAGE_LIFETIME_ANNOTATION}\"]")
      fi
      if [ "${isScanBaseimageLifetime}" == "" ] || [ "${isScanBaseimageLifetime}" == "null" ]; then
        isScanBaseimageLifetime="${DEFAULT_SCAN_BASEIMAGE_LIFETIME}"
      fi
      if [ "${isScanDistroless}" == "" ] || [ "${isScanDistroless}" == "null" ]; then
        isScanDistroless=$(echo "${namespaceAnnotations}" | jq -r ".[\"${SCAN_DISTROLESS_ANNOTATION}\"]")
      fi
      if [ "${isScanDistroless}" == "" ] || [ "${isScanDistroless}" == "null" ]; then
        isScanDistroless="${DEFAULT_SCAN_DISTROLESS}"
      fi
      if [ "${isScanMalware}" == "" ] || [ "${isScanMalware}" == "null" ]; then
        isScanMalware=$(echo "${namespaceAnnotations}" | jq -r ".[\"${SCAN_DISTROLESS_ANNOTATION}\"]")
      fi
      if [ "${isScanMalware}" == "" ] || [ "${isScanMalware}" == "null" ]; then
        isScanMalware="${DEFAULT_SCAN_MALWARE}"
      fi
      if [ "${isScanDependencyCheck}" == "" ] || [ "${isScanDependencyCheck}" == "null" ]; then
        isScanDependencyCheck=$(echo "${namespaceAnnotations}" | jq -r ".[\"${SCAN_DEPENDENCY_CHECK_ANNOTATION}\"]")
      fi
      if [ "${isScanDependencyCheck}" == "" ] || [ "${isScanDependencyCheck}" == "null" ]; then
        isScanDependencyCheck="${DEFAULT_SCAN_DEPENDENCY_CHECK}"
      fi
      if [ "${isScanRunasroot}" == "" ] || [ "${isScanRunasroot}" == "null" ]; then
        isScanRunasroot=$(echo "${namespaceAnnotations}" | jq -r ".[\"${SCAN_RUNASROOT_ANNOTATION}\"]")
      fi
      if [ "${isScanRunasroot}" == "" ] || [ "${isScanRunasroot}" == "null" ]; then
        isScanRunasroot="${DEFAULT_SCAN_DEPENDENCY_CHECK}"
      fi
      if [ "${scanLifetimeMaxDays}" == "" ] || [ "${scanLifetimeMaxDays}" == "null" ]; then
        scanLifetimeMaxDays=$(echo "${namespaceAnnotations}" | jq -r ".[\"${SCAN_LIFETIME_MAX_DAYS_ANNOTATION}\"]")
      fi
      if [ "${scanLifetimeMaxDays}" == "" ] || [ "${scanLifetimeMaxDays}" == "null" ]; then
        scanLifetimeMaxDays="${DEFAULT_SCAN_LIFETIME_MAX_DAYS}"
      fi

      # TODO in the future maybe not only running pods
      pods=$(kubectl get pods --namespace=${namespace} --field-selector=status.phase=Running --output json)
      for pod in $(echo ${pods} | jq -rcM '.items[]? | @base64'); do
        echo "Pod in namespace ${namespace}"
        echo ${pod} | base64 -d | jq '{
          "email": .metadata.annotations["'${CONTACT_ANNOTATION_PREFIX}/'email"],
          "slack": .metadata.annotations["'${CONTACT_ANNOTATION_PREFIX}/'slack"],
          "scm_source_url": .metadata.annotations["'${SCM_URL_ANNOTATION}'"],
          "scm_source_branch": .metadata.annotations["'${SCM_BRANCH_ANNOTATION}'"],
          "scm_release": .metadata.annotations["'${SCM_RELEASE_ANNOTATION}'"],
          "skip": .metadata.annotations["'${SKIP_ANNOTATION}'"],
          "app_kubernetes_io_name": .metadata.labels["'${APP_NAME_LABEL}'"],
          "app_version": .metadata.labels["'${APP_VERSION_LABEL}'"],
          "team": "'${team}'",
          "namespace": "'${namespace}'",
          "container_running_as": "TODO",
          "environment": "'${ENVIRONMENT_NAME}'",
          "is_scan_lifetime": .metadata.annotations["'${SCAN_LIFETIME_ANNOTATION}'"],
          "is_scan_baseimage_lifetime": .metadata.annotations["'${SCAN_BASEIMAGE_LIFETIME_ANNOTATION}'"],
          "is_scan_distroless": .metadata.annotations["'${SCAN_DISTROLESS_ANNOTATION}'"],
          "is_scan_malware": .metadata.annotations["'${SCAN_MALWARE_ANNOTATION}'"],
          "is_scan_dependency_check": .metadata.annotations["'${SCAN_DEPENDENCY_CHECK_ANNOTATION}'"],
          "is_scan_runasroot": .metadata.annotations["'${SCAN_RUNASROOT_ANNOTATION}'"],
          "scan_lifetime_max_days": .metadata.annotations["'${SCAN_LIFETIME_MAX_DAYS_ANNOTATION}'"]
          }
          ' > /tmp/meta.json
        for container in $(echo $pod | base64 -d |  jq -rcM 'select(.status.containerStatuses != null) | .status.containerStatuses[] | @base64'); do
          echo "container in ${namespace}"

          # The following is an example:
          # { "image":"sha256:XXX",
          #   "imageID":"docker-pullable://k8s.gcr.io/ingress-nginx/controller@sha256:YYY" }
          # k8s.gcr.io/ingress-nginx/controller@sha256:XXX is not existing, therefore, we take the imageID
          echo "${container}" | base64 -d | jq '. |
          if .imageID|startswith("docker://") then .imageID="\("sha256:")\(.imageID|split(":")[2])" else . end |
          if .imageID|startswith("docker-pullable://") then if .image|startswith("sha") then .image=(.imageID|split("//"))[1] else  .imageID="\("sha256:")\(.imageID|split(":")[2])" end else . end |
          if .imageID|startswith("docker-pullable://") then if .image|startswith("sha") then .image=.imageID else  . end else . end |
          if .imageID|startswith("sha256:") then .imageID="\(.image|split(":")[0])\("@sha256:")\(.imageID|split(":")[1])" else . end |
          if .image|test("sha256:") then .imageID=.image else . end |
          if .imageID == null then .imageID=.image else . end | {
            "image": .image,
            "image_id": .imageID
          }' > /tmp/container.json

          image=$(cat /tmp/container.json | jq -rcM ".image")
          imageTag=$(echo "${image}" | sed 's#.*@sha256#sha256#' | sed 's#.*/.*:##')
          skip=${DEFAULT_SKIP}
          if [ "${skipNamespace}" == "true" ] || [ "${skipNamespace}" == "false" ]; then
            skip=${skipNamespace}
          else
            if [ "${NAMESPACE_SKIP_REGEX}" != "" ] && [ $(echo "${namespace}" | grep "${NAMESPACE_SKIP_REGEX}" | wc -l) -gt 0 ]; then
              echo "Skipping image due to namespace name and NAMESPACE_SKIP_REGEX ${NAMESPACE_SKIP_REGEX}"
              skip="true"
            fi
          fi

          for i in $(jq -rcM ".[]" config/imageNegativeList.json);do
            if [ "$(echo "${image}" | grep -c ${i})" -ne 0 ] && [ "${skip}" == "false" ]; then
              echo "skipping ${image} based on imageNegativeList with term ${i}"
              skip="true"
              break;
            fi
          done
          if [ "${IMAGE_SKIP_POSITIVE_LIST}" != "" ] && [ "$(echo "${image}" | grep -c "${IMAGE_SKIP_POSITIVE_LIST}")" -ne 1 ]; then
            echo "skipping ${image} based on IMAGE_SKIP_POSITIVE_LIST with regex ${IMAGE_SKIP_POSITIVE_LIST}"
            skip="true"
          fi

          echo "will combine both in ${namespace}"
          jq -s '. | add |
          if .skip == null then (if .image|test("'${skipImageBasedOnNamespaceRegex}'") then .skip=true else .skip='${skip}' end) else . end |
          if .email == null then .email="'${email}'" else . end |
          if .slack == null then .slack="'${slack}'" else . end |
          if .is_scan_distroless == null then .is_scan_distroless="'${isScanDistroless}'" else . end |
          if .is_scan_lifetime == null then .is_scan_lifetime="'${isScanLifetime}'" else . end |
          if .is_scan_baseimage_lifetime == null then .is_scan_baseimage_lifetime="'${isScanBaseimageLifetime}'" else . end |
          if .is_scan_malware == null then .is_scan_malware="'${isScanMalware}'" else . end |
          if .is_scan_dependency_check == null then .is_scan_dependency_check="'${isScanDependencyCheck}'" else . end |
          if .is_scan_runasroot == null then .is_scan_runasroot="'${isScanRunasroot}'" else . end |
          if .scan_lifetime_max_days == null then .scan_lifetime_max_days="'${scanLifetimeMaxDays}'" else . end |
          if .app_version == null then .app_version="'${imageTag}'" else . end |
          if .scm_release == null then .scm_release=.app_version else . end
          ' /tmp/container.json /tmp/meta.json >> "${IMAGE_JSON_FILE}"
        done
      done
    done
    ls -lah "${IMAGE_JSON_FILE}"

    # fix syntax between namespaces
    sed  -i -z 's#}\s{#},\n{#g' "${IMAGE_JSON_FILE}"
    echo "]" >> "${IMAGE_JSON_FILE}"
    jq 'unique' "${IMAGE_JSON_FILE}" > "${IMAGE_JSON_FILE}.tmp"
    mv "${IMAGE_JSON_FILE}.tmp" "${IMAGE_JSON_FILE}"
}
