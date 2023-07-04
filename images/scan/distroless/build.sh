#!/bin/bash
set -e

if [ $# -ne 7 ]; then
  echo "Parameters are not set correctly"
  exit 1
fi

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
descr="Clusterscan Scanner Distroless"

# shellcheck source=env.bash
source env.bash

trap cleanup INT EXIT
cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
}

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
build_dir="${dir}/build"

base_image="quay.io/sdase/cluster-image-scanner-base:2"
ctr="$( buildah from --pull --quiet "${base_image}")"
mnt="$( buildah mount "${ctr}" )"

# shellcheck source=../../base/scan-common.bash
source "${mnt}/clusterscanner/scan-common.bash"

JSONFILE="${mnt}/clusterscanner/distroless.json"

cp module.bash "${mnt}/clusterscanner/"
cp env.bash "${mnt}/clusterscanner/"
cp ../ddTemplate.json "$JSONFILE"

JSON=$(<"$JSONFILE")
JSON=$(add_json_field infoText "$infoText" "$JSON" description) #infoText comes from env.bash
JSON=$(add_json_field title "No distroless used" "$JSON")
JSON=$(add_json_field severity "Medium" "$JSON")

if [ -z "$JSON" ]; then
  echo "failed to prepare JSON template"
  exit 1
else 
  echo "$JSON" > "$JSONFILE"
fi

../parseMarkdownToCreateDefectDojoText.bash ../../../docs/user/scans/distroless.md Relevance "$JSONFILE"
../parseMarkdownToCreateDefectDojoText.bash ../../../docs/user/scans/distroless.md Response "$JSONFILE"

# Get a bill of materials
base_bill_of_materials_hash=$(buildah inspect --type image "${base_image}"  | jq '.OCIv1.config.Labels."io.sda-se.image.bill-of-materials-hash"')
#echo "base_bill_of_materials_hash $base_bill_of_materials_hash"
bill_of_materials_hash="$( ( cat "${0}";
  echo "${base_bill_of_materials_hash}"; \
  cat ./*; \
  ) | sha256sum | awk '{ print $1 }' )"
echo "bill_of_materials: $bill_of_materials_hash";
buildah config \
  --label "${oci_prefix}.url=https://quay.io/sdase/cluster-image-scanner-distroless" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/clusterscanner-distroless" \
  --label "${oci_prefix}.revision=$( git rev-parse HEAD )" \
  --label "${oci_prefix}.version=${VERSION}" \
  --label "${oci_prefix}.title=Clusterscanner Scanner Distroless" \
  --label "${oci_prefix}.description=${descr}" \
  --label "io.sda-se.image.bill-of-materials-hash=${bill_of_materials_hash}" \
  --env 'RESULT_CACHING_HOURS=168' \
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
