# Scan BaseImage Lifetime
The baseimage lifetime scan has the implication that images based on the respective container baseimage should only run for a certain period of time (e.g. 5 days) in the cluster, otherwise libraries contained in the baseimage might be outdated.

## Relevance
The baseimage lifetime scan inspects the build time of first image layer (called base image) of the image under scan. In case the baseimage is older than the defined lifetime, the baseimage and therefore the image might run with outdated components.
By using an update to date base image, it minimizes the potential vulnerabilities, since a newly build image is up to date with the latest software components.

Container images consists of:
- Application and the application dependencies
- Operating system packages

![Lifetime Scans](lifetime-scans.png)

## Response
Use the following threat treatments on issues:

### Avoidance
Do not use the image in production.

### Mitigation
Update the base image. In a Dockerfile, the image in the first line `FROM` should be checked for new versions.

In case the image is a third party image, consider to build the image on your own and using the latest available application/service version.

### Acceptance
The runtime of the image over the recommended time span cannot have any comprehensible reasons. Even if the application contained in the image has not been updated at all, it is recommended to start a new image build after the maximum allowed time period.

Hint: The maximum defined lifetime your team agreed on can be configured.

### False Positive
A false positive case would only occur if the number of days was incorrect. Since the scan does not assume that this can happen, a possible action can be neglected.
