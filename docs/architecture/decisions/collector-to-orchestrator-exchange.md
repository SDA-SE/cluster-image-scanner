# Architecture Decision for the exchange of the Images (currently output.json) from the Collector to the Orchestrator

## Git
- Often used technology
- Easy to configure across different seperated clusters (when one cluster can not access components of another) and UI
- Versioning is given (easy to browse through)
- Sometimes declared as not production environment

Comments:
- git libraries (like https://github.com/go-git/go-git/tree/master/_examples/clone/auth/basic/access_token) exist for go, but they do not implement the fetching of a github token. This step needs to be done manually.

## S3
- Often used technology
- Might be hard to access the s3 of another cluster for restricted clusters
- Versioning is given (harder to browse through history than git)
- Production ready

## HTTP
- Often used technology
- Easy to configure across different seperated clusters (when one cluster can not access components of another)
- No versioning
- Production ready

Comments:
- The new collector needs 0.5 minutes for a cluster which needs over 70 minutes with the bash collector
- Access control (e.g. API key via mounted secret would be used to restrict access)

## DynamoDB
- Used rarely
- No Versioning
- Depending on the customer, it might be ready to be used or needs to be approved

# Decision
SDA SE woud like to use S3. S3 has derivates for different cloud providers.
S3 could have a UI with minio. Could be used on premises.
S3 can be easy automated with terraform.
