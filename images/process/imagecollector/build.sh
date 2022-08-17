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

MAJOR=$(echo "${VERSION}" | tr '.' "\n" | sed -n 1p)
MINOR=$(echo "${VERSION}" | tr '.' "\n" | sed -n 2p)

trap cleanup INT EXIT

cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
}

base_image="registry.access.redhat.com/ubi8/ubi-init" # minimal doesn't have useradd
ctr_tools="$(buildah from --pull --quiet ${base_image})"

tools_image="quay.io/sdase/cluster-image-scanner-base:2"
tools_ctr="$(buildah from --pull --quiet ${tools_image})"
tools_mnt="$(buildah mount "${tools_ctr}")"

target_image="scratch"
ctr="$(buildah from --pull --quiet ${target_image})"
mnt="$(buildah mount "${ctr}")"

# Options that are used with every `dnf` command
dnf_opts=(
  "--installroot=/mnt"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=8"
  "--setopt=tsflags=nocontexts,nodocs"
  "--quiet"
)

buildah run --volume "${mnt}:/mnt" "${ctr_tools}" -- /usr/bin/dnf install "${dnf_opts[@]}" curl git openssl openssh
buildah run --volume "${mnt}:/mnt" "${ctr_tools}" -- /usr/bin/dnf clean "${dnf_opts[@]}" all
rm -rf "${mnt}"/var/{cache,log}/* "${mnt}"/tmp/*

mkdir -p "${mnt}/home/code" || true
rsync -a bin/jq "${mnt}/usr/local/bin/jq"
rsync -a ${tools_mnt}/usr/bin/find ${mnt}/usr/bin/find
rsync -a bin/kubectl "${mnt}/usr/local/bin/kubectl"
rsync -a entrypoint.bash "${mnt}/home/code/entrypoint.bash"
rsync -a pods.bash "${mnt}/home/code/pods.bash"
#rsync -a build.sh "${mnt}/home/code/build.sh" # for sha1
rsync -a .gitconfig "${mnt}/home/code/.gitconfig"
rsync -a config "${mnt}/home/code/"
rsync -a "${tools_mnt}/clusterscanner/git.bash" "${mnt}/home/code/"
rsync -a "${tools_mnt}/clusterscanner/auth.bash" "${mnt}/home/code/"

# git looks up for a user
openShiftGroupId=0
echo "nonroot:x:1001:${openShiftGroupId}:nonroot:/home/code:/sbin/nologin" >> "${mnt}/etc/passwd"
echo "nobody:x:1001:" >>"${mnt}/etc/group"
echo "openshift:x:5555:" >>"${mnt}/etc/group"
chgrp "${openShiftGroupId}" "${mnt}/etc/passwd" # openShift 3.X specifc, https://docs.openshift.com/container-platform/3.3/creating_images/guidelines.html
chmod g=u "${mnt}/etc/passwd"
chmod o=u "${mnt}/etc/passwd"

# the ssh folder must be owned by the user, therefore, the folder can not be created in advance
chmod 777 "${mnt}/home/code/"
chown -R "1001:${openShiftGroupId}" "${mnt}/home/code/"

chmod 555 "${mnt}/etc/hosts"

# Get a bill of materials, TODO: use find to create bom
bill_of_materials="$(buildah run --volume "${mnt}:/mnt" "${ctr_tools}" -- /usr/bin/rpm \
  --query \
  --all \
  --queryformat "%{NAME} %{VERSION} %{RELEASE} %{ARCH}" \
  --dbpath="/mnt/var/lib/rpm" |
  sort)"
echo "bill_of_materials: ${bill_of_materials}"
bill_of_materials_hash="$( (
  cat "${0}"
  echo "${bill_of_materials}"
  cat ./*
) | sha256sum | awk '{ print $1 }')"

oci_prefix="org.opencontainers.image"
buildah config \
  --env GITHUB_APP_ID="SET-ME" \
  --env GITHUB_REPOSITORY="SET-ME" \
  --env GIT_SSH_REPOSITORY_HOST="SET-ME" \
  --env GIT_REPOSITORY_PATH="SET-ME" \
  --env CLUSTER_NAME="DEPRECATED" \
  --env ENVIRONMENT_NAME="SET_ME" \
  --env CONTACT_ANNOTATION_PREFIX="contact.sdase.org" \
  --env SKIP_ANNOTATION="clusterscanner.sdase.org/skip" \
  --env TEAM_ANNOTATION="contact.sdase.org/team" \
  --env DEFAULT_TEAM_NAME="nobody" \
  --env DEFAULT_SLACK_POSTFIX="-security" \
  --env SCM_URL_ANNOTATION="scm.sdase.org/source_url" \
  --env SCM_BRANCH_ANNOTATION="scm.sdase.org/source_branch" \
  --env SCM_RELEASE_ANNOTATION="scm.sdase.org/release" \
  --env CONTACT_DEFAULT_EMAIL="" \
  --env APP_NAME_LABEL="app.kubernetes.io/name" \
  --env APP_VERSION_LABEL="app.kubernetes.io/version" \
  --env DEFAULT_SKIP="false" \
  --env IMAGE_SKIP_POSITIVE_LIST="" \
  --env IMAGE_SKIP_NEGATIVE_LIST="" \
  --env NAMESPACE_SKIP_REGEX="" \
  --env DEFAULT_SCAN_LIFETIME="true" \
  --env DEFAULT_SCAN_DISTROLESS="true" \
  --env DEFAULT_SCAN_MALWARE="true" \
  --env DEFAULT_SCAN_DEPENDENCY_CHECK="true" \
  --env DEFAULT_SCAN_DEPENDENCY_TRACK="false" \
  --env DEFAULT_SCAN_RUNASROOT="true" \
  --env DEFAULT_SCAN_LIFETIME_MAX_DAYS="14" \
  --env DEFAULT_SCAN_BASEIMAGE_LIFETIME="true" \
  --env DEFAULT_SCAN_NEW_VERSION="true" \
  --env SCAN_LIFETIME_MAX_DAYS_ANNOTATION="clusterscanner.sdase.org/max-lifetime" \
  --env SCAN_LIFETIME_ANNOTATION="clusterscanner.sdase.org/is-scan-lifetime" \
  --env SCAN_DISTROLESS_ANNOTATION="clusterscanner.sdase.org/is-scan-distroless" \
  --env SCAN_MALWARE_ANNOTATION="clusterscanner.sdase.org/is-scan-malware" \
  --env SCAN_DEPENDENCY_CHECK_ANNOTATION="clusterscanner.sdase.org/is-scan-dependency-check" \
  --env SCAN_DEPENDENCY_CHECK_ANNOTATION="clusterscanner.sdase.org/is-scan-dependency-track" \
  --env SCAN_RUNASROOT_ANNOTATION="clusterscanner.sdase.org/is-scan-runasroot" \
  --env SCAN_BASEIMAGE_LIFETIME_ANNOTATION="clusterscanner.sdase.org/is-scan-baseimage-lifetime" \
  --env NAMESPACE_SKIP_IMAGE_REGEX_ANNOTATION="clusterscanner.sdase.org/skip_regex" \
  --env SCAN_NEW_VERSION_ANNOTATION="clusterscanner.sdase.org/is-scan-new-version" \
  --env DESCRIPTION_ANNOTATION="sdase.org/description" \
  --env NAMESPACE_TO_SCAN_ANNOTATION="clusterscanner.sdase.org/namespace_filter" \
  --env DEPENDENCY_TRACK_NOTIFICATION_THRESHOLDS_ANNOTATION="clusterscanner.sdase.org/dependency-track-notification-thresholds" \
  --env DEPENDENCY_TRACK_NOTIFICATION_THRESHOLDS_DEFAULT='[
                                                                {"maven": {"critical": 1, "high": 1, "medium": 100}},
                                                                {"npm": {"critical": 1, "high": 1, "medium": 100}},
                                                                {"deb": {"critical": 1, "high": 10, "medium": 100}},
                                                                {"rpm": {"critical": 1, "high": 10, "medium": 100}},
                                                                {"alpine": {"critical": 1, "high": 10, "medium": 100}} ]' \
  --env IS_FETCH_DESCRIPTION="true" \
  --env NAMESPACE_MAPPINGS="" \
  --env HOME="/home/code" \
  --cmd "/home/code/entrypoint.bash" \
  --user 1001 \
  --label "${oci_prefix}.authors=SDA SE Engineers <engineers@sda-se.io>" \
  --label "${oci_prefix}.url=https://quay.io/sdase/cluster-image-scanner" \
  --label "${oci_prefix}.source=https://github.com/SDA-SE/cluster-image-scanner/images/proces/imagecollector" \
  --label "${oci_prefix}.version=${VERSION}" \
  --label "${oci_prefix}.revision=$(git rev-parse HEAD)" \
  --label "${oci_prefix}.vendor=SDA SE Open Industry Solutions" \
  --label "${oci_prefix}.title=ClusterImageScanner Collector" \
  --label "${oci_prefix}.description=Collect images from cluster with kubectl" \
  --label "io.sda-se.image.bill-of-materials-hash=$(
    echo "${bill_of_materials_hash}"
  )" \
  "${ctr}"

buildah commit --quiet "${ctr}" "${IMAGE_NAME}:${VERSION}" && ctr=

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]; then
  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${VERSION}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${MAJOR}.${MINOR}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${MAJOR}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  buildah rmi "${IMAGE_NAME}:${VERSION}"
fi

cleanup
