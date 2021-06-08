# Configration Documentation
Target Audience: Teams using the cluster scanner to get notified.

To get notified about potential issues, the [ClusterScanner Image Collector](../../deployment/clusterscanner-image-collector.md) needs to be setup on the cluster.
As a team, annotations can be set in the following way to enable/disable scanning:

```
# Notification configuration (namespace/object)
contact.sdase.org/email: 'clusterscannertest@sda.se'
contact.sdase.org/team: 'mrkaplan'
contact.sdase.org/slack: '#mrkaplan-security' # in case not set on namespace/pod: derived from as <team>-security

# Skip scanning for an image in a namespace
clusterscanner.sdase.org/skip_regex: '.*-mock' # especially  useful for development clusters with development and production components at the same cluster
clusterscanner.sdase.org/skip: true # to skip all images in the namespace

# Object
## Skip scanning for all images in the pod
clusterscanner.sdase.org/skip: true # specially useful for development clusters with development and production components in one namespace

app.kubernetes.io/name: 'consent-service' # defaults to image
scm.sdase.org/source_branch: 'feature/foobar'

# Adjust scans on object or namespace
clusterscanner.sdase.org/is-scan-lifetime=true # or false
clusterscanner.sdase.org/is-scan-distroless=true # or false
clusterscanner.sdase.org/is-scan-dependency-check=true # or false
clusterscanner.sdase.org/is-scan-runasroot=true # or false
clusterscanner.sdase.org/is-scan-malware=false # scan to be implemented

clusterscanner.sdase.org/max-lifetime='14' # max lifetime days for the lifetime scan
```
The inheritance of overriding the parent annotations/configuration is pointed out in the following figure:
![inheritance](inheritance.png)