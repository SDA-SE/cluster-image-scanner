# CentOS image with kubectl

needed for cluster-scan

# Contact: security team

# Development
`docker run -ti --user 1000 --volume $(pwd)/pods.bash:/pods.bash --volume $(pwd)/known_hosts:/.ssh/known_hosts --volume $(pwd)/entrypoint.bash:/entrypoint.bash  --env GIT_SSH_REPOSITORY_HOST --volume $(pwd)/git.bash:/git.bash --env GIT_SSH_REPOSITORY_HOST=github.com --env GIT_REPOSITORY_PATH="/wurstbrot/test" --volume /home/tpagel/.ssh/id_rsa:/.ssh/id_rsa quay.io/sdase/cluster-scan-image-collector:1`