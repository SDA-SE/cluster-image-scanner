# Known Vulnerabilities via OWASP Dependency Check

## Relevance
Services and artifacts often rely on external dependencies for all sorts of reasons. These dependencies may have known vulnerabilities.

## Response
Use the following vulnerability treatments on issues:

### Avoidance
Elimination of the vulnerability by replacing the dependency containing the vulnerability with another dependency.

### Mitigation
In case a patch for the dependency containing the vulnerability is available which fixes the vulnerability, the usage of the patched version is highly recommended. After the patch is in production, the vulnerability management system OWASP DefectDojo will detect that the vulnerability is not getting reported and therefore automatically closes the vulnerability.

The use of pinning a transitive dependency version and/or exclusion of a transitive dependencies MAY be performed to mitigate vulnerabilities. As pinning and exclusions come with high risks to the stability of the system, advanced tests of the whole product need to be conducted. It is not a recommended way to handle vulnerabilities, but is better than the acceptance of a vulnerability.

### Acceptance
In case no patch for the direct or transitive dependency is available, or the mitigation is very cost intensive (e.g. pinning of a core library without having tests), acceptance is the last option.

A simple assessment MUST be performed. The calculation SHOULD be performed with the BASE SCORE of the CVSS Calculator. The OWASP Risk Rating Methodology in this wiki might also help in case there are further questions raised during the assessment.

Vulnerabilities SHOULD only be accepted temporary by setting a due date after the vulnerability is reported again in order to be able to check possible treatments again.

### False Positive
Mark the finding as false positive in DefectDojo.