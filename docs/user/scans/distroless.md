# Scan Distroless 
The distroless scan aims to ensure that the container image contains only the necessary parts. All other programs like shells, packet manager etc. have been removed.

## Relevance
A normal container image contains, in addition to the actual application, many components that ensure the functionality. However, these components also contain parts that are not necessary for the operation of the application. These parts may contain potential vulnerabilities or could otherwise be used for abuse. In order to avoid the possible threats, the images are checked for components that are not required and a warning is given.

## Response
Use the following treatments on issues:

### Avoidance
Do not use the image in production.

### Mitigation
If the scan detects that the image has not been cleaned of parts that are unnecessary for the operation of the image, it is recommended to build container images according to distroless.

### Acceptance
As the risk owner of the application, you can accept the risks coming by the usage of a non-distroless image. A temporary acceptance is recommended, to be reminded of the risk.

### False Positive
In case a shell is needed for the application and distroless is used, the finding can be marked as false positive.

