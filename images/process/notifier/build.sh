#!/bin/bash
set -e

if [ $# -ne 7 ]; then
  echo "Warn: Parameters are not set correctly"
  exit 1
fi

REGISTRY=$1
ORGANIZATION=$2
IMAGE_NAME=$3
VERSION=$4
REGISTRY_USER=$5
REGISTRY_TOKEN=$6
BUILD_EXPORT_OCI_ARCHIVES=$7

MAJOR=$(echo "${VERSION}" | tr '.' "\n" | sed -n 1p)
MINOR=$(echo "${VERSION}" | tr '.' "\n" | sed -n 2p)

oci_prefix="org.opencontainers.image"
descr="ClusterImageScanner Notifier"

trap cleanup INT EXIT
cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
}

## skopeo is not available in ubi
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
build_dir="${dir}/build"

base_image="registry.access.redhat.com/ubi9/ubi" # minimal doesn't have useradd
ctr_tools="$(buildah from --pull --quiet ${base_image})"

base_image="quay.io/sdase/cluster-image-scanner-base:3"
ctr="$(buildah from --pull --quiet $base_image)"
mnt="$(buildah mount "${ctr}")"

dnf_opts=(
  #"--disableplugin=*"
  "--installroot=/mnt"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=9"
  "--setopt=tsflags=nocontexts,nodocs"
  "--quiet"
)
#rm -Rf "${mnt}/etc/yum.repos.d" || true
curl -o "${mnt}/epel.rpm" -s -L https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
buildah run --volume "${mnt}":/mnt "${ctr_tools}" -- cp -a /etc/yum.repos.d/ /mnt/etc/
buildah run --volume "${mnt}":/mnt "${ctr_tools}" -- /usr/bin/dnf "${dnf_opts[@]}" install /mnt/epel.rpm
buildah run --volume "${mnt}":/mnt "${ctr_tools}" -- /usr/bin/dnf "${dnf_opts[@]}" update
buildah run --volume "${mnt}":/mnt "${ctr_tools}" -- /usr/bin/dnf install "${dnf_opts[@]}" sendmail s-nail dos2unix # s-nail enhances mailx
rm -rf "${mnt}/var/{cache,log}/*" "${mnt}/tmp/*"

curl https://raw.githubusercontent.com/rockymadden/slack-cli/master/src/slack --output "${mnt}/bin/slack"
chmod +x "${mnt}/bin/slack"

cp slack-template.json "${mnt}/clusterscanner/slack-template.json"
cp slack-template-one-block.json "${mnt}/clusterscanner/slack-template-one-block.json"

echo "" >"${mnt}/clusterscanner/cache.bash" # "check for existing in module.bash

# Get a bill of materials
base_bill_of_materials_hash=$(buildah inspect --type image $base_image | jq '.OCIv1.config.Labels."io.sda-se.image.bill-of-materials-hash"')
#echo "base_bill_of_materials_hash $base_bill_of_materials_hash"
bill_of_materials_hash="$( (
  cat "${0}"
  echo "${base_bill_of_materials_hash}"
  cat ./*
) | sha256sum | awk '{ print $1 }')"
echo "bill_of_materials: $bill_of_materials_hash"
buildah config \
  --label "${oci_prefix}.url=https://quay.io/sdase/cluster-image-scanner-notifier" \
  --label "${oci_prefix}.source=https://github.com/sdase/clusterscanner-notifier" \
  --label "${oci_prefix}.revision=$(git rev-parse HEAD)" \
  --label "${oci_prefix}.version=${VERSION}" \
  --label "${oci_prefix}.title=ClusterScanner Notifier" \
  --label "${oci_prefix}.description=${descr}" \
  --label "io.sda-se.image.bill-of-materials-hash=${bill_of_materials_hash}" \
  --env "SLACK_BIN=/bin/slack" \
  --env "SLACK_CLI_TOKEN=TODO" \
  --env "RESULT_PATH=/clusterscanner/data" \
  --env "ENFORCE_SLACK_CHANNEL=" \
  --env "smtp=smtps://smtp.gmail.com:465" \
  --env "smtp-auth=login" \
  --env "smtp-auth-user=USERNAME@YOURDOMAIN.COM" \
  --env "smtp-auth-password=YOURPASSWORD" \
  --env "ssl-verify=strict" \
  --env "SLACK_MESSAGE_ENDPOINT=https://slack.com/api/chat.postMessage" \
  --env "SLACK_TEMPLATE_ONE_BLOCK=/clusterscanner/slack-template-one-block.json" \
  --env "SLACK_TEMPLATE=/clusterscanner/slack-template.json" \
  "${ctr}"
#  --env "set nss-config-dir=/etc/pki/nssdb/" \ # might be needed later?
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
