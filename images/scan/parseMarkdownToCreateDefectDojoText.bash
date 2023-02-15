#!/bin/bash

SOURCE_FILE=$1 # md from doc
TARGET=$2 # What to extract Response or Relevance
TARGET_FILE=$3 # Target json
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
$(jq --arg extract "${extract}" '.findings[].relevance = ($extract | fromjson)' < "${TARGET_FILE}") > "${TARGET_FILE}"
