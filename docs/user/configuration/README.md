# Configration Documentation
Target Audiance: Teams using the cluster scanner to get notified.

To get notified about potential issues, the [ClusterScanner Image Fetcher](../../operator/clusterscanner-image-collector.md) needs to be setup on the cluster.
As a team, annotations can be set in the following way to enable/disable scanning:
```
## Notification endpoints configuration
contact.sdase.org/email: 'clusterscannertest@sda.se'
contact.sdase.org/team: 'mrkaplan'
contact.sdase.org/slack: '#mrkaplan-security' # derived from team, in case not set on namespace/pod
clusterscanner.sdase.org/skip_regex: 'mysql.*' # specially useful for development clusters with development and production components at the cluster

# Object
clusterscanner.sdase.org/skip: true # specially useful for development clusters with development and production components in one namespace
scm.sdase.org/branch: "feature/foobar"
```