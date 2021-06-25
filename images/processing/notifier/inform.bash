#!/bin/bash
set -e

image="${1}"
appName="${2}"
team="${3}"
namespace="${4}"
environment="${5}"
ddLink="${6}"
slackChannel="${7}"
email="${8}"
scanType="${9}"
title="${10}"
message="${11}"

echo "image: ${image}, appName ${appName}, team: ${team}, namespace: ${namespace}, environment: ${environment}, ddLink: ${ddLink}, slackChannel: ${slackChannel}, email: ${email}, scanType: ${scanType}, title: ${title}"

#slackChannel="#nobody-security" # for testing
if [ "${slackChannel}" != "" ]; then
  if [ "${SLACK_CLI_TOKEN}" == "" ]; then
    echo "SLACK_CLI_TOKEN not set, exit"
    exit 1
  fi
  echo "Sending to slack ${slackChannel}"
  message=$(echo "${message}" | sed 's#"##g')

  ${SLACK_BIN} chat send --actions '{"type": "button", "style": "primary", "text": "Handle potential vulnerabilities", "url": "'${ddLink}'"}' \
    --author 'ClusterScanner' \
    --channel "${slackChannel}" \
    --color bad \
    --fields '{"image": "'${image}'", "app": "'${appName}'", "namespace": "'${namespace}'", "envirnoment": "'${environment}'"}' \
    --footer 'image: '${image}', app: '${appName}', namespace: '${namespace}', envirnoment: '${environment} \
    --footer-icon 'https://assets-cdn.github.com/images/modules/logos_page/Octocat.png' \
    --image 'https://assets-cdn.github.com/images/modules/logos_page/Octocat.png' \
    --pretext "${title}" \
    --text "${message}"
else
  echo "slackChannel not set"
fi

if [ "${email}" != "null" ] && [ "${email}" != "" ]; then
  echo "Sending to email ${email}"
  if [ "${smtp-auth-user}" != "USERNAME@YOURDOMAIN.COM" ] && [ "${smtp-auth-user}" != "" ]; then
    message="$message\nimage: ${image}, app: ${appName}, namespace: ${namespace}, environment: ${environment}, link to DefectDojo: ${ddLink}"
    echo -e "${message}" | mail -s "Found unhandled findings" "${email}" # works
  else
    echo "Warning: email set, but no email configured"
  fi
else
  echo "Hint: email not set"
fi
