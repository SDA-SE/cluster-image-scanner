#!/bin/bash
if [[ ! -f /tmp/private ]]; then
  ssh-keygen -f /tmp/private -N ""
  chmod 777 /tmp/private
fi
docker pull quay.io/sdase/cluster-image-scanner-image-source-fetcher:featcollector-test
docker run -v /tmp/private:/.ssh/id_rsa/ssh-privatekey \
  -v $(pwd)/../../base/auth.bash:/clusterscanner/auth.bash \
  -v $(pwd)/../../base/git.bash:/clusterscanner/git.bash \
  -v /tmp/cluster-image-scanner-test.2022-08-21.private-key.pem:/clusterscanner/github/github_private_key.pem \
  --env GH_KEY_FILE_PATH="/clusterscanner/github/github_private_key.pem" \
          --env GH_APP_LOGIN="SDA-SE" \
          --env GH_APP_ID="" \
          --env GH_INSTALLATION_ID="" \
          --env GIT_REPOSITORY="https://api.github.com/repos/SDA-SE/cluster-image-scanner-sda-internal-test-images/tarball"  \
  -ti --rm quay.io/sdase/cluster-image-scanner-image-so  urce-fetcher:featcollector-test
