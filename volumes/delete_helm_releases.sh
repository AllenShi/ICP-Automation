#!/bin/bash

TARGET_NS=dbamc-icp-space
EXCLUSION_RELEASE=ibm-dba-multicloud-prod
if [[ -z EXCLUSION_RELEASE ]]; then
  while read i ; do
    echo $i
    helm delete --purge $i --tls
  done < <(helm list --namespace ${TARGET_NS} --tls | tail -n +2)
else
  while read i ; do
    echo $i
    helm delete --purge $i --tls
  done < <(helm list --namespace ${TARGET_NS} --tls | tail -n +2 | grep -v ${EXCLUSION_RELEASE})
fi
