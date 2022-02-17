#!/bin/bash
set -e
source ./env.bash
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

trap cleanup INT EXIT
cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
}

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
build_dir="${dir}/build"


base_image="registry.access.redhat.com/ubi8/ubi-init" # minimal doesn't have useradd
ctr_tools="$(buildah from --pull --quiet ${base_image})"

base_image="quay.io/sdase/cluster-image-scanner-base:2"
ctr="$( buildah from --pull --quiet "${base_image}")"
mnt="$( buildah mount "${ctr}" )"

cp -a *.bash "${mnt}/clusterscanner/"

buildah run --volume "${mnt}:/mnt" "${ctr_tools}" -- /usr/bin/dnf install -y "${dnf_opts[@]}" curl git openssl openssh
buildah run --volume "${mnt}:/mnt" "${ctr_tools}" -- /usr/bin/dnf clean "${dnf_opts[@]}" all
rm -rf "${mnt}"/var/{cache,log}/* "${mnt}"/tmp/*

# Get a bill of materials
base_bill_of_materials_hash=$(buildah inspect --type image "${base_image}"  | jq '.OCIv1.config.Labels."io.sda-se.image.bill-of-materials-hash"')
#echo "base_bill_of_materials_hash $base_bill_of_materials_hash"
bill_of_materials_hash="$( ( cat "${0}";
  echo "${base_bill_of_materials_hash}"; \
  cat ./*; \
  ) | sha256sum | awk '{ print $1 }' )"
echo "bill_of_materials: $bill_of_materials_hash";
buildah config \
  --label "${oci_prefix}.url=https://quay.io/sdase/cluster-image-scanner-${MODULE_NAME}" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/clusterscanner-${MODULE_NAME}" \
  --label "${oci_prefix}.revision=$( git rev-parse HEAD )" \
  --label "${oci_prefix}.version=${VERSION}" \
  --label "${oci_prefix}.title=${TITLE}" \
  --label "${oci_prefix}.description=${DESCRIPTION}" \
  --label "io.sda-se.image.bill-of-materials-hash=${bill_of_materials_hash}" \
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
