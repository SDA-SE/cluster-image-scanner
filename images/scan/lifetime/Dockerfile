FROM quay.io/sdase/centos-development:8

RUN useradd clusterscanner && \
    dnf install -y --setopt=install_weak_deps=false --setopt=tsflags=nocontexts,nodocs skopeo && \
    dnf clean all && \
    rm -rf /var/{cache,log}/* /tmp/* && \
    mkdir -p /clusterscanner && \
    chown clusterscanner:clusterscanner /clusterscanner

USER clusterscanner
WORKDIR /clusterscanner
ENTRYPOINT [ "bash" ]

ADD module.bash /clusterscanner/module.bash

ENV CLUSTER_SCAN_BASE_PATH=/clusterscanner
