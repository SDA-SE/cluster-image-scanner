# Scan Run As Root

The Root Account scan checks if the user root is found during a scan of the container images. The root user is the administrator account that can be used to exploit any rights. 

## Relevance
Containers running as root user are running with higher privileges than necessary. Container images are using isolation and do not have the same security level given by virtualization with hypervisor type I.

## Resolution
Use the following treatments on issues:

### Avoidance
Do not use the image.

### Acceptance
After an assessment, the risk owner accept the risk. This might be the case for infrastructure related container images. In case the cluster deployment configuration enforces using non-root images, a temporary acceptance is recommended.

### False Positive
In case the image runs as root, but you enforce a user via the deployment manifest in kubernetes, you might mark this as false positive.
In all other cases, please inform the security team in order to adjust the check.
