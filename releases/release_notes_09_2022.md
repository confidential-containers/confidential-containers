# About 
Welcome :-)

We are thrilled to share with you Confidential Containers (COCO) release X.X.X .

In this document we will take you through the content of this release, installation instructions, deploying workloads and troubleshooting if things go wrong. 

# Release notes 

## Goals 

This release focused on the following:

- **Simplicity** - Using the operator to deploy and configure
- **Stability** - Supporting CI for the key workflows of the release
- **Documentation** - Details instruction of how to deploy and use this release

## Use cases 

This release supports the following use cases:

- Creating a sample COCO workload
- Creating a COCO workload using a pre-existing encrypted image
- Creating a COCO workload using a pre-existing encrypted image on CC HW
- Building a new encrypted container image and deploying it as a COCO workload

## Limitations 

The following are known limitations of this release: 

- A
- B
- C

# Installing 

The COCO solution can be installed, uninstalled and configured using the COCO operator. 

* *TBD: we will move the below sections to the operator documentation and only refer to that link
Installing the operator* * 

Follow the steps described in https://github.com/confidential-containers/operator/blob/main/docs/INSTALL.md

Assuming the operator was installed successfully you can move on to creating a workload (**the following section is optional**). 

## Details on the CC operator installation

A few points to mention if your interested in the details: 

### Deploy the the operator:

```
kubectl apply -f https://raw.githubusercontent.com/confidential-containers/operator/main/deploy/deploy.yaml
```

You may get the following error when deploying the operator: 

```
Error from server (Timeout): error when creating "https://raw.githubusercontent.com/confidential-containers/operator/main/deploy/deploy.yaml": Timeout: request did not complete within requested timeout - context deadline exceeded
```

This is a timeout on the `kubectl` side and simply run the command again which will solve the problem.

After you deployed the operator and before you create the custom resource run the following command and observer the expected output (STATUS is ready):
```
kubectl get pods -n confidential-containers-system
```
Output: 
```
NAME                                              READY   STATUS    RESTARTS   AGE
cc-operator-controller-manager-5df7584679-kffzf   2/2     Running   0          4m35s
```

### Deploying the operator vs a custom resource

The operator is responsible for creating the custom resource definition (CRD) which we can then use for creating a custom resource (CR).

In our case the operator has created the ccruntime CRD as can be observed in the following command:
```
kubectl get crd | grep ccruntime
```
Output: 
```
ccruntimes.confidentialcontainers.org   2022-09-08T06:10:37Z
```

The following command provides the details on the CcRuntime CRD:

```
kubectl explain ccruntimes.confidentialcontainers.org
```
Output: 
```
KIND:     CcRuntime
VERSION:  confidentialcontainers.org/v1beta1
 
DESCRIPTION:
     CcRuntime is the Schema for the ccruntimes API
 
FIELDS:
   apiVersion	<string>
     APIVersion defines the versioned schema of this representation of an
     object. Servers should convert recognized schemas to the latest internal
     value, and may reject unrecognized values. More info:
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
 
   kind	<string>
     Kind is a string value representing the REST resource this object
     represents. Servers may infer this from the endpoint the client submits
     requests to. Cannot be updated. In CamelCase. More info:
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
 
   metadata	<Object>
     Standard object's metadata. More info:
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
 
   spec	<Object>
     CcRuntimeSpec defines the desired state of CcRuntime
 
   status	<Object>
     CcRuntimeStatus defines the observed state of CcRuntime
 ```


The complete CRD can be seen by running the following command:

```
kubectl explain --recursive=true ccruntimes.confidentialcontainers.org
```

You can also see the details of the CcRuntime CRD in the following .go file: https://github.com/confidential-containers/operator/blob/main/api/v1beta1/ccruntime_types.go#L90

Create the custom resource:

```
kubectl apply  -f https://raw.githubusercontent.com/confidential-containers/operator/main/config/samples/ccruntime.yaml
```

Check that the ccruntime was created successfully: 
```
kubectl get ccruntimes
```
Output: 
``` 
NAME               AGE
ccruntime-sample   5s
```

