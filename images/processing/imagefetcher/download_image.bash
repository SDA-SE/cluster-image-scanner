#!/bin/bash
# Downloads a container image specified by an image hash
# and stores it as a tarball, including manifest and build
# config files
#
# Skips if there already is a identical config file present
#
# Usage examples:
# ./download_image.bash nginx@sha256:4cf620a5c81390ee209398ecc18e5fb9dd0f5155cd82adcbae532fec94006fb9 /path/to/destination/folder
IMAGE_BY_HASH=${1}
shift
DEST_DIR=${1}

_tmp_dir=$(mktemp -d)
_unpack_dir=$(mktemp -d)
_config_dir=$(mktemp -d)

echo "Checking for existing config manifest"

skopeo inspect --config docker://${IMAGE_BY_HASH} | jq -cMS 'def recursively(f): . as $in | if type == "object" then reduce keys_unsorted[] as $key ( {}; . + { ($key):  ($in[$key] | recursively(f)) } ) elif type == "array" then map( recursively(f) ) | f else . end; . | recursively(sort)' > "${_config_dir}/config.json"

[[ -f "${DEST_DIR}/config.json" ]] && diff -qs "${_config_dir}/config.json" "${DEST_DIR}/config.json" && echo "Already got image with identical config manifest, skipping" && exit 0

echo "Downloading image ${IMAGE_BY_HASH}"

skopeo copy docker://${IMAGE_BY_HASH} dir:${_tmp_dir}

for l in $(cat "${_tmp_dir}/manifest.json" | jq ".layers | .[].digest" | tr -d \" | sed -e "s/^sha256://g"); do
    echo "Extracting blob ${l}"
    tar --no-acls --no-selinux --no-xattrs --no-overwrite-dir --owner=clusterscan --group=clusterscan -mxzf "${_tmp_dir}/${l}" -C "${_unpack_dir}" || exit 1
    find "${_unpack_dir}" -type d -exec chmod 755 {} +
    find "${_unpack_dir}" -type f -exec chmod 644 {} +
done

cd "${_unpack_dir}"

echo "Packing image"
tar -cf "${DEST_DIR}/image.tar" * || exit 1

echo "Copying manifest and config file"
cp "${_tmp_dir}/manifest.json" "${DEST_DIR}/manifest.json"
cp "${_config_dir}/config.json" "${DEST_DIR}/config.json"

echo "Cleaning up"
rm -rf ${_tmp_dir} ${_unpack_dir}
