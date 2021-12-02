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

base_image="quay.io/sdase/cluster-image-scanner-base:2"
ctr="$( buildah from --pull --quiet ${base_image} )"
mnt="$( buildah mount "${ctr}" )"

cp module.bash "${mnt}/clusterscanner/"
cp env.bash "${mnt}/clusterscanner/"
cp workflow.template.yml "${mnt}/clusterscanner/"
touch "${mnt}/clusterscanner/template.yml"
chmod 777 "${mnt}/clusterscanner/template.yml"

# set argo version
export ARGO_VERSION=$(curl --silent https://api.github.com/repos/argoproj/argo-workflows/releases/latest | jq '.tag_name' | sed 's/"//g')
# Download archive
echo "Will download from https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-linux-amd64.gz"
curl -sLO "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-linux-amd64.gz"
# Unzip
gunzip argo-linux-amd64.gz
# Make binary executable
chmod +x argo-linux-amd64
# Move binary to path
mv ./argo-linux-amd64 "${mnt}/usr/local/bin/argo"
# Test installation not working, as kubectl context is not given
# ${mnt}/usr/local/bin/argo version

curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl "${mnt}/usr/local/bin"


# Get a bill of materials
base_bill_of_materials_hash=$(buildah inspect --type image ${base_image}  | jq '.OCIv1.config.Labels."io.sda-se.image.bill-of-materials-hash"')
#echo "base_bill_of_materials_hash $base_bill_of_materials_hash"
bill_of_materials_hash="$( ( cat "${0}";
  echo "${base_bill_of_materials_hash}"; \
  cat ./*; \
  ) | sha256sum | awk '{ print $1 }' )"
echo "bill_of_materials: ${bill_of_materials_hash}";
buildah config \
  --label "${oci_prefix}.url=https://quay.io/sdase/cluster-image-scanner-${MODULE_NAME}" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/clusterscanner-${MODULE_NAME}" \
  --label "${oci_prefix}.revision=$( git rev-parse HEAD )" \
  --label "${oci_prefix}.version=${VERSION}" \
  --label "${oci_prefix}.title=${TITLE}" \
  --label "${oci_prefix}.description=${DESCRIPTION}" \
  --label "io.sda-se.image.bill-of-materials-hash=${bill_of_materials_hash}" \
  --env "GITHUB_KEY_FILE_PATH=/clusterscanner/github/github_private_key.pem" \
  --env "MAX_RUNNING_JOBS_IN_QUEUE=5" \
  --env "JOB_EXECUTION_NAMESPACE=clusterscanner" \
  "${ctr}"

buildah commit --quiet "${ctr}" "${IMAGE_NAME}:${VERSION}" && ctr=

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]; then
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
