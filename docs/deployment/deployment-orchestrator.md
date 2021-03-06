# Setup
## Requirements

Tools:

- Kubernetes
- ArgoWorkflow (ideal v3.X, minimum v2.12.11, v.2.12.5 doesn't work)

Others:

- Images to be scanned in a git repository, e.g. fetched via ClusterScanner Image Collector (might be on the same cluster as the ClusterScanner Orchestrator)
- Communication Channel (e.g. slack, email)
- S3 (with retention policy of _X_ days, e.g. 2) for artifacts
- PersistentVolumeClaim with access mode _ReadWriteMany_ (e.g. AWS EFS or nfs)

## ServiceAccounts
A serviceaccount _clusterscanner_ is needed. _clusterscanner_ will be used to store S3 credentials for ArgoWorkflow artifacts.

## Registry Credentials
Registry credentials can be stored as (Sealed)Secret:
```
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: registry-sda-default
  namespace: clusterscanner
  labels:
    app.kubernetes.io/name: clusterscanner
spec:
  encryptedData:
    auth.json: XXXX
  template:
    metadata:
      creationTimestamp: null
      name: registry-sda-default
      namespace: clusterscanner

```
_auth.json_ will be mounted to fetch to be scanned container images from registries with authentication. It has the following format:
```
{
	"auths": {
		"quay.io": {
			"auth": "XXX"
		}
	},
	"HttpHeaders": {
		"User-Agent": "Docker-Client/18.09.5 (linux)"
	}
```
Multiple registries (identified via different hosts) can be defined.

## Persistent Volume Claims
To temporary store images, they are stored in a PVC.
Make sure to have enough space in the PVC, as all scanned images will be stored in the PVC as tar.

## Multi Tenant Deployment
By having multiple clusters (e.g. due to multiple customers):
![multitenant](multitenant.png)
The following figure shows the ArgoWorkflows workflow structure:
![multitenant](multitenant-impl.png)

## Slack Token
In case slack is used, an app should be created. The creation of an app including "Bot Tokens" is described in the [slack app documentation](https://api.slack.com/tutorials/tracks/hello-world-bolt). The scope `chat:write` is needed. The created user needs to be invite to all channels in which the user should post messages to.
