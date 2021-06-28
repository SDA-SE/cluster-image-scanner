# ClusterScanner Image Collector
The _ClusterScanner Image Collector_ collectors images from a cluster.

## Solution Overview
![Overview](images/collector.png)
The Cluster Scan Image Collector gets pods, parses the pod descriptions and, extracts namespaces and images, including image tags and hashes. Because mutable images (e.g. lastest) might be used, the image hash is gathered in case it is available. The image hash is not available for nonrunning cronjobs with history enabled. To get pods from within a container in a cluster, kubectl is used and defined in _entrypoint.bash_ like the following:
```
kubectl get pods -A -o json
```

The ClusterScanner Image Collector pushes the used images into the defined target repository. An example entry in the pushed flat JSON is documented in [Github](https://github.com/SDA-SE/cluster-scan-test-images/).

