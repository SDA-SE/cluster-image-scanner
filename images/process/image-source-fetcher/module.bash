#!/bin/bash
set -ex

echo "source auth.bash"
source auth.bash # > /dev/null 2>&1
echo "calling sp_authorize"
sp_authorize || echo "Couldn't authorize, assuming the image-source-repo is accessible by anonymous." #> /dev/null 2>&1

mkdir -p /clusterscanner/out/merged

# TODO implement https://github.com/SDA-SE/cluster-image-scanner-aws-api?tab=readme-ov-file#request-images-list-of-a-single-cluster to overcome 6mb AWS lamba limit
if [ "${S3_API_LOCATION}" != "" ]; then
  curl --http1.1 --location "${S3_API_LOCATION}" \
      --header "x-api-key: ${S3_API_KEY}" \
      --header "x-api-signature: ${S3_API_SIGNATURE}" \
      | jq '( .[] | select(.team == "") ).team |= "nobody"' \
      > /clusterscanner/out/metadata-api.json
      # test for valid JSON
      jq empty < /clusterscanner/out/metadata-api.json > /dev/null
      # test for object/array in case of not authorized
      [ $(jq 'type=="array"' < /clusterscanner/out/metadata-api.json) == "true" ]
fi

mkdir -p /clusterscanner/out/tmp
i=0
if [ $(ls -l /clusterscanner/image-source-list/ | grep -v total | wc -l) -eq 0 ]; then
  echo "No image-source-list found"
else
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
      source git.bash # > /dev/null 2>&1
      GIT_REPOSITORY_PATH=$(echo ${repourl} | sed 's#.*@##g')
      GIT_REPOSITORY_PATH=$(echo ${GIT_REPOSITORY_PATH#*/})
      GIT_SSH_REPOSITORY_HOST=$(echo ${repourl} | sed 's#.*@##g' | sed 's#/.*##g')
      gitAuth
      git clone "${repourl}" /tmp/${i}
      echo "Will delete service-description.json"
      find /tmp/${i} -type f -name ".*service-description.json" -exec rm -rf {} + || true
      find /tmp/${i} -type f -name "service-description.json" -exec rm -rf {} + || true
      find /tmp/${i} -name "*.json" -exec mv "{}" /clusterscanner/out/ \;
      rm -Rf /tmp/${i}
    else
      dest="/clusterscanner/out/${i}.tar"
      sp_getfile "${repourl}" "${dest}" "application/vnd.github.v3+json" #> /dev/null 2>&1#
      cd /clusterscanner/out/tmp/
      tar xfv "${dest}"
      echo "Will delete service-description.json"
      find . -type f -name "service-description.json" -exec rm -rf {} + || true
      find . -name "*.json" -exec mv "{}" /clusterscanner/out/ \;
      cd -
      rm -Rf /clusterscanner/out/tmp/* || true
      rm "${dest}"
    fi
    ((i=i+1))
  done
fi

mkdir -p /clusterscanner/out/merged
echo "Will flatten JSONs"
jq -s 'flatten | sort_by(.image, .namespace)' /clusterscanner/out/*.json > /clusterscanner/out/merged/merged.json
sed -i 's#"scm_source_branch": null#"scm_source_branch": "notset"#g' /clusterscanner/out/merged/merged.json

ls -la /clusterscanner/out/merged/
# test for valid JSON
jq empty < /clusterscanner/out/merged/merged.json > /dev/null
# test for object/array in case of not authorized
[ $(jq 'type=="array"' < /clusterscanner/out/merged/merged.json) == "true" ]

exit 0
