# Setup
## Requirements
Tools:
- Kubernetes
- ArgoWorkflow (minimum v2.12.11, v.2.12.5 doesn't work)

Others:
- Images to be scanned in a git repository, e.g. fetched via ClusterScanner Image Collector (might be on the same cluster as the ClusterScanner Orchestrator)
- Communication Channel (e.g. slack, email)
- S3 (with retention policy of _X_ days, e.g. 2) for artifacts
- PersistentVolumeClaim with access mode _ReadWriteMany_ (e.g. AWS EFS or nfs)

## Deployment
For deployment, ArgoCD is recommended.