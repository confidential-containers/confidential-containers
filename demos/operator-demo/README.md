<!-- TOC start -->
- [CCv0 Operator Demo](#ccv0-operator-demo)
  * [Demo Video](#demo-video)
  * [Demo Environment setup](#demo-environment-setup)
    + [Kubernetes cluster](#kubernetes-cluster)
    + [Replace containerd ](#replace-containerd)
    + [Verify if the cluster nodes are all up](#verify-if-the-cluster-nodes-are-all-up)
  * [Operator Setup](#operator-setup)
  * [Confidential Containers Runtime setup](#confidential-containers-runtime-setup)
<!-- TOC end -->

# CCv0 Operator Demo

## Demo Video

The demo shows CCv0 Kata runtime installation and configuration using the [operator](https://github.com/confidential-containers/operator).

[Watch the demo in youtube](https://www.youtube.com/watch?v=4cM3IhfnJLQ)


## Demo Environment setup

### Kubernetes cluster

Setup a two nodes Kubernetes cluster using Ubuntu 20.04. 
You can use your preferred Kubernetes setup tool. Here is an example
using [kcli](https://kcli.readthedocs.io/en/latest/)

Download ubuntu 20.04 image if not present
```
kcli download image ubuntu2004
```

Install the cluster
```
kcli create kube generic -P image=ubuntu2004 -P workers=1 testk8s
```

### Replace containerd 

Replace containerd on the worker node by building a new containerd from the following 
branch - https://github.com/confidential-containers/containerd/tree/ali-CCv0

Modify systemd configuration to use the new binary and restart containerd and kubelet

### Verify if the cluster nodes are all up

```
kubectl get nodes
```
Sample output from my demo environment
```
NAME                  STATUS   ROLES                  AGE   VERSION
cck8s-demo-master-0   Ready    control-plane,master   25d   v1.22.3
cck8s-demo-worker-0   Ready    worker                 25d   v1.22.3
```

## Operator Setup

```
kubectl apply -f https://raw.githubusercontent.com/confidential-containers/operator/ccv0-demo/deploy/deploy.yaml
```

The operator installs everything under the `confidential-containers-system` namespace

Verify if the operator is running

```
kubectl get pods -n confidential-containers-system                                                                                                                       
```

Sample output from my demo environment
```
NAME                                              READY   STATUS    RESTARTS   AGE                                                                                              
cc-operator-controller-manager-7f8d6dd988-t9zdm   2/2     Running   0          13s 
```

## Confidential Containers Runtime setup

Creating a `CCruntime` object sets up the container runtime
The default payload image sets up the CCv0 demo image of the kata-containers runtime.

```yaml
cat << EOF | kubectl create -f -
apiVersion: confidentialcontainers.org/v1beta1
kind: CcRuntime
metadata:
  name: ccruntime-sample
  namespace: confidential-containers-system
spec:
  # Add fields here
  runtimeName: kata
  config:
    installType: bundle
    payloadImage: quay.io/confidential-containers/runtime-payload:latest
EOF
```
This will create an install daemonset targeting the worker nodes for installation.
You can verify the status under the `confidential-containers-system` namespace

```
kubectl get pods -n confidential-containers-system
NAME                                              READY   STATUS    RESTARTS   AGE
cc-operator-controller-manager-7f8d6dd988-t9zdm   2/2     Running   0          82s
cc-operator-daemon-install-p9ntc                  1/1     Running   0          45s
```

On successful installation, you'll see the following `runtimeClasses` being setup

```
kubectl get runtimeclasses.node.k8s.io
NAME        HANDLER     AGE
kata        kata        92s
kata-cc     kata-cc     92s
kata-qemu   kata-qemu   92s
```
`kata-cc` runtimeclass uses CCv0 specific configurations. 

Now you can deploy the PODs targeting the specific runtimeclasses.
