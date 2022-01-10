# Comparsion with other scanning tools
|                       Feature                | ClusterImageScanner   | Clair | AWS Inspector           |
|----------------------------------------------|-----------------------|-------|-------------------------|
| Correlation of production images with scan results  | Yes                   | No    | Unknown                 |
| Bill of Materials                            | Yes (Dependency Track)| No    | No                      |
| Vuln. in OS dependencies                     | Yes (Dependency Track)| Yes   | Yes                     |
| Vuln. in application dependencies            | Yes                   | No    | Yes (Enhanced scanning) |
| New dependency available                     | Yes (Dependency Track)| No    | Yes (Enhanced scanning) |
| Image Lifetime scan                          | Yes                   | No    | No                      |
| BaseImage Lifetime scan                      | Yes                   | No    | No                      |
| Run as Root scan                             | Yes                   | No    | No                      |
| Malware scan                                 | Yes                   | No    | No                      |
| Distroless scan                              | Yes                   | No    | No                      |
| New image version scan                       | Yes                   | No    | No                      |
| Notification of teams                        | Yes                   | No    | Unknown                 |

## Correlation of production images with scan results
The ClusterImageScanner scans images in production. Images in test envirnoments are marked as such or not scanned.

## Bill of Materials
A Software Bill of Materials including all libraries/packages in the image to be scanned.

## Vuln. in OS dependencies
Vulnerabilities in Operating System dependencies, like glibc, are scanned for vulnerabilities.

## Vuln. in application dependencies
Vulnerabilities in application dependencies, like apache-commons in java,are scanned for vulnerabilities.

## New dependency available
Scanning for new versions for dependencies.

## Image Lifetime scan
See [Image Lifetime](../user/scans/image-lifetime.md).

## Base Image Lifetime scan
See [Image Lifetime](../user/scans/baseimage-lifetime.md).

## Run as Root scan
See [Run as Root](../user/scans/run-as-root.md).

## Malware scan
See [Malware](../user/scans/malware.md).

## Distroless scan
See [Distroless](../user/scans/distroless.md).

## New image version scan
See [New Version](../user/scans/new-version.md).

## Notification of teams
The team responsibile for a namespace/container is getting notified.
