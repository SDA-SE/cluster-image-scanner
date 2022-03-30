#!/bin/bash
if [[ ! -f /tmp/private ]]; then
  ssh-keygen -f /tmp/private -N ""
  chmod 777 /tmp/private
fi
docker pull quay.io/sdase/cluster-image-scanner-imagecollector:2
docker run -v /tmp/private:/.ssh/id_rsa/ssh-privatekey -v $(pwd)/../../base/git.bash:/home/code/git.bash -v $(pwd)/../../base/auth.bash:/home/code/auth.bash -v $(pwd)/entrypoint.sh:/home/code/entrypoint.sh  -v $(pwd)/pods.bash:/home/code/pods.bash    --env GIT_SSH_REPOSITORY_HOST=github.com/SDA-SE/cluster-scan-test-images.git  --user=2300:5555 -ti --rm quay.io/sdase/cluster-image-scanner-imagecollector:2
