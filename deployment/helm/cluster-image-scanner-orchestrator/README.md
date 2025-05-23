# cluster-image-scanner-orchestrator

![Version: 0.1.3](https://img.shields.io/badge/Version-0.1.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A chart that deploys the image metadata orchestrator.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| api.host | string | `""` |  |
| api.path | string | `"/all-image-collector-reports"` |  |
| api.pathSeparator | string | `"/"` |  |
| api.version | string | `"v1"` |  |
| credentials.apikey | string | `""` |  |
| credentials.signature | string | `""` |  |
| cronSchedule | string | `"*/1 * * * 1-5"` |  |
| defectdojo.branchesToKeep | string | `"*"` |  |
| defectdojo.deduplicationOnEngagement | string | `"false"` |  |
| defectdojo.gitUrl | string | `"https://github.com/sda-se"` |  |
| defectdojo.importType | string | `"import"` |  |
| defectdojo.lead | string | `"3"` |  |
| defectdojo.markedAsActive | string | `"true"` |  |
| defectdojo.markedAsInactive | string | `"false"` |  |
| defectdojo.reportPath | string | `"/tmp/dependency-check-results/dependency-check-report.xml"` |  |
| defectdojo.token | string | `""` |  |
| defectdojo.url | string | `""` |  |
| defectdojo.user | string | `""` |  |
| dependencytrack.key | string | `""` |  |
| dependencytrack.url | string | `""` |  |
| github.appId | string | `""` |  |
| github.appLogin | string | `""` |  |
| github.installationId | string | `""` |  |
| github.privateKeyPem | string | `""` |  |
| image.tag | string | `"3"` |  |
| imageSourceList.image-lifetime | string | `"https://raw.githubusercontent.com/SDA-SE/cluster-scan-test-images/master/image-lifetime.json"` |  |
| isLocal | bool | `false` |  |
| registry.authJson | string | `""` |  |
| resources.limits.memory | string | `"128Mi"` |  |
| resources.requests.cpu | string | `"50m"` |  |
| resources.requests.memory | string | `"128Mi"` |  |
| scanjob.caBundle | string | `nil` |  |
| scanjob.ddDaysToKeepWithoutUpload | string | `"0"` |  |
| scanjob.ddNameTemplate | string | `"###ENVIRONMENT### | ###NAMESPACE###"` |  |
| scanjob.dependencyTrack.threshold.application.alpine.critical | int | `8` |  |
| scanjob.dependencyTrack.threshold.application.alpine.high | int | `20` |  |
| scanjob.dependencyTrack.threshold.application.alpine.medium | int | `100` |  |
| scanjob.dependencyTrack.threshold.application.deb.critical | int | `8` |  |
| scanjob.dependencyTrack.threshold.application.deb.high | int | `20` |  |
| scanjob.dependencyTrack.threshold.application.deb.medium | int | `100` |  |
| scanjob.dependencyTrack.threshold.application.golang.critical | int | `1` |  |
| scanjob.dependencyTrack.threshold.application.golang.high | int | `1` |  |
| scanjob.dependencyTrack.threshold.application.golang.medium | int | `100` |  |
| scanjob.dependencyTrack.threshold.application.maven.critical | int | `1` |  |
| scanjob.dependencyTrack.threshold.application.maven.high | int | `1` |  |
| scanjob.dependencyTrack.threshold.application.maven.medium | int | `100` |  |
| scanjob.dependencyTrack.threshold.application.npm.critical | int | `1` |  |
| scanjob.dependencyTrack.threshold.application.npm.high | int | `1` |  |
| scanjob.dependencyTrack.threshold.application.npm.medium | int | `100` |  |
| scanjob.dependencyTrack.threshold.application.pypi.critical | int | `8` |  |
| scanjob.dependencyTrack.threshold.application.pypi.high | int | `20` |  |
| scanjob.dependencyTrack.threshold.application.pypi.medium | int | `100` |  |
| scanjob.dependencyTrack.threshold.application.rpm.critical | int | `8` |  |
| scanjob.dependencyTrack.threshold.application.rpm.high | int | `20` |  |
| scanjob.dependencyTrack.threshold.application.rpm.medium | int | `100` |  |
| scanjob.dependencyTrack.threshold.thirdParty.alpine.critical | int | `30` |  |
| scanjob.dependencyTrack.threshold.thirdParty.alpine.high | int | `100` |  |
| scanjob.dependencyTrack.threshold.thirdParty.alpine.medium | int | `9999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.deb.critical | int | `30` |  |
| scanjob.dependencyTrack.threshold.thirdParty.deb.high | int | `100` |  |
| scanjob.dependencyTrack.threshold.thirdParty.deb.medium | int | `9999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.golang.critical | int | `99` |  |
| scanjob.dependencyTrack.threshold.thirdParty.golang.high | int | `999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.golang.medium | int | `9999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.maven.critical | int | `99` |  |
| scanjob.dependencyTrack.threshold.thirdParty.maven.high | int | `999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.maven.medium | int | `9999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.npm.critical | int | `99` |  |
| scanjob.dependencyTrack.threshold.thirdParty.npm.high | int | `999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.npm.medium | int | `9999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.pypi.critical | int | `99` |  |
| scanjob.dependencyTrack.threshold.thirdParty.pypi.high | int | `999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.pypi.medium | int | `9999` |  |
| scanjob.dependencyTrack.threshold.thirdParty.rpm.critical | int | `30` |  |
| scanjob.dependencyTrack.threshold.thirdParty.rpm.high | int | `100` |  |
| scanjob.dependencyTrack.threshold.thirdParty.rpm.medium | int | `9999` |  |
| scanjob.dependencyTrackNameTemplate | string | `"###ENVIRONMENT### | ###NAMESPACE### | ###APP_NAME###"` |  |
| scanjob.errorNotificationIgnore | string | `"DiskPressure\\|imagefetcher.*sj-tools-kube-system\\|sj-si-verzahnung-defectdojo"` |  |
| scanjob.registryOverride.default.from | string | `""` |  |
| scanjob.registryOverride.default.to | string | `""` |  |
| scanjob.registryOverride.dockerA.from | string | `""` |  |
| scanjob.registryOverride.dockerA.to | string | `""` |  |
| scanjob.registryOverride.dockerIo.from | string | `""` |  |
| scanjob.registryOverride.dockerIo.to | string | `""` |  |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `true` |  |
| securityContext.runAsUser | int | `56315` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automount | bool | `true` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `"clusterscanner"` |  |
| slack.cliToken | string | `""` |  |
| storage.s3.bucket | string | `""` |  |
| storage.s3.endpoint | string | `"s3.eu-central-1.amazonaws.com"` |  |
| storage.s3.insecure | bool | `false` |  |
| storage.s3.useSDKCreds | bool | `true` |  |
| volumeMounts | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
