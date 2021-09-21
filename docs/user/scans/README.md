Software and infrastructure are potential points of attack. Such attacks can lead to damages, financial losses due to failures or recourse claims from customers, and more. There are various forms of investigations that protect against such threats. Manual searches for these vulnerabilities and points of attack require a great deal of effort and tie up staff in the execution. Automated scanning reduces effort and minimizes errors such as forgotten tests. The different types of scanning used, their significance, and possible reactions to the results are listed below.

# Types of Scans
There are a number of different types of scans that can produce different findings. Each check is introduced by a short summary of the relevance and different response possibilities.

## Misconfigurations

- [Distroless](distroless.md)
- [Root-User](run-as-root.md)

## Known Vulnerabilities and Malware

- [Known Vulnerabilities](known-vulnerabilities.md)
- [Malware](malware.md)

## Patch Management

- [BaseImage Lifetime](baseimage-lifetime.md)
- [Image Lifetime](image-lifetime.md)
- [New version](new-version.md)

# Responses to Findings
When a finding is detected, the first step is to perform an analysis. The following treatments can be used for this:

- Avoidance: Remove the component with the threat/vulnerability.
- Mitigation: Patch a vulnerability. In DefectDojo, vulnerabilities are automatically closed after the next scan report.
- Acceptance: Accept a vulnerability. In DefectDojo, the vulnerability needs to be manually marked as Accepted.
- False Positive: The finding doesn't apply. In DefectDojo, the vulnerability can be manually marked as False Positive.

Not all responses apply to all scans. In the scan descriptions, the possible responses are described.
We use OWASP DefectDojo as vulnerability management system to combine the findings of different tools. All described, scans are implemented by the _Cluster Scanner_.
