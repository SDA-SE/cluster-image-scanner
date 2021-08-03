#!/bin/bash
set -e
# Downloads a container image specified by an image hash
# and stores it as a tarball, including manifest and build
# config files
#
# Skips if there already is a identical config file present

if [ "${IMAGE_TAR_FOLDER_PATH}" == "" ]; then
  echo "IMAGE_TAR_FOLDER_PATH is not set"
  exit 2
fi

mkdir -p "${IMAGE_TAR_FOLDER_PATH}/" || true

_tmp_dir="${IMAGE_TAR_FOLDER_PATH}/tmp"
rm -Rf ${_tmp_dir} || true
mkdir ${_tmp_dir}
_unpack_dir=$(mktemp -d --tmpdir=${_tmp_dir})
_config_dir=$(mktemp -d --tmpdir=${_tmp_dir})

echo "Directory /run/containers"
ls -lah /run/containers
sha256sum /run/containers/auth.json

echo "Checking for existing config manifest of ${IMAGE_BY_HASH}"
# catch tagged images (which can happen if we don't know the image hash to pull by). When we have a tagged image, the image is assumed to be mutable - therefore the config.json of the image is checked, to make sure they are identical before skipping the pull process.
skopeo inspect --config "docker://${IMAGE_BY_HASH}" | jq -cMS 'def recursively(f): . as $in | if type == "object" then reduce keys_unsorted[] as $key ( {}; . + { ($key):  ($in[$key] | recursively(f)) } ) elif type == "array" then map( recursively(f) ) | f else . end; . | recursively(sort)' > "${_config_dir}/config.json"

[[ -f "${IMAGE_TAR_FOLDER_PATH}/config.json" ]] && diff -qs "${_config_dir}/config.json" "${IMAGE_TAR_FOLDER_PATH}/config.json" && echo "Already got image with identical config manifest, skipping" && exit 0

echo "Downloading image ${IMAGE_BY_HASH}"

skopeo copy "docker://${IMAGE_BY_HASH}" "dir:${_tmp_dir}"

for l in $(jq ".layers | .[].digest" "${_tmp_dir}/manifest.json" | tr -d \" | sed -e "s/^sha256://g"); do
    echo "Extracting blob ${l}"
    tar --exclude "/dev/" --no-acls --no-selinux --no-xattrs --no-overwrite-dir --owner=clusterscan --group=clusterscan -mxzf "${_tmp_dir}/${l}" -C "${_unpack_dir}" || true # TODO scan somehow dev
    find "${_unpack_dir}" -type d -exec chmod 755 {} +
    find "${_unpack_dir}" -type f -exec chmod 644 {} +
done

cd "${_unpack_dir}"

echo "Packing image to ${IMAGE_TAR_FOLDER_PATH}"
tar -cf "${IMAGE_TAR_PATH}" ./* || exit 1

echo "Copying manifest and config file"
cp "${_tmp_dir}/manifest.json" "${IMAGE_TAR_FOLDER_PATH}/manifest.json"
cp "${_config_dir}/config.json" "${IMAGE_TAR_FOLDER_PATH}/config.json"

echo "Cleaning up"
rm -rf "${_tmp_dir}"