Use the following command to observe the details of the CR yaml::
```
kubectl get ccruntimes ccruntime-sample -o yaml | less
```

Note that we are using  runtimeName: kataataame: kata

If we were use enclave-cc for example we would observe that runtimeName: enclave-cc

Once we also create the custom resource the validation will show us 2 additional pods created:
```
kubectl get pods -n confidential-containers-system
```
Output: 
```
NAME                                              READY   STATUS    RESTARTS   AGE
cc-operator-controller-manager-5df7584679-kffzf   2/2     Running   0          21m
cc-operator-daemon-install-xz697                  1/1     Running   0          6m45s
cc-operator-pre-install-daemon-rtdls              1/1     Running   0          7m2s
```

Once the CR was created you will notice we have multiple runtime classes:
```
kubectl get runtimeclass
```
Output: 
```
NAME            HANDLER         AGE
kata            kata            9m55s
kata-clh        kata-clh        9m55s
kata-clh-tdx    kata-clh-tdx    9m55s
kata-qemu       kata-qemu       9m55s
kata-qemu-tdx   kata-qemu-tdx   9m55s
```

Details on each of the runtime classes:

-- kata - standard kata runtime using the QEMU hypervisor including all COCO building blocks for a non CC HW
-- kata-clh - standard kata runtime using the cloud hypervisor including all COCO building blocks for a non CC HW
-- kata-clh-tdx - using the Cloud Hypervisor, with TD-Shim, and support for Intel TDX CC HW
-- kata-qemu - same as kata
-- kata-qemu-tdx - using QEMU, with TDVF, and support for Intel TDX CC HW
-- * *TBD: we need to add the SEV runtimes as well* *


# Post installation configuration 
* *TBD:...* *

# Creating a workload 
## Creating a sample COCO workload 

The first workload we create will show how the COCO building blocks work together without encryption or CC HW support (which will be demonstrated in later workloads). 

A key point when working on COCO is to ensure that the container images get downloaded inside the VM and not on the host.

In our example we will be using the bitnami/nginx image as described in the following yaml:
```
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
  name: nginx
spec:
  containers:
  - image: bitnami/nginx:1.22.0
    name: nginx
  dnsPolicy: ClusterFirst
  runtimeClassName: kata
```

For verifying that the container image doesn’t exist on the host you should log into the k8s node and ensure the following command returns an empty result:
```
root@cluster01-master-0:/home/ubuntu# crictl  -r  unix:///run/containerd/containerd.sock image ls | grep bitnami/nginx
```

Create a pod YAML file as previously described (we named it `nginx.yaml`) .

Create the workload: 
```
kubectl apply -f nginx.yaml
```
Output: 
```
pod/nginx created
```

Ensure the pod was created successfully (in running state):
```
kubectl get pods        
```
Output: 
```
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          3m50s
```

Now go back to the k8s node and ensure that you still don’t have any bitnami/nginx images on it:
```
root@cluster01-master-0:/home/ubuntu# crictl  -r  unix:///run/containerd/containerd.sock image ls | grep bitnami/nginx
```

## Creating a COCO workload using a pre-existing encrypted image

We will now proceed to download and run an encrypted container image using the COCO building blocks. 

* *TBD: based on https://github.com/confidential-containers/operator/issues/77* *


## Creating a COCO workload using a pre-existing encrypted image on CC HW

For running one of the sample workloads provided in the previous step, but now taking advantage of a specific TEE vendor, the user will have to set the runtime class of the workload accordingly in the workload yaml file.

In case the user wants to run the workload on a TDX capable hardware, using QEMU (which uses TDVF as its firmware) the `kata-qemu-tdx` runtime class must be specified.  In case the user prefers using Cloud Hypervisor (which uses TD-Shim as its firmware) then the `kata-clh-tdx` runtime class must be specified.

* *TBD: do we have enough details on TDX and SEV-ES to write this section* *

## Building a new encrypted container image and deploying it as a COCO workload

* *TBD: instructions to build encrypted container image and other requirements (attestation, key etc)* *

# Debugging problems 
* *TBD: describe tools to debug problems, logs etc…* *


