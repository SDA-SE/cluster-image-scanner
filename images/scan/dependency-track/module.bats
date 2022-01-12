#!/usr/bin/env bats

setup() {

    export DEPSCAN_IMAGE="quay.io/sdase/owasp-dependency-check:6"
    export DEPSCAN_DB_DRIVER="org.postgresql.Driver"
    export DEPSCAN_DB_CONNECTSRING="jdbc:postgresql://owasp-dependency-check-db.sda-se.io:5432/owasp?useSSL=false&allowPublicKeyRetrieval=true"
    export DEPSCAN_DB_USERNAME="owaspreader"
    export DEPSCAN_DB_PASSWORD=""
    export CLUSTER_SCAN_BASE_PATH="$(pwd)/../.."

    mkdir -p tmp
    cat << EOF > tmp/suppressions.xml
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">
</suppressions>
EOF
    export SUPPRESSIONS_FILE=$(pwd)/tmp/suppressions.xml
    mkdir -p tmp-results
}

teardown() {
    rm -rf tmp
    rm -rf tmp-results
}

@test 'dependency check: incident negative' {
    IMAGE="quay.io/sdase/cluster-scan-test-images:document-ods-service"
    _imageShortName=$(echo "${IMAGE}" | sed 's#:.*##' | tr -cd '[:alnum:]._-')
    _outDir=$(pwd)/tmp-results/${_imageShortName}
    mkdir -p ${_outDir}
    _result=$(buildah unshare ./depCheck.bash ${IMAGE} ${_outDir} | jq -cM .)
    echo $_result
    [ $(echo $_result | jq '.errors') == '[]' ]
    [ $(echo $_result | jq '.status' | tr -d \") == 'completed' ]
}

@test 'dependency check: incident positive' {
    IMAGE="quay.io/sdase/document-ods-service:0793326"
    _imageShortName=$(echo "${IMAGE}" | sed 's#:.*##' | tr -cd '[:alnum:]._-')
    _outDir=$(pwd)/tmp-results/${_imageShortName}
    mkdir -p ${_outDir}
    _result=$(buildah unshare ./depCheck.bash ${IMAGE} ${_outDir} | jq -cM .)
    echo $_result
    [ $(echo $_result | jq '.errors') == '[]' ]
    [ $(echo $_result | jq '.status' | tr -d \") == 'completed' ]
}

@test 'dependency check: invalid image' {
    IMAGE="this-is-an-unknown-image:v0.0.0.1"
    _imageShortName=$(echo "${IMAGE}" | sed 's#:.*##' | tr -cd '[:alnum:]._-')
    _outDir=$(pwd)/tmp-results/${_imageShortName}
    mkdir -p ${_outDir}
    _result=$(buildah unshare ./depCheck.bash ${IMAGE} ${_outDir} | jq -cM .)
    echo $_result
    [ $(echo $_result | jq '.status' | tr -d \") == 'failed' ]
}
