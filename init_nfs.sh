#!/bin/sh
# Deploy NFS server, set up PersistentVolume and
# PersistentVolumeClaim for home directories, and a data
# directory.
source set_config.sh

# Put into main namespace
kubectl create namespace $NAMESPACE

# Set up NFS server
# Complete YaML files with env vars.
export CLUSTER_DISK
envsubst < nfs-configs/nfs_deployment_tpl.yaml | kubectl create -f -

kubectl create -f nfs-configs/nfs_service.yaml

# Wait for pod to start
echo Control-C to stop this loop if it does not return in 30s or so.
while :
do
    sleep 5
    echo 'Checking if pod is running'
    pod_running=$(kubectl get pods -o custom-columns=POD:metadata.name,STATUS:status.phase | grep nfs-server | grep Running)
    if [ -n "$pod_running" ]; then break; fi
done

# Get cluster IP
NFS_IP=$(kubectl get service --namespace $NAMESPACE nfs-server -o yaml | grep "clusterIP:" | awk '//{print $2}')

# Set up PV, PVC for home dirs and data directory.
export NAMESPACE
export NFS_PV_NAME="nfs"
export NFS_DISK_PATH=$HOME_PATH
export NFS_ACCESS_MODE=ReadWriteMany
envsubst < nfs-configs/nfs_pv_pvc_tpl.yaml | kubectl create -f -
export NFS_PV_NAME="nfs-data"
export NFS_DISK_PATH=$DATA_PATH
export NFS_ACCESS_MODE=ReadOnlyMany
envsubst < nfs-configs/nfs_pv_pvc_tpl.yaml | kubectl create -f -

# Wait for pod to start
echo Control-C to stop this loop if it does not return in 30s or so.
while :
do
    sleep 5
    echo 'Checking if pod is running'
    pod_running=$(kubectl get pods -o custom-columns=POD:metadata.name,STATUS:status.phase | grep nfs-server | grep Running)
    if [ -n "$pod_running" ]; then break; fi
done

echo Next run
echo source configure_jhub.sh
