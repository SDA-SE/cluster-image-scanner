#!/bin/bash

set -ex
# checks if an image a new images exists

source ./scan-common.bash

JSONFILE="${ARTIFACTS_PATH}/new-version.json"

scan_result_pre

function testNewImageAndReport {
  imageToTest=$1


  imageExists=true
  skopeo inspect "docker://${imageToTest}" > /dev/null || imageExists=false
  if [ ${imageExists} == false ]; then return ; fi

  infoText="Image has a new tag, at least ${imageToTest}"
  JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": true, \"infoText\": \"${infoText}\", \"newVersion\": \"${imageToTest}\"}")

  #cp /clusterscanner/new-version.json "${ARTIFACTS_PATH}/new-version.json"
  JSON=$(<"${JSONFILE}")
  JSON=$(add_json_field infoText "$infoText" "$JSON" description)
  JSON=$(add_json_field title "Image Has a New Version" "$JSON")
  JSON=$(add_json_field severity "low" "$JSON")
  #JSON=$(jq \
  #  --arg infoText "${infoText}" \
  #  --arg title "Image Has a New Version" \
  #  --arg severity "low" \
  #'.findings[].description.infoText = $infoText | .findings[].title = $title | .findings[].severity = $severity' \
  #"${ARTIFACTS_PATH}/new-version.json")
  if [ -z "$JSON" ]; then
    echo "JSON generation with base data failed"
    exit 1
  else 
    cat "$JSON" > "$JSONFILE"
  fi

  scan_result_post
  exit 0
}

if ! [[ ${IMAGE} =~ ${IMAGE_SCAN_POSITIVE_FILTER} ]]; then
  echo "Image ${IMAGE} is not whitelisted via '${IMAGE_SCAN_POSITIVE_FILTER}', no scan"
  exit 0
fi

if [[ "${IMAGE}" =~ "@sha256" ]]; then
  echo "Image ${IMAGE} is an image with a hash, no scan"
  exit 0
fi



# Is image tag (simple) semantic (normally, - would be allowed)
imageTag=$(echo "${IMAGE}" |  sed 's#.*/.*:##')
echo "Analysing IMAGE: ${IMAGE} with tag ${imageTag}"
if ! [[ "${imageTag}" =~ ^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "${IMAGE} has tag ${imageTag} which is not (simple) semantic, stopping test (exit code 0)"
  exit 0
fi
echo "Image Tag: ${imageTag}"
MAJOR=$(echo "${imageTag}" | tr  '.' "\n" | sed -n 1p)
MINOR=$(echo "${imageTag}" | tr  '.' "\n" | sed -n 2p)
PATCH=$(echo "${imageTag}" | tr  '.' "\n" | sed -n 3p)
IMAGE_WITHOUT_TAG=$(echo "${IMAGE}" | sed 's#:.*##')
echo "IMAGE_WITHOUT_TAG: ${IMAGE_WITHOUT_TAG}"

(( patchPlusOne = PATCH + 1 ))
testNewImageAndReport "${IMAGE_WITHOUT_TAG}:${MAJOR}.${MINOR}.${patchPlusOne}"

(( minorPlusOne = MINOR + 1 ))
testNewImageAndReport "${IMAGE_WITHOUT_TAG}:${MAJOR}.${minorPlusOne}.0"
if [[ "${MAJOR}" =~ ^v ]]; then
  let majorPlusOne=$(echo ${MAJOR} | sed 's#v##g')+1
  majorPlusOne="v${majorPlusOne}"
else let majorPlusOne=${MAJOR}+1
fi


testNewImageAndReport "${IMAGE_WITHOUT_TAG}:${majorPlusOne}.0.0"

echo "No new version available"
JSON_RESULT=$(echo "${JSON_RESULT}" | jq -Sc ". += {\"status\": \"completed\", \"finding\": false}")

scan_result_post

echo "result file:"
cat "$JSONFILE"

exit  0

