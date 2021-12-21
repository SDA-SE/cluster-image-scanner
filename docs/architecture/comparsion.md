# Comparsion with other scanning tools
|                       Feature                | ClusterImageScanner   | Clair | AWS Inspector           |
|----------------------------------------------|-----------------------|-------|-------------------------|
| Correlation of production images with scan results  | Yes                   | No    | Unknown                 |
| Bill of Materials                            | Yes (Dependency Track)| No    | No                      |
| Vuln. in OS dependencies                     | Yes (Dependency Track)| Yes   | Yes                     |
| Vuln. in software dependencies               | Yes                   | No    | Yes (Enhanced scanning) |
| New dependency available                     | Yes (Dependency Track)| No    | Yes (Enhanced scanning) |
| Image Lifetime scan                          | Yes                   | No    | No                      |
| BaseImage Lifetime scan                      | Yes                   | No    | No                      |
| Run as root scan                             | Yes                   | No    | No                      |
| Malware scan                                 | Yes                   | No    | No                      |
| Distroless scan                              | Yes                   | No    | No                      |
| New image version scan                       | Yes                   | No    | No                      |
| Notification of teams                        | Yes                   | No    | Unknown                 |
