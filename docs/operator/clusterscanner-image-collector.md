# Cluster Scan Image Fetcher

The fetcher “Cluster Scan Image Collector” fetches images from a cluster. This page presents the collection process and the threat model of the process.

# Introduction
The fetcher “Cluster Scan Image Collector” is deployed in a Kubernetes cluster and needs to have read access on all pods. Therefore, it has a high protection requirement and a threat model has been created.

# Overview
The Cluster Scan Image Collector gets pods, parse the pod descriptions and, extracts namespaces and images, including image tags and hashes. Because mutable images (e.g. lastest) might be used, the image hash is gathered in case it is available. The image hash is not available for nonrunning cronjobs with history enabled. To get pods from within a container in a cluster, kubectl is used and defined in _entrypoint.bash_: 
```shell
kubectl get pods -A -o json | jq -r '.items[] | select(.status.containerStatuses != null) | .metadata.namespace+"'$DELIMITER'"+(.status.containerStatuses[] | .image)+"'$DELIMITER'"+(.status.containerStatuses[] | .imageID)' > /tmp/images
kubectl get pods -A -o json | jq -r '.items[] | select(.status.containerStatuses == null) | .metadata.namespace+"'$DELIMITER'"+(.spec.containers[] | .image)+"'$DELIMITER'"' >> /tmp/images
```

The cluster scan pod needs to have a _ClusterRole_ with _read_ access to the resource pod. An example configuration located in TODO.

The Cluster Scan Image Collector pushed the used images into the defined target repository. An example entry in the pushed comma separated list (csv, deprecated):
```
cluster,namespace,image,imageID,
gitops-devops-tools,argocd,argoproj/argocd:v1.10.0,docker-pullable://argoproj/argocd@sha256:2l1ca3u12msd1231ad0ec2e22910a47f5c56417a40d0
[...]
```
In addition, a JSON in the following format is generated:
```json
{
"environment": "development-cluster-A",
    "namespaces": [
        {
            "namespace": "argocd",
            "images": [
                { "image": "argoproj/argocd:v1.0.0", "imageID": "docker-pullable://argoproj/argocd@sha256:aaaaaaaaa56a7ec41f59ba305b1f8158ada2c7eaee7a87d29fad8d88da650fec" },
                { "image": "redis:1.0.0", "imageID": "docker-pullable://redis@sha256:aaaaaaaaaaaa4b15e3cf4de74077f650c911cb26ec0981e0772df35a1a5cb19798" },
            ]
        },
        {
            "namespace": "argocd",
[...]
```