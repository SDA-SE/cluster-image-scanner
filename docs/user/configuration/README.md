# Configration Documentation
Target Audiance: Teams using the cluster scanner to get notified.

To get notified about potential issues, the [ClusterScanner Image Fetcher](../../deployment/clusterscanner-image-collector.md) needs to be setup on the cluster.
As a team, annotations can be set in the following way to enable/disable scanning:
```
# Notification configuration (namespace/object)
contact.sdase.org/email: 'clusterscannertest@sda.se'
contact.sdase.org/team: 'mrkaplan'
contact.sdase.org/slack: '#mrkaplan-security' # in case not set on namespace/pod: derived from as <team>-security

# Skip scanning for an image in a namespace
clusterscanner.sdase.org/skip_regex: '.*-mock' # specially useful for development clusters with development and production components at the same cluster
clusterscanner.sdase.org/skip: true # to skip all images in the namespace

# Object
## Skip scanning for all images in the pod
clusterscanner.sdase.org/skip: true # specially useful for development clusters with development and production components in one namespace
scm.sdase.org/branch: "feature/foobar"
```