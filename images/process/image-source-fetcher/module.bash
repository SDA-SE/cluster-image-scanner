#!/bin/bash
set -e

source auth.bash # > /dev/null 2>&1
if [ -z "${GITHUB_APP_ID}" ] || [ -z "${GITHUB_INSTALLATION_ID}" ]; then
  sp_authorize #> /dev/null 2>&1
else
  echo "GITHUB_APP_ID and GITHUB_INSTALLATION_ID are not set. Assuming the image-source-repo is accessible by anonymous."
fi
mkdir -p /clusterscanner/out/tmp
i=0
for repofile in /clusterscanner/image-source-list/*; do
  repourl=$(cat "${repofile}")
  echo "${i}: ${repofile} ${repourl}"
  if [ "$(echo "${repourl}" | grep -c "json$")" -eq 1 ]; then
    sp_getfile "${repourl}" "/clusterscanner/out/${i}.json" #> /dev/null 2>&1#
    if [ "$(grep -c 'image' "/clusterscanner/out/${i}.json")" -eq 0 ]; then
      echo "Could not get repo ${repourl} from (${repofile}) or the repos doesn't include images"
      exit 1
    fi
  else
    dest="/clusterscanner/out/${i}.tar"
    sp_getfile "${repourl}" "${dest}" "application/vnd.github.v3+json" #> /dev/null 2>&1#
    cd /clusterscanner/out/tmp/
    tar xfv "${dest}"
    find . -name "*.json" -exec mv "{}" /clusterscanner/out/ \;
    cd -
    rm -Rf /clusterscanner/out/tmp/* || true
    rm "${dest}"
  fi
  ((i=i+1))
done
mkdir -p /clusterscanner/out/merged
jq -s 'flatten' /clusterscanner/out/*.json > /clusterscanner/out/merged/merged.json
sed -i 's#"scm_source_branch": null#"scm_source_branch": "notset"#g' /clusterscanner/out/merged/merged.json
ls -la /clusterscanner/out/merged/
exit 0
