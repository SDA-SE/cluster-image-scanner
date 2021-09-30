# Scan New Version
The new version scan tests for a new version in the defined registry for the defined filter (e.g. an organization in quay.io).
It searches for (simple) a new image in the registry. (simple) semantic versioning (e.g. 1.1.1 or v1.1.1) must be used by the repository.

## Relevance
A new version might fix security issues, even without announcing it.

## Response
Use the following treatments on issues:

### Mitigation
Usage the new image version.

### Acceptance
Temporary acceptance, for example because the new version will be deployed in within the next spring, is an option.
Do not accept this with for a too long time (or even forever). 

### False Positive
If the result is a false positive, in addition to mark it as such in DefectDojo, please create an [Issue](https://github.com/SDA-SE/cluster-image-scanner/issues/new).
False Positives shouldn't happen.
