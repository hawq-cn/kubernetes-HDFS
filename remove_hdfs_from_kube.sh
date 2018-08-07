#!/bin/bash

echo "Removing HDFS datanode."
helm del --purge my-hdfs-datanode
echo "Removing HDFS namenode."
helm del --purge my-hdfs-namenode
echo "Removing HDFS config."
helm del --purge my-hdfs-config

echo "Removing tiller-deploy in kube-system namespace."
kubectl -n "kube-system" delete deployment tiller-deploy
echo "Removing helm account."
kubectl delete -f installHelm/helm-account.yaml

# Delete hdfs namenode datanode labels from nodes.
labeled_node_name=`kubectl get nodes --show-labels |grep hdfs-datanode-exclude |grep hdfs-namenode-selector |cut -d ' ' -f1`
if [ "${labeled_node_name}" != "" ]; then
    echo "Removing hdfs labels from node: ${labeled_node_name}"
    kubectl label node ${labeled_node_name} hdfs-namenode-selector-
    kubectl label node ${labeled_node_name} hdfs-datanode-exclude-
fi

# Check if all the labels are deleted.
kubectl get nodes --show-labels |grep hdfs-datanode-exclude >/dev/null
if [ "$?" != "0" ]; then
    echo "Please check below existing labeled nodes for hdfs:"
    kubectl get nodes --show-labels |grep hdfs-datanode-exclude
fi

kubectl get nodes --show-labels |grep hdfs-namenode-selector >/dev/null
if [ "$?" != "0" ]; then
    echo "Please check below existing labeled nodes for hdfs:"
    kubectl get nodes --show-labels |grep hdfs-namenode-selector
fi
