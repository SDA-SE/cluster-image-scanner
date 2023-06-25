#!/bin/bash
set -e

if [ $# -ne 7 ]; then
  echo "Parameters are not set correctly"
  exit 1
fi

source "${mnt}/clusterscanner/scan-common.bash"

REGISTRY=$1
ORGANIZATION=$2
IMAGE_NAME=$3
VERSION=$4
REGISTRY_USER=$5
REGISTRY_TOKEN=$6
BUILD_EXPORT_OCI_ARCHIVES=$7

MAJOR=$(echo "${VERSION}" | tr  '.' "\n" | sed -n 1p)
MINOR=$(echo "${VERSION}" | tr  '.' "\n" | sed -n 2p)

oci_prefix="org.opencontainers.image"
descr="Check for new version of a semantic image tag in registry"

trap cleanup INT EXIT
cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
}

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
build_dir="${dir}/build"

base_image="quay.io/sdase/cluster-image-scanner-base:2"
ctr="$( buildah from --pull --quiet "${base_image}")"
mnt="$( buildah mount "${ctr}" )"

cp module.bash "${mnt}/clusterscanner/"
cp env.bash "${mnt}/clusterscanner/"
cp ../ddTemplate.json "${mnt}/clusterscanner/new-version.json"
JSON=$(<"/${mnt}/clusterscanner/new-version.json")
JSON=$(add_json_field severity "Medium" "$JSON")
#jq --arg severity "Medium" \
#  '.findings[].severity = $severity' \
#  "${mnt}/clusterscanner/new-version.json" > "${mnt}/clusterscanner/new-version.json"
if [ -n "$JSON" ]; then
  echo "JSON" > "/${mnt}/clusterscanner/new-version.json"
else 
  echo "error generating JSON file"
  exit 1
fi

../parseMarkdownToCreateDefectDojoText.bash ../../../docs/user/scans/new-version.md Relevance ${mnt}/clusterscanner/new-version.json
../parseMarkdownToCreateDefectDojoText.bash ../../../docs/user/scans/new-version.md Response ${mnt}/clusterscanner/new-version.json

# Get a bill of materials
base_bill_of_materials_hash=$(buildah inspect --type image "${base_image}"  | jq '.OCIv1.config.Labels."io.sda-se.image.bill-of-materials-hash"')
#echo "base_bill_of_materials_hash $base_bill_of_materials_hash"
bill_of_materials_hash="$( ( cat "${0}";
  echo "${base_bill_of_materials_hash}"; \
  cat ./*; \
  ) | sha256sum | awk '{ print $1 }' )"
echo "bill_of_materials: $bill_of_materials_hash";
buildah config \
  --label "${oci_prefix}.url=https://quay.io/sdase/cluster-image-scanner-scan-new-version" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/clusterscanner-scan-new-version" \
  --label "${oci_prefix}.revision=$( git rev-parse HEAD )" \
  --label "${oci_prefix}.version=${VERSION}" \
  --label "${oci_prefix}.title=Clusterscanner Scanner New Version" \
  --label "${oci_prefix}.description=${descr}" \
  --label "io.sda-se.image.bill-of-materials-hash=${bill_of_materials_hash}" \
  --env 'IMAGE=' \
  --env 'IMAGE_SCAN_POSITIVE_FILTER=^quay.io/sdase/.*:(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' \
  --env 'RESULT_CACHING_HOURS=4' \
  "${ctr}"

buildah commit --quiet "${ctr}" "${IMAGE_NAME}:${VERSION}" && ctr=

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]
then
  mkdir --parent "${build_dir}"
  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${VERSION}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${MAJOR}.${MINOR}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${MAJOR}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  buildah rmi "${IMAGE_NAME}:${VERSION}"
fi

cleanup
