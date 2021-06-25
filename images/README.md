# Clusterscanner images

This folder contains the build instructions for all container images used by the clusterscanner.

## Folder structure

```sh
├─ base                     # base image used for building other images
├─ processing               # contains images aiding in the scanning process
│  ├─ imagecollector        # collects information about images running in a Kubernetes cluster
│  ├─ imagefetcher          # fetches image contents for scanning
│  ├─ image-source-fetcher  # fetches and preprocesses image lists generated by the imagecollector
│  └─ notifier              # notifies targets of scan results
└─ scan                     # contains all scanner modules
    ├─ dependency-check     # image for OWASP dependency check
    ├─ distroless           # image for distroless check
    ├─ lifetime             # image for lifetime check
    ├─ malware              # image for malware scan
    └─ runasroot            # image for runasroot check
```