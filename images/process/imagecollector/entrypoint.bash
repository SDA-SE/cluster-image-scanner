#!/bin/bash
set -e

export HOME=/home/code
id || true

cd $HOME
source pods.bash
source git.bash
IMAGE_FILENAME_JSON=/tmp/cluster-scan/output.json

echo "gitAuth1"
gitAuth # test that it works

echo "getPods"
if [ "${CLUSTER_NAME}" != "" ]; then
  ENVIRONMENT_NAME="${CLUSTER_NAME}"
fi
getPods "${IMAGE_FILENAME_JSON}" "${ENVIRONMENT_NAME}"

echo "gitAuth2"
gitAuth
echo "gitFetch"
gitFetch
cp -a /tmp/cluster-scan/* /tmp/clusterscanner-remote

cd /tmp/clusterscanner-remote
git add "output.json" || true
git commit -m "update file" "output.json" || true

if [ "${IS_FETCH_DESCRIPTION}" == "true" ]; then
  git add description/ || true
  git commit -m "update file" description/ || true
fi

TZ="Europe/Berlin" date > lastScan
git add lastScan || true

echo "Old json is not to be used anymore" # TODO: Remove
git rm imagesAndCluster.json || true

git commit -m "update lastscan" lastScan  || true
git push -f origin master || true


