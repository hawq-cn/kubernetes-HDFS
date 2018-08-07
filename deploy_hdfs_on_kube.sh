#!/bin/bash

echo "Creating service account for helm."
kubectl create -f installHelm/helm-account.yaml
helm init --service-account helm

# Get Kubernetes node list
k8s_node_list=`kubectl get nodes |grep '^vm-' |cut -d ' ' -f1`
echo "Kubernetes node list is: $k8s_node_list"
echo "$k8s_node_list"
name_node=`echo $k8s_node_list | cut -d ' ' -f1`
echo "Selected $name_node as HDFS name node."

kubectl label nodes $name_node hdfs-namenode-selector=hdfs-namenode-0
kubectl label nodes $name_node hdfs-datanode-exclude=yes

# install configmap
cd charts
helm install hdfs-config-k8s --name my-hdfs-config --set fullnameOverride=hdfs-config
# install nn
echo "Deploying HDFS namenode."
helm install -n my-hdfs-namenode hdfs-simple-namenode-k8s
# install dn
echo "Deploying HDFS datanodes."
helm install -n my-hdfs-datanode hdfs-datanode-k8s

sleep 20
echo "HDFS deploy finished, please wait couple seconds for service startup..."
echo "You can check hdfs status by:"
echo "> kubectl exec -it hdfs-namenode-0 'hadoop dfsadmin -report'"
echo "> kubectl exec -it hdfs-namenode-0 'hdfs dfs -fs hdfs-namenode-0.hdfs-namenode:8020 -ls /'"
