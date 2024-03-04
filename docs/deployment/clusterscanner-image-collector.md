# Cluster Scan Image Collector
The _ClusterScanner Image Collector_ is deployed in a Kubernetes cluster and needs to have read access on all pods.

The ClusterScanner Orchestrator needs to have a _ClusterRole_ with  read access to the resource pod.

## Deployment
- Creation of a git repository to store the images (e.g. _github.com/YOUR-ORG/clusterscanner-image-collector-images-<ENV NAME>.git_)
- Providing access to the _ClusterScanner Image Collector_ (e.g. github app or ssh with a private key)
- Deployment of the _ClusterScanner Image Collector_ with the created secret

In the following is a sample deployment.
### Sample configmap.yaml
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: collector-upload-repository
  namespace: clusterscanner-image-collector
data:
  collector.upload.github.appid: "1111"
  collector.upload.github.installlationid: "2222"
  collector.namespacemapping: |
    {
      "teams": [
        {
        "namespaces":
          [
            {
              "namespace_filter": "argo",
              "description": "used for deployment"
            },
            {
              "namespace_filter": "istio-",
              "description": "istio is the Service Mesh of our choice, containg all services neded to run the service mesh"
            }
          ],
          "configurations": {
            "scan_lifetime_max_days": "14",
            "is_scan_lifetime": "true",
            "is_scan_baseimage_lifetime": "false",
            "is_scan_distroless": "false",
            "is_scan_malware": "false",
            "is_scan_runasroot": "false",
            "slack": "#operations-security",
            "team": "operations"
          }
        }
      ]
    }
```
### Sample cronjob.yaml
```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: clusterscanner-image-collector-collector
  namespace: clusterscanner-image-collector
spec:
  schedule: "0 */2 * * *"
  concurrencyPolicy: Forbid
  failedJobsHistoryLimit: 1
  successfulJobsHistoryLimit: 1
  suspend: false
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: clusterscanner-image-collector
          automountServiceAccountToken: true # mount clusterscanner-image-collector
          restartPolicy: Never
          containers:
          - name: clusterscanner-image-collector-image-collector
            securityContext:
              runAsNonRoot: true
              allowPrivilegeEscalation: false
              runAsUser: 1001
            image: quay.io/sdase/cluster-image-scanner-imagecollector:2.0
            imagePullPolicy: Always
            env:
              - name: GH_APP_ID
                valueFrom:
                  configMapKeyRef:
                    name: collector-upload-repository
                    key: collector.upload.github.appid
              - name: GH_INSTALLATION_ID
                valueFrom:
                  configMapKeyRef:
                    name: collector-upload-repository
                    key: collector.upload.github.installlationid
              - name: NAMESPACE_MAPPINGS
                valueFrom:
                  configMapKeyRef:
                    name: collector-upload-repository
                    key: collector.namespacemapping
            resources:
              limits:
                cpu: 100m
                memory: 124Mi
          volumes:
          - name: collector-upload-repository
            configMap:
              name: collector-upload-repository
```
### Sample kustomization.yaml
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- configmap.yaml
- cron-job.yaml
- namespace.yaml
- service-account-authorization.yaml

patchesJSON6902:
- target:
  group: batch
  version: v1
  kind: CronJob
  name: clusterscanner-image-collector-collector
  namespace: clusterscanner-image-collector
  patch: |-
    - op: add
      path: /spec/jobTemplate/spec/template/spec/containers/0/env/0
      value:
      name: DEFAULT_SCAN_LIFETIME_MAX_DAYS
      value: "5"
  patch: |-
    - op: add
      path: /spec/jobTemplate/spec/template/spec/containers/0/env/0
      value:
        name: CLUSTER_NAME
        value: "my-cluster-name"
    - op: add
      path: /spec/jobTemplate/spec/template/spec/containers/0/env/0
      value:
        name: GIT_REPOSITORY
        value: "github.com/YOUR-ORG/clusterscanner-image-collector-images-<ENV NAME>.git"
```
### Sample namespace.yaml
```
apiVersion: v1
kind: Namespace
metadata:
  labels:
    name: clusterscanner-image-collector
  name: clusterscanner-image-collector
  annotations:
    contact.sdase.org/team: "security"
    app.kubernetes.io/name: "clusterscanner"
```

### Sample service-account-authorization.yaml
```
apiVersion: v1
kind: ServiceAccount
metadata:
name: clusterscanner-image-collector
namespace: clusterscanner-image-collector
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: pod-reader-global
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods", "namespaces"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: read-pods-global
subjects:
- kind: ServiceAccount
  name: clusterscanner-image-collector
  namespace: clusterscanner-image-collector
  roleRef:
  kind: ClusterRole
  name: pod-reader-global
  apiGroup: rbac.authorization.k8s.io
---
```
### keyfile.yaml
To be created for example with _kubeseal_.
```
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: github
  namespace: clusterscanner-image-collector
spec:
  # github private key SHA256:XXXXX+++XXXX/XXXXXXXXXXXXXXXXXe8=
  encryptedData:
    keyfile: XXXXXX
  template:
    metadata:
      name: github
      namespace: clusterscanner-image-collector
```

### secret-volume.yaml
```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: clusterscanner-image-collector-collector
  namespace: clusterscanner-image-collector
spec:
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: clusterscanner-image-collector-image-collector
            volumeMounts:
            - name: github
              mountPath: "/etc/github"
              readOnly: true
          volumes:
          - name: github
            secret:
              secretName: github
              items:
                - key: keyfile
                  path: keyfile
```
