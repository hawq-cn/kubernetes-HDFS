# Installation on Google Kubernetes Engine(GKE)
The original Spark's HDFS plan is based on a raw k8s cluster: 
**it depends on hostPath volume**.

But hostPath volume cannot be used on GKE, so we should use 
GKE [local-SSD](https://cloud.google.com/kubernetes-engine/docs/concepts/local-ssd) instead of it.

## Create a Kubernetes cluster on GKE
Create a k8s cluster on GKE web console and wait some minutes until it is initialized.

Note:
* k8s version: 1.10 (support local-ssd)
* minimum 3 nodes
* **must** with local ssd disk, [refer]( https://cloud.google.com/kubernetes-engine/docs/concepts/local-ssd#create)

## Setup gcloud (terminal) environment
glcoud is the SDK tools which running in terminal

1. install: [refer](https://cloud.google.com/sdk/docs/downloads-interactive)
2. init and login
    ```bash
    gcloud init
    ```
3. setup k8s cluster
    ```bash
    gcloud container clusters get-credentials cluster-hawq --zone us-central1-a --project data-hawq-bj
    ```
4. now your kubectl should point to *cluster-hawq* context, 
    ```bash
    $ kubectl config current-context
    gke_data-hawq-bj_us-central1-a_cluster-hawq
    ```    
5. verify
    ```bash
    $ kubectl get nodes
    NAME                                          STATUS    ROLES     AGE       VERSION
    gke-cluster-hawq-default-pool-0ffe5ac4-5ths   Ready     <none>    1d        v1.10.2-gke.3
    gke-cluster-hawq-default-pool-0ffe5ac4-8lqg   Ready     <none>    1d        v1.10.2-gke.3
    gke-cluster-hawq-default-pool-0ffe5ac4-g6pg   Ready     <none>    1d        v1.10.2-gke.3
    ```

## Install Helm
1. setup account
    ```bash
    kubectl -f installHelm/helm-account.yaml
    ```
2. install helm
    ```bash
    helm init --service-account helm
    ```
3. verify helm
    ```bash
    helm install --name helm-test ./installHelm/samplechart --set service.type=LoadBalancer
    curl {service:port} # should get nginx output
    ```
Note:
* if found privilege issue, use ```helm upgrade``` to fix, [refer](https://github.com/kubernetes/helm/issues/3130)

## Install a basic HDFS server
This section is the same as Spark original instruments (but modified some charts files).
```bash
# add label for scheduler
kubectl label nodes {one node} hdfs-namenode-selector=hdfs-namenode-0
kubectl label nodes {same node} hdfs-datanode-exclude=yes
# install configmap
cd charts
helm install hdfs-config-k8s --name my-hdfs-config --set fullnameOverride=hdfs-config
# install nn
helm install -n my-hdfs-namenode hdfs-simple-namenode-k8s
# install dn
helm install -n my-hdfs-datanode hdfs-datanode-k8s

# wait some minutes for pod running
```

## Verify HDFS
exec in pod and try dfsadmin command:
```bash
$ kubectl exec -it hdfs-namenode-0 /bin/bash

root@gke-cluster-hawq-default-pool-0ffe5ac4-5ths:/# hadoop dfsadmin -report
DEPRECATED: Use of this script to execute hdfs command is deprecated.
Instead use the hdfs command for it.

Configured Capacity: 202482581504 (188.58 GB)
Present Capacity: 193957756928 (180.64 GB)
DFS Remaining: 193957699584 (180.64 GB)
DFS Used: 57344 (56 KB)
DFS Used%: 0.00%
Under replicated blocks: 0
Blocks with corrupt replicas: 0
Missing blocks: 0
Missing blocks (with replication factor 1): 0

-------------------------------------------------
Live datanodes (2):

Name: 10.128.0.8:50010 (gke-cluster-hawq-default-pool-0ffe5ac4-g6pg.c.data-hawq-bj.internal)
Hostname: gke-cluster-hawq-default-pool-0ffe5ac4-g6pg.c.data-hawq-bj.internal
Decommission Status : Normal
Configured Capacity: 101241290752 (94.29 GB)
DFS Used: 28672 (28 KB)
Non DFS Used: 4083929088 (3.80 GB)
DFS Remaining: 97157332992 (90.48 GB)
DFS Used%: 0.00%
DFS Remaining%: 95.97%
Configured Cache Capacity: 0 (0 B)
Cache Used: 0 (0 B)
Cache Remaining: 0 (0 B)
Cache Used%: 100.00%
Cache Remaining%: 0.00%
Xceivers: 1
Last contact: Wed Jun 13 00:38:21 UTC 2018


Name: 10.128.0.10:50010 (gke-cluster-hawq-default-pool-0ffe5ac4-8lqg.c.data-hawq-bj.internal)
Hostname: gke-cluster-hawq-default-pool-0ffe5ac4-8lqg.c.data-hawq-bj.internal
Decommission Status : Normal
Configured Capacity: 101241290752 (94.29 GB)
DFS Used: 28672 (28 KB)
Non DFS Used: 4440895488 (4.14 GB)
DFS Remaining: 96800366592 (90.15 GB)
DFS Used%: 0.00%
DFS Remaining%: 95.61%
Configured Cache Capacity: 0 (0 B)
Cache Used: 0 (0 B)
Cache Remaining: 0 (0 B)
Cache Used%: 100.00%
Cache Remaining%: 0.00%
Xceivers: 1
Last contact: Wed Jun 13 00:38:20 UTC 2018

```

## use HDFS (in pod)
Namenode is a statefulset, so we can use dns name to access it, e.g.
```bash
root@gke-cluster-hawq-default-pool-0ffe5ac4-5ths:/# hdfs dfs -fs hdfs-namenode-0.hdfs-namenode:8020 -ls /
18/06/13 00:40:47 WARN fs.FileSystem: "hdfs-namenode-0.hdfs-namenode:8020" is a deprecated filesystem name. Use "hdfs://hdfs-namenode-0.hdfs-namenode:8020/" instead.
Found 2 items
drwxr-xr-x   - gpadmin gpadmin             0 2018-06-12 09:30 /hawqcluster
drwxr-xr-x   - root    supergroup          0 2018-06-12 09:25 /test
```