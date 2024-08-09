#!/bin/bash

wait_for_pods_ready () {
  local name="${1}"; shift
  local namespace="${1}"; shift
  local count="${1}"; shift
  local sleep="${1}"; shift
  local max_attempts="${1}"
  local attempt_num=0

  until [[ $(kubectl -n "${namespace}" get pods -o json | jq '.items | length') -ge "${count}" ]]
  do
    if [[ $(( attempt_num++ )) -ge "${max_attempts}" ]]
    then
      echo "max_attempts ${max_attempts} reached, aborting"
      debug_pods_in_namespace "${namespace}"
      exit 1
    fi
    echo "waiting for ${name} to be created"
    sleep "${sleep}"
  done
  until [[ $(kubectl -n "${namespace}" get pods -o json | jq '.items[].status.conditions[].status=="True"' | grep -c false) -eq "0" ]]
  do
    if [[ $(( attempt_num++ )) -ge "${max_attempts}" ]]
    then
      echo "max_attempts ${max_attempts} reached, aborting"
      debug_pods_in_namespace "${namespace}"
      exit 1
    fi
    echo "waiting for ${name} to be up"
    sleep "${sleep}"
  done
}
debug_pods_in_namespace() {
  namespace=$1
  kubectl get pods -A
  for pod in $(kubectl get pods -n ${namespace} | grep -v NAME  | awk '{print $1}'); do
    echo "######################### ${pod}:"
    kubectl get pod -n ${namespace} ${pod} -o yaml
    kubectl logs -n ${namespace} ${pod}
    echo "#########################"
  done
}
wait_for_pods_completed () {
  local name="${1}"; shift
  local namespace="${1}"; shift
  local count="${1}"; shift
  local sleep="${1}"; shift
  local max_attempts="${1}"
  local attempt_num=0

  until [[ $(kubectl get pods -n ${namespace} | grep -c Running) -eq ${count} ]]
  do
    if [[ $(( attempt_num++ )) -ge "${max_attempts}" ]]
    then
      echo "max_attempts ${max_attempts} reached, aborting"
      debug_pods_in_namespace "${namespace}"
      exit 1
    fi
    echo "waiting for ${name} to be created"
    sleep "${sleep}"
  done
  until [[ $(kubectl get pods -n ${namespace} | grep -c Running) -eq 0 ]]
  do
    if [[ $(( attempt_num++ )) -ge "${max_attempts}" ]]
    then
      echo "max_attempts ${max_attempts} reached, aborting"
      debug_pods_in_namespace "${namespace}"
      exit 1
    fi
    echo "waiting for ${name} to be done"
    sleep "${sleep}"
  done
}

BRANCH=$(git rev-parse --abbrev-ref HEAD)
export BRANCH
#export BRANCH="master"
export MAJOR="3"
export MINOR="0"
export PATCH="${GITHUB_RUN_NUMBER}"
export VERSION="${MAJOR}.${MINOR}.${PATCH}"
if [ "${BRANCH}" != "master" ] && [ "${BRANCH}" != "head" ]; then
  export MAJOR=$(echo ${BRANCH} | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
  export PATCH=""
  if [ "${GITHUB_RUN_NUMBER}" != "" ]; then
    echo "Detected GITHUB_RUN_NUMBER"
    export MINOR="${GITHUB_RUN_NUMBER}"
    if [ "${GITHUB_HEAD_REF}" != "" ]; then
      echo "Detected GITHUB_HEAD_REF"
      export MAJOR=$(echo ${GITHUB_HEAD_REF} | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
    fi
  else
    export MINOR=""
  fi
  export VERSION="${MAJOR}.${MINOR}.${PATCH}"
fi
VERSION=$(echo ${VERSION} | sed 's#\.$##')
VERSION=$(echo ${VERSION} | sed 's#\.$##') # to heal two .
echo "VERSION: ${VERSION}"
