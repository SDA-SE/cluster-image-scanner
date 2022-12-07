#!/bin/bash
set -xe

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

echo "Building ${IMAGE_NAME}"

oci_prefix="org.opencontainers.image"
descr="ClusterImageScanner Base"

trap cleanup INT EXIT
cleanup() {
  test -n "${ctr}" && buildah rm "${ctr}" || true
}


## skopeo is not available in ubi
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
build_dir="${dir}/build"


skopeo_image="registry.access.redhat.com/ubi8/go-toolset:latest"
ctr_skopeo="$( buildah from --pull --quiet "${skopeo_image}")"
mnt_skopeo="$( buildah mount "${ctr_skopeo}")"

base_image="registry.access.redhat.com/ubi8-init" # minimal doesn't have useradd
ctr_tools="$( buildah from --pull --quiet "${base_image}")"
mnt_tools="$( buildah mount "${ctr_tools}")"

target_image="scratch"
ctr="$( buildah from --pull --quiet "${target_image}")"
mnt="$( buildah mount "${ctr}")"


# Options that are used with every `dnf` command
dnf_opts=(
  #"--disableplugin=*"
  "--installroot=/mnt"
  "--assumeyes"
  "--setopt=install_weak_deps=false"
  "--releasever=8"
  "--setopt=tsflags=nocontexts,nodocs"
  "--quiet"

)

# User management
touch "${mnt}/etc/passwd" "${mnt}/etc/shadow" "${mnt}/etc/group"
useradd --root "${mnt}" --uid 1001 --home-dir /clusterscanner --create-home clusterscanner


buildah run --volume "${mnt}":/mnt "${ctr_tools}" -- /usr/bin/dnf install "${dnf_opts[@]}" bash tar jq grep diffutils findutils coreutils-single util-linux curl openssl bc

buildah run --volume "${mnt}":/mnt "${ctr_tools}" -- /usr/bin/dnf clean "${dnf_opts[@]}" all
rm -rf "${mnt}/var/{cache,log}/*" "${mnt}/tmp/*"

latest_skopeo_tarball=$(curl --silent https://api.github.com/repos/containers/skopeo/releases/latest | jq '.tarball_url' | sed 's/"//g')
buildah run "${ctr_skopeo}" -- curl -s -L "${latest_skopeo_tarball}" -o skopeo.tar
buildah run "${ctr_skopeo}" -- tar xf skopeo.tar
folder=$(buildah run "${ctr_skopeo}" -- ls | grep containers)
buildah run "${ctr_skopeo}" -- make --directory="${folder}" bin/skopeo DISABLE_CGO=1

### skopeo
mkdir -p "${mnt}/etc" "${mnt}/bin" "${mnt}/etc/containers" || true

echo "copying to skopeo"
cp "${mnt_skopeo}/opt/app-root/src/$folder/default-policy.json" "${mnt}/etc/containers/policy.json"
cp "${mnt_skopeo}/opt/app-root/src/$folder/bin/skopeo" "${mnt}/bin/"

# component
mkdir -p "${mnt}/clusterscanner" || true
cp ./*.bash "${mnt}/clusterscanner"

echo "removing ${mnt}/etc/yum.repos.d ${mnt}/etc/yum/repos.d ${mnt}/etc/distro.repos.d"
rm -Rf ${mnt}/etc/yum.repos.d ${mnt}/etc/yum/repos.d ${mnt}/etc/distro.repos.d || true

# Get a bill of materials
bill_of_materials="$(buildah run --volume "${mnt}":/mnt "${ctr_tools}" -- /usr/bin/rpm \
  --query \
  --all \
  --queryformat "%{NAME} %{VERSION} %{RELEASE} %{ARCH}" \
  --dbpath="/mnt/var/lib/rpm" \
  | sort )"
echo "bill_of_materials: ${bill_of_materials}";
# Get bill of materials hash – the content
# of this script is included in hash, too.
bill_of_materials_hash="$( ( cat "${0}";
  echo "${bill_of_materials}"; \
  cat ./*;
  ) | sha256sum | awk '{ print $1 }' )"

buildah config \
  --label "${oci_prefix}.authors=SDA SE Engineers <engineers@sda-se.io>" \
  --label "${oci_prefix}.url=https://quay.io/sdase/cluster-image-scanner-base" \
  --label "${oci_prefix}.source=https://github.com/sdase/cluster-image-scanner-base" \
  --label "${oci_prefix}.revision=$( git rev-parse HEAD )" \
  --label "${oci_prefix}.version=${VERSION}" \
  --label "${oci_prefix}.vendor=SDA SE Open Industry Solutions" \
  --label "${oci_prefix}.title=ClusterImageScanner Base" \
  --label "${oci_prefix}.description=${descr}" \
  --label "io.sda-se.image.bill-of-materials-hash=${bill_of_materials_hash}" \
  --env "IMAGE_TAR_FOLDER_PATH=/clusterscanner/images" \
  --env "IMAGE_TAR_PATH=/clusterscanner/images/image.tar" \
  --env "ARTIFACTS_PATH=/clusterscanner/data" \
  --env "CACHE_TIME_SECONDS=14400" \
  --env "IMAGE_UNPACKED_DIRECTORY=/tmp/image-unpacked" \
  --env "REGISTRY_AUTH_FILE=/run/containers/auth.json" \
  --user clusterscanner \
  --workingdir "/clusterscanner" \
  --entrypoint "/clusterscanner/entrypoint.bash" \
  "${ctr}"

buildah commit --quiet "${ctr}" "${IMAGE_NAME}:${VERSION}" && ctr=

if [ -n "${BUILD_EXPORT_OCI_ARCHIVES}" ]
then
  mkdir -p "${build_dir}"
  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${VERSION}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${MAJOR}.${MINOR}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  image="docker://${REGISTRY}/${ORGANIZATION}/${IMAGE_NAME}:${MAJOR}"
  buildah push --quiet --creds "${REGISTRY_USER}:${REGISTRY_TOKEN}" "${IMAGE_NAME}:${VERSION}" "${image}"

  buildah rmi "${IMAGE_NAME}:${VERSION}"
fi

cleanup
