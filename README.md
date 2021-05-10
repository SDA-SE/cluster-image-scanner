# Cluster Scanner
<span style="display:block;text-align:center">

![Logo](assets/images/logo.png "Logo")

</span>

Discover vulnerabilities and container image misconfiguration in production environments.

# Introduction
The _Cluster Scanner_ detects images in Kubernetes clusters and provides fast feedback based on security tests.
It is recommended to run the Cluster Scanner in production environments.

As a developer, the Cluster Scanner works out of the box.
As a system operator, I just have to add the Cluster Scanner in my deployment configuration, for example Argo CD. The benefit is to get feedback on what is in production and not what should be in production. For example, due to waiting for approval or due to a failing build.

# Overview
In order to achieve an understanding of the cluster scanning process, this page uses a chart and detailed documentation to describe which factors are involved and in which way.
1. The Image Collector, as the name suggests, collects the different images.
2. These images can be passed to the Fetcher via the Cluster Scan, via the GitOps process, or manually. The Fetcher then converts the CSV files into JSON files and provides additional fields with information about clusters, teams and images.
3. These files are kept in a separate directory and from there they are passed to the scanner.
4. This scanner - which then receives the libraries to be ignored via the suppressions file - then executes the scans described in the definitions of Dependency Check, Lifetime, Virus and further more.
5. The vulnerability management system then collects the results and makes them available to the developers via Slack.
## Table of Contents

- [User documentation](docs/user)
- [Architecture and Decisions](docs/architecture)
- [Operator documentation](docs/operator)


# Local testing
The following is a description of `test/minikube-setup.bash`.

## Install argocd CLI and argo CLI
Local setup
* See https://github.com/argoproj/argo-cd/releases
* See https://github.com/argoproj/argo-workflows/releases


## Install argocd
(see also https://argoproj.github.io/argo-cd/getting_started/):
```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

sleep 20 # wait
kubectl patch deploy argocd-server -n argocd -p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]' --type json

kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Visit [https://localhost:8080/applications/](https://localhost:8080/applications/)

## Create Project
```
argocd proj  --server localhost:8080 --insecure create clusterscanner -d https://kubernetes.default.svc,clusterscanner 
argocd proj --server localhost:8080 --insecure add-source clusterscanner "*"
argocd proj --server localhost:8080 --insecure allow-cluster-resource clusterscanner '*' '*' 
argocd proj --server localhost:8080 --insecure deny-namespace-resource "clusterscanner" '*' '*' # needed for add
argocd proj --server localhost:8080 --insecure allow-namespace-resource  clusterscanner '*' '*'
argocd repo --server localhost:8080 --insecure add git@github.com:SDA-SE/clusterscanner-orchestration.git --ssh-private-key-path ~/.ssh/id_rsa

 ```
## Add Secrets
[https://localhost:8080/settings/repos](https://localhost:8080/settings/repos)
Adjust defectdojo and DD_TOKEN in deployment/test/config-placeholder/defectdojo-test-secret and deployment/test/defectdojo-test-config




## Install argoworkflow and clusterscanner
`kubectl apply -f app.yml`

## minIO (S3)
Decide to use minIO or AWS S3. In case of minio:
`kubectl apply -f minio/app.yml`

### Initial Setup / Debugging
`kubectl -n clusterscanner port-forward deployment/argo-server 9000:9000`
Goto http://localhost:9000/minio/ -> create bucket -> "clusterscan-artifacts"


## Argoworkflow
`kubectl -n clusterscanner port-forward deployment/argo-server 2746:2746`

Visit [http://localhost:2746/workflows/clusterscanner](http://localhost:2746/workflows/clusterscanner)

## Add configurations
Add secrets to artifacts-aws in case AWS S3 should be used.
```
kubectl apply -f deployment/test/config/artifacts-aws.yml # kubectl apply -f deployment/test/config/artifacts.yml 
kubectl apply -f deployment/test/config/defectdojo-test-config.yml 
kubectl apply -f deployment/test/config/dependency-check-config.yml
kubectl apply -f deployment/test/config/registry-test-default-secret.yml
kubectl apply -f deployment/test/config-placeholder/defectdojo-test-secret.yml
kubectl apply -f deployment/test/config/secrets/test/github-secret.yml
```

## Pull Secret
kubectl create secret docker-registry regcred --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>
for example
```
kubectl create secret docker-registry dockerhub --docker-server=https://registry.hub.docker.com --docker-username=wurstbrot --docker-password=xxx # unlimted pulls
kubectl create secret docker-registry quayio --docker-server=https://quay.io --docker-username="sdase+cluster_vulnerability_scan" --docker-password=xxx

# for workflows
kubectl create secret docker-registry quayio --docker-server=https://quay.io --docker-username="sdase+cluster_vulnerability_scan" --docker-password=xxx -n clusterscanner
kubectl create secret docker-registry dockerhub --docker-server=https://registry.hub.docker.com --docker-username=wurstbrot --docker-password=xxx -n clusterscanner
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "dockerhub"},{"name": "quayio"}]}' -n clusterscanner
```
## execute and check workflows
argo submit deployment/test/workflow/argo-main.yml

`argo list -n clusterscanner`

# TODO
deployment/sda/config/secrets/sda/github-secret.yml für Test einrichten