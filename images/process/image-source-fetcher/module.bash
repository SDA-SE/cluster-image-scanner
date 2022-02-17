#!/bin/bash
set -e

echo "source auth.bash"
source auth.bash # > /dev/null 2>&1
source git.bash # > /dev/null 2>&1
echo "calling sp_authorize"
sp_authorize || echo "Couldn't authorize, assuming the image-source-repo is accessible by anonymous." #> /dev/null 2>&1

mkdir -p /clusterscanner/out/tmp
i=0
for repofile in /clusterscanner/image-source-list/*; do
  repourl=$(cat "${repofile}")
  echo "${i}: ${repofile} ${repourl}"
  if [ "$(echo "${repourl}" | grep -c "json")" -eq 1 ]; then # do not check for end because the branch might be in the URL
    sp_getfile "${repourl}" "/clusterscanner/out/${i}.json" #> /dev/null 2>&1#
    if [ "$(grep -c 'image' "/clusterscanner/out/${i}.json")" -eq 0 ]; then
      echo "Could not get repo ${repourl} from (${repofile}) or the repos doesn't include images"
      ls -la /clusterscanner/out/${i}.json
      echo "Content of /clusterscanner/out/${i}.json"
      cat /clusterscanner/out/${i}.json
      exit 1
    fi
  elif [ $(echo "${repourl}" | grep -c "ssh://") -eq 1 ]; then
    GIT_REPOSITORY_PATH=$(echo ${repourl} | sed 's#.*@##g')
    GIT_REPOSITORY_PATH=$(echo ${GIT_REPOSITORY_PATH#*/})
    GIT_SSH_REPOSITORY_HOST=$(echo ${repourl} | sed 's#.*@##g' | sed 's#/.*##g')
    gitAuth
    git clone "${repourl}" /tmp/${i}
    find /tmp/${i} -name "*.json" -exec mv "{}" /clusterscanner/out/ \;
    rm -Rf /tmp/${i}
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
