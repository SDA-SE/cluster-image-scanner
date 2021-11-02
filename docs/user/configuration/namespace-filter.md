# Usecases for the `namespace_filter`
By using one target environment, _release_ (branch _master_) and _develop_ (branch _develop_) will be in the same environment and should be scanned.

In this scenario, a release is deployed separately, resulting in the following structure in a _kustomize_ deployment:
* base
* overlay/release

For _release_, the annotation `clusterscanner.sdase.org/skip: "false"` can be added.
_develop_ is often treated as a normal branch, so that no difference between develop and an other PR is given.
For such cases a namespace_filter with a regex is needed to give teams the flexibility to include namespaces they want.

Sample Namespaces:
* master: fellowship-ring-release
* Develop: fellowship-ring-develop
* PR 1: master: fellowship-ring-pr1
* PR 2: master: fellowship-ring-pr2

An example filter:
```
clusterscanner.sdase.org/namespace_filter: "^fellowship-ring-release$\|^fellowship-ring-develop$"
```

While production is important for security metrics, the branch develop is important during the development process.
Therefore, we need a way distinguish them in DefectDojo. DefectDojo offers tags, so that we can add tags.

A way to do it is use the existing functionality of
`scm.sdase.org/source_branch="master"`
which will create an engagement with the scan type and append the branch. Otherwise, the image tag (e.g. 1.2.3) is used.
