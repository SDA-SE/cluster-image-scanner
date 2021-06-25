# Release Process

This document describes the release process of SDA ClusterScanner.

## Happy Path
The release process is automated.
It generates new releases for all (commits/) and performed merges to `master` and uploads all releases as images to quay.io/sdase/clusterscanner-scan-dependency-check:x.x.x.

See also `build.sh` and `.github/workflows/master.yaml`.
