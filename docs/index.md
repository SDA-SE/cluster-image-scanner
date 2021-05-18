# ClusterScanner
![Logo](images/logo.png)

Discover vulnerabilities and container image misconfiguration in production environments.

The Cluster Scanner detects images in Kubernetes clusters and provides fast feedback based on security tests. It is recommended to run the Cluster Scanner in production environments.
As a developer, the Cluster Scanner works out of the box. As a system operator, I just have to add the Cluster Scanner in my deployment configuration, for example Argo CD. The benefit is to get feedback on what is in production and not what should be in production. For example, due to waiting for approval or due to a failing build.

The use case is shown in the following figure:
![UseCase](images/usecase.png)

An overview is depicted in the following figure:
![Overview](images/overview.png)


* The Image Collector, as the name suggests, collects the different images.
* These images can be passed to the Fetcher via the Cluster Scan, via the GitOps process, or manually. The Fetcher then converts the CSV files into JSON files and provides additional fields with information about clusters, teams and images.
* These files are kept in a separate directory and from there they are passed to the scanner.
* This scanner - which then receives the libraries to be ignored via the suppressions file - then executes the scans described in the definitions of Dependency Check, Lifetime, Virus and further more.
* The vulnerability management tool then collects the results and makes them available to the developers via a communication channel like Slack.


The documentation is in a transition phase to techdocs.
See also https://sda-se.atlassian.net/wiki/spaces/DG/pages/1322057921/Cluster+Scan+Overview