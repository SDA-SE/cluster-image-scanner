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
      kubectl get pods -A
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
      kubectl get pods -A
      exit 1
    fi
    echo "waiting for ${name} to be up"
    sleep "${sleep}"
  done
}

export BRANCH=$(git rev-parse --abbrev-ref HEAD)
export MAJOR="2"
export MINOR="0"
export PATCH="${GITHUB_RUN_NUMBER}"
export VERSION="${MAJOR}.${MINOR}.${PATCH}"
if [ "${BRANCH}" != "master" ] && [ "${BRANCH}" != "head" ]; then
  export MAJOR=$(echo ${BRANCH} | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
  export PATCH=""
  if [ "${GITHUB_RUN_NUMBER}" != "" ]; then
    export MAJOR=$(echo ${GITHUB_REF##*/} | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
    export MINOR=".${GITHUB_RUN_NUMBER}"
  else
    export MINOR=""
  fi
  export VERSION="${MAJOR}${MINOR}${PATCH}"
fi

