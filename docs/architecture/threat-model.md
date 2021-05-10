# Rudimentary Threat Model
To satisfy the high protection requirement, rudimentary threat modeling has been conducted and documented. The measures can also be used to understand the architecture of the cluster scan.

Attack: As an adversary, I compromise the cluster-scan collector image or container and try to access other projects on GitHub\
Measure: The GitHub token is restricted to access the cluster-image repository only. (HOWTO documentation outstanding)
Hint: The compromise of an image might be done through different attack vectors like taking over quay.io image or the GitHub account with the corresponding infrastructure as code (Dockerfile). The compromise of a container might be performed from an other compromised container.

Attack: As an adversary, I compromise the GitHub repository or organization and remove all entries to make sure that malware distributed in images is not getting detected.\
Measure: The access to the GitHub repository is restricted. (HOWTO documentation outstanding)

Attack: As an adversary, I compromise the _clusterscan image collector_ image or container and want to get as much information from other pods as possible.\
Measure: The container is limited within its own namespace. (unknown)

Attack: As an adversary, I compromise the cluster-scan collector image or container and want to get as much information from the API as possible.\
Measure: The service-account-token is limited to get pod manifest, only (least privileges). (done)

Attack: As an adversary, I compromise the cluster-scan collector image or container and connect to other containers.\
Measure 1: The service-account-token is limited to get pod manifest, only (least privileges).\
Measure 2: The container should be able to connect to the api only and not be able to connect to other containers. (outstanding)