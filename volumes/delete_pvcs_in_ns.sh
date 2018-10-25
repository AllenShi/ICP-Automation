#!/bin/bash

usage() { echo "Usage: $0 -n <string>" 1>&2; exit 1; }

while getopts ":s:n:" o; do
    case "${o}" in
        n)
            TARGET_NS=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${TARGET_NS}" ]; then
    usage
fi

echo "TARGET_NS = ${TARGET_NS}"

for i in $(kubectl get pvc -n ${TARGET_NS} | awk '{print $1}' | tail -n +2); do
  echo "The PVC to be deleted is $i"
  kubectl delete pvc $i -n ${TARGET_NS}
done
