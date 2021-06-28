# Clusterscanner Scan Lifetime

This repository contains the image configuration for the lifetime scanner, used in the containerized clusterscan.

The purpose of this image is to check the lifetime (time since build date) of the used container images.

# Local build 
## Requirements
buildah

## Build
`$ buildah unshare ./build.sh # creates localhost/clusterscan-lifetime`