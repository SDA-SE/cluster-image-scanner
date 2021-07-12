#!/bin/bash
set -e

cd /home/code

export HOME=/home/code

source pods.bash
source git.bash
IMAGE_FILENAME_JSON=/tmp/cluster-scan/output.json
DESCRIPTION_JSON_FILE=/tmp/cluster-scan/description/service-description.json
mkdir -p /tmp/cluster-scan/description/ || true

echo "gitAuth"
gitAuth
echo "gitFetch"
gitFetch

echo "getPods"
if [ "${CLUSTER_NAME}" != "" ]; then
  ENVIRONMENT_NAME="${CLUSTER_NAME}"
fi
getPods "${IMAGE_FILENAME_JSON}" "${ENVIRONMENT_NAME}" "${DESCRIPTION_JSON_FILE}"


cd /tmp/cluster-scan
git add "${IMAGE_FILENAME_JSON}" || true
git commit -m "update file" "${IMAGE_FILENAME_JSON}" || true

if [ "${IS_FETCH_DESCRIPTION}" == "true" ]; then
  git add ${DESCRIPTION_JSON_FILE}
  git commit -m "update file" "${DESCRIPTION_JSON_FILE}" || true
fi

TZ="Europe/Berlin" date > lastScan
git add lastScan || true

#echo "Old csv is not to be used anymore" TODO
#git rm imagesAndCluster.csv || true

git commit -m "update lastscan" lastScan  || true

git push -f origin master || true
