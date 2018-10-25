#!/bin/bash

GLUSTERFS_VOL_PREFIX=icp
TARGET_NS=dbamc-icp-space
GLUSTERFS_NS=kube-system
CUID=501
CGID=500

rm -rf delete-glusterfs-vol.sh

VOL_PREFIXES=()
for i in $(kubectl get pvc -n ${TARGET_NS} | awk '{print $1}' | tail -n +2); do
  echo ${GLUSTERFS_VOL_PREFIX}_${TARGET_NS}_$i
  VOL_PREFIXES+=(${GLUSTERFS_VOL_PREFIX}_${TARGET_NS}_$i)
done

GLUSTERFS_VOL_LIST=$(kubectl exec -it $(kubectl get pod -n ${GLUSTERFS_NS} | grep glusterfs-daemonset | awk '{print $1}' | head -n 1) -n ${GLUSTERFS_NS} gluster volume list)
for v in  ${GLUSTERFS_VOL_LIST[@]}; do
  echo "v is $v"

  for vt in "${VOL_PREFIXES[@]}"; do 
    echo "vt is $vt"
    if [[ $v == $vt* ]]; then
      echo "match $vt"

      echo "gluster volume set $v storage.owner-uid ${CUID}" >> delete-glusterfs-vol.sh
      echo "gluster volume set $v storage.owner-uid ${CGID}" >> delete-glusterfs-vol.sh

      break
    fi
  done
done

chmod +x delete-glusterfs-vol.sh
kubectl cp delete-glusterfs-vol.sh $(kubectl get pod -n ${GLUSTERFS_NS} | grep glusterfs-daemonset | awk '{print $1}' | head -n 1):/tmp/ -n ${GLUSTERFS_NS} 
kubectl exec -it $(kubectl get pod -n ${GLUSTERFS_NS} | grep glusterfs-daemonset | awk '{print $1}' | head -n 1) -n ${GLUSTERFS_NS} -- bash /tmp/delete-glusterfs-vol.sh
