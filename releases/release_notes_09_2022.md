# About
Welcome :-)

We are thrilled to share with you Confidential Containers (COCO) release X.X.X .

In this document we will take you through the content of this release, installation instructions, deploying workloads and troubleshooting if things go wrong.

# Release notes

## Goals

This release focused on the following:

- **Simplicity** - Using a dedicated Kubernetes operator, the COCO operator, to deploy and configure
- **Stability** - Supporting Continuous Integration (CI) for the key workflows of the release
- **Documentation** - Details instruction of how to deploy and use this release

## Use cases

This release supports the following use cases:

- Creating a sample COCO workload
- Creating a COCO workload using a pre-existing encrypted image
- Creating a COCO workload using a pre-existing encrypted image on hardware with support for Confidential Computing (CC HW)
- Building a new encrypted container image and deploying it as a COCO workload

## Limitations

The following are known limitations of this release:

- Platform support is currently limited, and rapidly changing
  * AMD SEV is tested by the CI (with some limitations regarding attestation, see below)
  * Intel TDX is expected to work, but not currently tested in the CI
  * S390x is not supported by the COCO operator
- Attestation and key brokering support is still under development
  * The disk-based key broker client (KBC) is still the primary method used for development, even if it will never be an acceptable approach in production.
  * Currently, there are two KBS that can be used:
    - simple-kbs:  simple key broker service (KBS) is expected to be merged just prior to release.
    - [Verdictd](https://github.com/inclavare-containers/verdictd): An external project with which Attestation Agent can conduct remote attestation communication and key acquisition via EAA KBC
  * The full-featured generic KBS and the corresponding KBC are still in the development stage.
  * For developers, other KBCs can be experimented with.
- Signature support is in a transitory state, and should be replaced in the next release
  * We currently use skopeo, which requires kernel command-line options in order to do signature verification
  * This is not the option retained for the longer term
- The format of encrypted container images is still subject to change
  * The oci-crypt container image format itself may still change
  * The tools to generate images are not in their final form
  * The image format itself is subject to change in upcoming releases
  * Image repository support for encrypted images is unequal
- COCO currently requires a custom build of `containerd`
  * The COCO operator will deploy the correct version of `containerd` for you
  * Changes are required to delegate `PullImage` to the agent in the virtual machine
  * The required changes are not part of the vanilla `containerd`
  * The final form of the required changes in `containerd` is expected to be different
  * `crio` is not supported
* COCO is not fully integrated with the orchestration ecosystem (Kubernetes, OpenShift)
  * OpenShift is a non-started at the moment due to their dependency on CRIO
  * Existing APIs do not fully support the COCO security and threat model
  * Some commands accessing confidential data, such as `kubectl exec`, may either fail to work, or incorrectly expose information to the host
  * Container image sharing is not possible in this release
  * Container images are downloaded by the guest (with encryption), not  by the host
  * As a result, the same image will be downloaded separately by every pod using it, not shared between pods on the same host.

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

### Use EAA KBC and Verdictd

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

# Experience Trusted Ephemeral Storage for container image and RW layer

Container image in COCO is pulled inside guest VM, it will be save in CC HW protected guest memory by default.
Since memory is an expensive resource, COCO implemented [trusted ephemeral storage](https://github.com/confidential-containers/documentation/issues/39) for container image and RW layer.

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
Before deploy the workload, we can follow this [documentation](https://github.com/kata-containers/kata-containers/blob/CCv0/docs/how-to/how-to-build-and-test-ccv0.md) and use [ccv0.sh](https://github.com/kata-containers/kata-containers/blob/CCv0/docs/how-to/ccv0.sh) to enable COCO console debug(optional, check whether working as expected).

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
* *TBD: describe tools to debug problems, logs etc…* *
