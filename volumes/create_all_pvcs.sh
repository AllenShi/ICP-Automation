#!/bin/bash


./create_content_pvcs.sh -s glusterfs-dev -n dbamc-icp-space

./create_ibacc_pvc.sh -s glusterfs-dev -n dbamc-icp-space

./create_bai_pvcs.sh -s glusterfs-dev -n dbamc-icp-space

./set_glusterfs_vol_owership.sh
