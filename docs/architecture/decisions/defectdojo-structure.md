# Architecture Decision of DefectDojo Structure DRAFT

Two strcutures are evaluated:
* Grouped by organizations' product
* Grouped by namespace
* image/service

## Grouped by organizations' product:
### Structure
* Product, <cluster> | <kubernetes.io/name> e.g. two-towers
  * Engagement, <ScanType> | <image without tag>, e.g. Dependency Track | quay.io/sdase/cluster-image-scanner-base 
    * Test,  <date> | <imageTag> | (<ScanType>),   	2022-12-04 21:21:49 | 2cbc6c9.47 (Dependency Track Import)

### Pro
* Statistics for products are easier to understand for humans because they are visible in an aggregated form.  

### Con
* Extra work to integrate


## Grouped by namespace:
### Structure
* Product, <cluster> |<namespace> e.g. two-towers
    * Engagement, <ScanType> | <image without tag>, e.g. Dependency Track | quay.io/sdase/cluster-image-scanner-base
        * Test,  <date> | <imageTag> | (<ScanType>),   	2022-12-04 21:21:49 | 2cbc6c9.47 (Dependency Track Import)

### Pro
* Statistics for products are easier to understand for humans because they are visible in an aggregated form.

### Con
* Extra work to integrate


##  image/service:
### Structure
* Product, <cluster> | <namespace> |<image without tag> e.g. quay.io/sdase/cluster-image-scanner-base
    * Engagement, <ScanType> | <image without tag>, e.g. Dependency Track | quay.io/sdase/cluster-image-scanner-base
        * Test,  <date> | <imageTag> | (<ScanType>),   	2022-12-04 21:21:49 | 2cbc6c9.47 (Dependency Track Import)

### Pro
* Current default status (no extra work)
### Con

## Conclusion
A combination of _grouped by organizations' product_ and _grouped by namespace_ is prefered. By default, _grouped by namespace_ is used. In case a label _kubernetes.io/name_ exists, the value is used instead of the namespace.