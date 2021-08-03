#!/bin/bash
set -e
shopt -s globstar nullglob

if [ "${RESULT_PATH}" == "" ]; then
  RESULT_PATH=/clusterscanner/data
fi

for file in "${RESULT_PATH}"/**/*.json; do
  echo "found file ${file}"
  item=$(cat "${file}")
  image=$(echo "${item}" | jq -r '.image'| tr -cd '[:alnum:]./@:_-')
  team=$(echo "${item}" | jq -r '.team'| tr -cd '[:alnum:]._-')
  namespace=$(echo "${item}" | jq -r '.namespace'| tr -cd '[:alnum:]._-')
  environment=$(echo "${item}" | jq -r '.environment'| tr -cd '[:alnum:]._-')
  slack=$(echo "${item}" | jq -r '.slack')
  appName=$(echo "${item}" | jq -r '.appname'| tr -cd '[:alnum:]._-')
  email=$(echo "${item}" | jq -r '.email')
  if [ "${ENFORCE_SLACK_CHANNEL}" != "" ]; then
    slack="${ENFORCE_SLACK_CHANNEL}"
  fi
  echo "Inspecting team ${team} for image ${image}"
  echo "item: ${item}" | jq -rcM '.uploadResults[] | @base64'
  for result in $(echo "${item}" | jq -rcM '.uploadResults[] | @base64'); do
    #for result2 in $(echo "${result}" | base64 -d | jq -rcM '.[] | @base64'); do
      notifications=$(echo "${result}" | base64 -d | jq 'select(.finding == true)')
      echo "notifications: ${notifications}"
      while IFS= read -r notification; do
        echo "in notification for ${image}"

        ddLinkTest=$(echo "${notification}" | jq -r ".ddLink")
        message=$(echo "${notification}" | jq -r ".infoText" | sed 's#{##g' | sed 's#}##g')   #| tr -cd '[:alnum:]._ \n:@*+()[]-') # at least { } needs to be removed for the slack cli
        errorText=$(echo "${notification}" | jq -r ".errorText" | tr -cd '[:alnum:]._ \n:@*+()[]-' || true)
        status=$(echo "${notification}" | jq -r ".status" | tr -cd '[:alnum:]._ -')
        ddLinkScheme=$(echo "${ddLinkTest}" | tr '/' ' ' | awk '{print $1}')
        ddLinkDomain=$(echo "${ddLinkTest}" | tr '/' ' ' | awk '{print $2}')
        ddLinkBase="${ddLinkScheme}//${ddLinkDomain}"
        for findingBase in $(echo "${notification}" | jq -rcM '.findings[] | @base64'); do
          finding=$(echo "${findingBase}" | base64 -d)
          findingId=$(echo "${finding}" | jq -r '.id' | tr -cd '[:alnum:]._ -')
          if [ "${findingId}" != "null" ] && [ "${findingId}" != "" ]; then
            ddLink="${ddLinkBase}/finding/${findingId}"
          else
            ddLink="${ddLinkTest}"
          fi
          title=$(echo "${finding}" | jq -r '.title' | cut -c1-20 | sed 's#{##g'| sed 's#}##g') #| tr -cd '[:alnum:]._ <>-')
          title="${title} in ${image}"
          description=$(echo "${finding}" | jq -r '.description' | sed 's#{##g'| sed 's#}##g')
          message="${message}\n${description}\nScan Job Status: ${status}"
          if [ "${errorText}" != "null" ] && [ "${errorText}" != "[]" ] && [ "${errorText}" != "" ]; then
            message="${message}\nError: ${errorText}"
          fi
          output=$(./inform.bash "${image}" "${appName}" "${team}" "${namespace}" "${environment}" "${ddLink}" "${slack}" "${email}" "${title}" "${message}" || true)
          echo "${output}"
          if [ "$(echo "${output}" | grep -c '"ok": false')" -gt 0 ]; then
            echo "error in slack"
            exit 1;
          fi
          if [ "$(echo "${output}" | grep -c ratelimited)" -gt 0 ]; then
            sleep 120 # wait for rate limit
            ./inform.bash "${image}" "${appName}" "${team}" "${namespace}" "${environment}" "${ddLink}" "${slack}" "${email}" "${title}" "${message}"
          fi
          sleep 1 # reduce risk of rate limit
        done
      #done <<< "$(echo "${notifications}")"
    done
  done
done
