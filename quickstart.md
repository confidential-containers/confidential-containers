# Getting Started
This document contains an overview of Confidential Containers use cases and support
as well as a guide for installing Confidential Containers, deploying workloads,
and troubleshooting if things go wrong.

## Use cases

Confidential Containers (CoCo) supports the following use cases:

- Running unencrypted containers without Confidential Computing (CC) hardware
- Running encrypted containers without CC HW (sample container images provided)
- Running unencrypted container images or sample encrypted images with CC HW
- Running your own encrypted container images with CC HW

The first two cases are mainly for testing and development or new users who want to
explore the project. This guide explains all four cases below.

## Hardware Support
Confidential Containers is tested with attestation on the following platforms:
- Intel TDX
- AMD SEV

Confidential Containers can also be run on Linux without any Confidential Computing hardware
for testing or development.

The following platforms are untested or partially supported:
- AMD SEV-ES
- IBM Z SE

The following platforms are in development:
- Intel SGX
- AMD SEV-SNP

## Limitations

Confidential Containers is still maturing. See [release notes](./releases) for currrent limitations.

# Installing

You can enable Confidential Containers in an existing Kubernetes cluster using the Confidential Containers Operator.

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
kata-qemu-sev   kata-qemu-sev   9m55s
```

Details on each of the runtime classes:

-- kata - standard kata runtime using the QEMU hypervisor including all CoCo building blocks for a non CC HW
-- kata-clh - standard kata runtime using the cloud hypervisor including all CoCo building blocks for a non CC HW
-- kata-clh-tdx - using the Cloud Hypervisor, with TD-Shim, and support for Intel TDX CC HW
-- kata-qemu - same as kata
-- kata-qemu-tdx - using QEMU, with TDVF, and support for Intel TDX CC HW
-- * *TBD: we need to add the SEV runtimes as well* *

# Running a workload
## Creating a sample CoCo workload

Once you've used the operator to install Confidential Containers, you can run a pod with CoCo by simply adding a runtime class.
First, we will use the `kata` runtime class which uses CoCo wihout hardware support.
Initially we will try this with an unencrypted container image.

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

With Confidential Containers, the workload container images are never downloaded on the host.
For verifying that the container image doesn’t exist on the host you should log into the k8s node and ensure the following command returns an empty result:
```
root@cluster01-master-0:/home/ubuntu# crictl  -r  unix:///run/containerd/containerd.sock image ls | grep bitnami/nginx
```
You will run this command again after the container has started.

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

## Creating a CoCo workload using a pre-existing encrypted image

We will now proceed to download and run an encrypted container image using the CoCo building blocks.

* *TBD: based on https://github.com/confidential-containers/operator/issues/77* *

Change the yaml to point to the sample container image
The keys for this image should be in the rootfs


## Creating a CoCo workload using a pre-existing encrypted image on CC HW

For running one of the sample workloads provided in the previous step, but now taking advantage of a specific TEE vendor,
the user will have to set the runtime class of the workload accordingly in the workload yaml file.

### TDX
In case the user wants to run the workload on a TDX capable hardware, using QEMU (which uses TDVF as its firmware) the `kata-qemu-tdx` runtime class must be specified.  In case the user prefers using Cloud Hypervisor (which uses TD-Shim as its firmware) then the `kata-clh-tdx` runtime class must be specified.

### SEV

`kata-qemu-sev`
Export cert chain
Start KBS (even for unencrypted)

Use the sample image or an unencrypted image


## Building a new encrypted container image and deploying it as a CoCo workload

* *TBD: instructions to build encrypted container image and other requirements (attestation, key etc)* *

### Use EAA KBC and Verdictd (TDX)

EAA is used to perform attestation at runtime and provide guest with confidential resources such as keys.
It is based on [rats-tls](https://github.com/inclavare-containers/rats-tls).

[Verdictd](https://github.com/inclavare-containers/verdictd) is the Key Broker Service and Attestation Service of EAA.
The EAA KBC is an optional module in the attestation-agent at compile time,
which can be used to communicate with Verdictd.
The communication is established on the encrypted channel provided by rats-tls.

EAA can now be used on intel TDX and intel SGX platforms.

#### Create encrypted image

Before build encrypted image, you need to make sure Skopeo and Verdictd(EAA KBS) have been installed:
- [Skopeo](https://github.com/containers/skopeo): the command line utility to perform encryption operations.
- [Verdictd](https://github.com/inclavare-containers/verdictd): EAA Key Broker Service and Attestation Service.

1. Pull unencrypted image.

Here use `alpine:latest` for example:

```sh
${SKOPEO_HOME}/bin/skopeo copy --insecure-policy　docker://docker.io/library/alpine:latest oci:busybox
```

2. Follow the [Verdictd README #Generate encrypted container image](https://github.com/inclavare-containers/verdictd#generate-encrypted-container-image) to encrypt the image.

3. Publish the encrypted image to your registry.

#### Deploy encrypted image

1. Build rootfs with EAA component:

Specify `AA_KBC=eaa_kbc` parameters when using kata-containers `rootfs.sh` scripts to create rootfs.

2. Launch Verdictd

Verdictd performs remote attestation at runtime and provides the key needed to decrypt the image.
It is actually both Key Broker Service and Attestation Service of EAA.
So when deploy the encrypted image, Verdictd is needed to be launched:

```sh
verdictd --listen <$ip>:<$port> --mutual
```

**Note:** The communication between Verdictd and EAA KBC is based on rats-tls,
so you need to confirm that [rats-tls](https://github.com/inclavare-containers/rats-tls) has been correctly installed in your running environment.

3. Agent Configuration

Add configuration `aa_kbc_params= 'eaa_kbc::<$IP>:<$PORT>'` to agent config file, the IP and PORT should be consistent with verdictd.

### Use offline SEV KBC and simple-kbs (SEV)

TODO: add instructions for simple-kbs with encrypted images

# Trusted Ephemeral Storage for container images

With CoCo, container images are pulled inside the guest VM.
By default container images are saved in guest memory which is protected by CC hardware.
Since memory is an expensive resource, CoCo implemented [trusted ephemeral storage](https://github.com/confidential-containers/documentation/issues/39) for container image and RW layer.

This solution is verified with Kubernetes CSI driver [open-local](https://github.com/alibaba/open-local). Please follow this [user guide](https://github.com/alibaba/open-local/blob/main/docs/user-guide/user-guide.md) to install open-local.

We can use following example `trusted_store_cc.yaml` to have a try:
```
apiVersion: v1
kind: Pod
metadata:
  name: trusted-lvm-block
