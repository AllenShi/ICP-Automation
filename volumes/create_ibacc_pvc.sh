#!/bin/bash

usage() { echo "Usage: $0 -s <string> -n <string>" 1>&2; exit 1; }

while getopts ":s:n:" o; do
    case "${o}" in
        s)
            STORAGE_CLASS=${OPTARG}
            ;;
        n)
            TARGET_NS=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${STORAGE_CLASS}" ] || [ -z "${TARGET_NS}" ]; then
    usage
fi

echo "STORAGE_CLASS = ${STORAGE_CLASS}"
echo "TARGET_NS = ${TARGET_NS}"

sed "s/{{ STORAGE_CLASS }}/${STORAGE_CLASS}/g" ibacc-shared-claim.yaml.tpl > ibacc-shared-claim.yaml

kubectl apply -f ibacc-shared-claim.yaml -n $TARGET_NS
