#!/bin/bash

SOURCE_FILE=$1 # md from doc
TARGET=$2 # What to extract Response or Relevance
TARGET_FILE=$3 # Target CSV
TEMP_FILE="/tmp/tmp-file-to-create-markdown"
heading="##"

if [ "${TARGET}" != "Response" ] && [ "${TARGET}" != "Relevance" ]; then
  echo "TARGET not set correctly"
  exit 1
fi

cp "${SOURCE_FILE}" "${TEMP_FILE}"

sed -i.bak "/${heading} ${TARGET}/,\$!d" "${TEMP_FILE}"
sed -i.bak "s/${heading} ${TARGET}/${TARGET}/g" ${TEMP_FILE}
sed -i.bak "/^${heading} [a-zA-Z]/,\$d" ${TEMP_FILE}
sed -i.bak "s/##/#/g" ${TEMP_FILE}
sed -i.bak "s/# //g" ${TEMP_FILE}
sed -i.bak "s/#/\n/g" ${TEMP_FILE}

extract=$(jq -R -s -c '.' ${TEMP_FILE})
echo $(jq --arg extract "${extract}" '.findings[].relevance = ($extract | fromjson)' < "${TARGET_FILE}") > "${TARGET_FILE}"

desc=$(jq '.findings[].description | to_entries | map(.value) | join("\n")' distroless.json)
echo $(jq --arg desc "${desc}" '.findings[].description = ($desc | fromjson)' < distroless.json) > distroless.json