spec:
  runtimeClassName: kata-qemu-tdx
  containers:
   - name: sidecar-trusted-store
     image: pause
     volumeDevices:
     - devicePath: "/dev/trusted_store"
       name: trusted-store
   - name: application
     image: busybox
     command:
     - sh
     - "-c"
     - |
         sleep 10000
  volumes:
   - name: trusted-store
     persistentVolumeClaim:
       claimName: trusted-store-block-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: trusted-store-block-pvc
spec:
  volumeMode: Block
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: open-local-lvm
```
Before deploy the workload, we can follow this [documentation](https://github.com/kata-containers/kata-containers/blob/CCv0/docs/how-to/how-to-build-and-test-ccv0.md) and use [ccv0.sh](https://github.com/kata-containers/kata-containers/blob/CCv0/docs/how-to/ccv0.sh) to enable CoCo console debug(optional, check whether working as expected).

Create the workload:
```
kubectl apply -f trusted_store_cc.yaml
```

Ensure the pod was created successfully (in running state):
```
kubectl get pods
```

Output:
```
NAME                READY   STATUS    RESTARTS   AGE
trusted-lvm-block   2/2     Running   0          31s
```

After we enable the debug option, we can login into the VM with `ccv0.sh` script:
```
./ccv0.sh -d open_kata_shell
```

Check container image is saved in encrypted storage with following commands:
```
root@localhost:/# lsblk --fs
NAME                             FSTYPE LABEL UUID FSAVAIL FSUSE% MOUNTPOINT
sda
└─ephemeral_image_encrypted_disk                      906M     0% /run/image

root@localhost:/# cryptsetup status ephemeral_image_encrypted_disk
/dev/mapper/ephemeral_image_encrypted_disk is active and is in use.
  type:    LUKS2
  cipher:  aes-xts-plain64
  keysize: 512 bits
  key location: dm-crypt
  device:  /dev/sda
  sector size:  4096
  offset:  32768 sectors
  size:    2064384 sectors
  mode:    read/write

root@localhost:/# mount|grep image
/dev/mapper/ephemeral_image_encrypted_disk on /run/image type ext4 (rw,relatime)

root@localhost:/# ls /run/image/
layers  lost+found  overlay
```

# Debugging problems

Enable kata debug (this will change the measurement)
Has the guest booted or not?
TODO: finish this
