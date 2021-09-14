# ClusterScanner Image Collector
The _ClusterScanner Image Collector_ collectors images from a cluster.

## Solution Overview
![Overview](images/collector.png)
The Cluster Scan Image Collector gets pods, parses the pod descriptions and, extracts namespaces and images, including image tags and hashes. Because mutable images (e.g. lastest) might be used, the image hash is gathered in case it is available. The image hash is not available for nonrunning cronjobs with history enabled. To get pods from within a container in a cluster, kubectl is used and defined in _entrypoint.bash_ like the following:
```
kubectl get pods -A -o json
```

The ClusterScanner Image Collector pushes the used images into the defined target repository. An example entry in the pushed flat JSON is documented in [Github](https://github.com/SDA-SE/cluster-scan-test-images/).

## ISMS compliant asset inventory
### Question: I want to relate: staff->teams->apps->repos->scan results, dependencies, etc.
Let teams add annotations to deployments (e.g. `contact.sdase.org/team`). Teams are also able to add the label `app.kubernetes.io/name`.
So that images for apps are grouped. For source code (repos) annotations can be added
```scm.sdase.org/source_url="https://github.com/cluster-image-scanner"
scm.sdase.org/source_branch="master"
scm.sdase.org/release="1.0.0"
```
We are using the ClusterImageScanner Collector for that https://github.com/SDA-SE/cluster-image-scanner/blob/master/docs/deployment/clusterscanner-image-collector.md
We also use the annoation `sdase.org/description` to get a brief description (might be useful for an auditor who wants to understand what it is used for).

The outcome is stored in github, here is an example https://github.com/SDA-SE/cluster-scan-test-images/blob/master/output.json.

This asset catalog doesn't include stuff not in kubernetes, like apps in a google/app store.

The annotations/labels are often set during build/deployment, fetching it from github-teams or other sources.

The folder `description/missing-service-description.txt` in the target repo of the Collector contains namespaces with missing annoations.
