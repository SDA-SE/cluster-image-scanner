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

#| sed "s|${heading}.*||g"
#extract=$(cat $SOURCE_FILE | sed -e "s|^.*\(${heading} ${TARGET}\)|\1|g" )
cp ${SOURCE_FILE} ${TEMP_FILE}

sed -i "/${heading} ${TARGET}/,\$!d" ${TEMP_FILE}
sed -i "s/${heading} ${TARGET}/${TARGET}/g" ${TEMP_FILE}
sed -i "/^${heading} [a-Z]/,\$d" ${TEMP_FILE}
sed -i "s/##/#/g" ${TEMP_FILE}
sed -i "s/# //g" ${TEMP_FILE}
sed -i "s/#/\n/g" ${TEMP_FILE}
extract=$(cat ${TEMP_FILE} | sed 's#|#_#g' | tr '\n' "|")
#sed -e "s|###${TARGET}###|${extract}|" ${TARGET_FILE}

sed -i -e "s/###${TARGET}###/${extract}/g"  ${TARGET_FILE}
sed -i -e "s/|/\n/g"  ${TARGET_FILE}
echo "####################"
#cat ${TARGET_FILE}

#awk "/###${TARGET}###/{system(\"cat ${TEMP_FILE}\")}1" ${TARGET_FILE} > ${TEMP_FILE}2
#mv ${TEMP_FILE}2 ${TARGET_FILE}



