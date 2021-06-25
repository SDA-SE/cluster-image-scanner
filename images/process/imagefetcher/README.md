# Clusterscan Imagefetcher

This repository contains the image configuration for the imagefetcher, used in the containerized clusterscan.

The purpose of this image is to download container images to tarballs for later inspection by the clusterscan modules.

# Local build 
## Requirements
buildah

## Build
`$ buildah unshare ./build.sh # creates localhost/clusterscan-imagefetcher`