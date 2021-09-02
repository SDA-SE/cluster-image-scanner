#!/bin/bash

SOURCE_FILE=$1
TARGET=$2
TARGET_FILE=$3
TEMP_FILE="/tmp/tmp-file-to-craete-markdown"
heading="##"

if [ "${TARGET}" != "Response" ] && [ "${TARGET}" != "Relevance" ]; then
  echo "TARGET not set correctly"
  exit 1
fi

#| sed "s|${heading}.*||g"
#extract=$(cat $SOURCE_FILE | sed -e "s|^.*\(${heading} ${TARGET}\)|\1|g" )
cp $SOURCE_FILE ${TEMP_FILE}

sed -i "/${heading} ${TARGET}/,\$!d" ${TEMP_FILE}
sed -i "s/${heading} ${TARGET}/${TARGET}/g" ${TEMP_FILE}
sed -i "/^${heading} [a-Z]/,\$d" ${TEMP_FILE}
sed -i "s/##/#/g" ${TEMP_FILE}
sed -i "s/# //g" ${TEMP_FILE}
sed -i "s/#/\n/g" ${TEMP_FILE}
extract=$(cat ${TEMP_FILE})

sed -i "s|###${TARG}||g" ${TARGET_FILE}
rm tmp/x
