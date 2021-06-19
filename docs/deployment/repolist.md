# Image-Source-List

The image-source-list configmap (often configured via _repolist.yml_) has a list of configured repositories for images.
The list will most likly be created  by the _ClusterScanner Image Collector_. As an alternative, it can be manually created or via build pipelines like Jenkins.

The image-source-list can have entries in the following pattern:
`<alphanumeric name>: <source>`. The source is a link to a specific file or to a repository with multiple files.
The `<name>` is only used for a documentation. Please make sure that `<name>` is only used once.
Example:
```
  testSpecificPublicFile: https://raw.githubusercontent.com/SDA-SE/cluster-scan-test-images/master/output-short.json
  testSpecificProtectedFile: https://api.github.com/repos/SDA-SE/cluster-scan-test-images/contents/output.json
  test-alltests: https://api.github.com/repos/SDA-SE/cluster-scan-test-images/tarball
```
