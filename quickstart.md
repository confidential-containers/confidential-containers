# Getting Started

Confidential Containers (CoCo) provides a uniform workflow, trust model, and feature set
across a wide array of platforms and deployment models.

In general, using CoCo involves the following steps:

- Install CoCo using the operator
- Add a runtimeClassName to your pod yaml
- Deploy signed/encrypted container images (optional)
- Setup attestation (optional)

This guide walks through these steps and touches on some platform-specific configurations.
For more advanced features, specific hardware setup, and troubleshooting information,
see the [guides](./guides) directory.

Confidential Containers is still maturing. See [release notes](./releases) for currrent
hardware support and limitations.

# Installation

You can enable Confidential Containers in an existing Kubernetes cluster using the Confidential Containers Operator.
When installation is finished, your cluster will have new runtime classes for different hardware platforms,
including a generic runtime for testing CoCo without confidential hardware support, a runtime using a remote hypervisor
that allows for cloud integration, a runtime for process-based isolation using SGX, as well as runtimes for TDX and SEV.

## Prerequisites

To run the operator you must have an existing Kubernetes cluster that meets the followng requirements.

- Ensure a minimum of 8GB RAM and 4 vCPU for the Kubernetes cluster node
- Only containerd runtime based Kubernetes clusters are supported with the current CoCo release
- The minimum Kubernetes version should be 1.24
- Ensure at least one Kubernetes node in the cluster has the labels `node-role.kubernetes.io/worker=` or `node.kubernetes.io/worker=`. This will assign the worker role to a node in your cluster, making it responsible for running your applications and services. 
- Ensure SELinux is disabled or not enforced (https://github.com/confidential-containers/operator/issues/115)

For more details on the operator, including the custom resources managed by the operator, refer to the operator [docs](https://github.com/confidential-containers/operator).

> **Note** If you need to quickly deploy a single-node test cluster, you can
use the [run-local.sh
script](https://github.com/confidential-containers/operator/blob/main/tests/e2e/run-local.sh)
from the operator test suite, which will setup a single-node cluster on your
machine for testing purpose.
This script requires `ansible-playbook`, which you can install on CentOS/RHEL using
`dnf install ansible-core`, and the Ansible `docker_container` module, which you can
get using `ansible-galaxy collection install community.docker`.

> ****************************************** **Note** You can also use a Kind or Minikube cluster with containerd runtime to try out the CoCo stack
for development purposes.  Make sure to use the `kata-clh` runtime class for your workloads when using Kind or
Minikube, [as QEMU is known to **not** be working with Kind or Minikube](https://github.com/confidential-containers/operator/issues/124).
Also, with the `enclave-cc` runtime class, the cluster must be prepared so that `/opt/confidential-containers`
on the worker nodes is **not** on an overlayfs mount but the path is a `hostPath` mount (see
[a sample configuration](https://github.com/confidential-containers/operator/blob/cf6a4f38114f7c5b71daec6cb666b1b40bcea140/tests/e2e/enclave-cc-kind-config.yaml#L6-L8)) *****************************************************

## Operator Installation

### Deploy the operator

Deploy the operator by running the following command  where `<RELEASE_VERSION>` needs to be substituted
with the desired [release tag](https://github.com/confidential-containers/operator/tags).

```
kubectl apply -k github.com/confidential-containers/operator/config/release?ref=<RELEASE_VERSION>
```

For example, to deploy the `v0.9.0` release run:
```
kubectl apply -k github.com/confidential-containers/operator/config/release?ref=v0.9.0
```

Wait until each pod has the STATUS of Running.

```
kubectl get pods -n confidential-containers-system --watch
```

### Create the custom resource

#### Create custom resource for kata

Creating a custom resource installs the required CC runtime pieces into the cluster node and creates
the `RuntimeClasses`

```
kubectl apply -k github.com/confidential-containers/operator/config/samples/ccruntime/<CCRUNTIME_OVERLAY>?ref=<RELEASE_VERSION>
```

The current present overlays are: `default` and `s390x`

For example, to deploy the `v0.9.0` release for `x86_64`, run:
```
kubectl apply -k github.com/confidential-containers/operator/config/samples/ccruntime/default?ref=v0.9.0
```

And to deploy `v0.9.0` release for `s390x`, run:
```
kubectl apply -k github.com/confidential-containers/operator/config/samples/ccruntime/s390x?ref=v0.9.0
```

Wait until each pod has the STATUS of Running.

```
kubectl get pods -n confidential-containers-system --watch
```

#### Create custom resource for enclave-cc

**Note** For `enclave-cc` certain configuration changes, such as setting the
URI of the KBS, must be made **before** applying the custom resource. 
Please refer to the [guide](./guides/enclave-cc.md#configuring-enclave-cc-custom-resource-to-use-a-different-kbc)
to modify the enclave-cc configuration.

Please see the [enclave-cc guide](./guides/enclave-cc.md) for more information.

`enclave-cc` is a form of Confidential Containers that uses process-based isolation.
`enclave-cc` can be installed with the following custom resources.
```
kubectl apply -k github.com/confidential-containers/operator/config/samples/enclave-cc/sim?ref=<RELEASE_VERSION>
```
or
```
kubectl apply -k github.com/confidential-containers/operator/config/samples/enclave-cc/hw?ref=<RELEASE_VERSION>
```
for the **simulated** SGX mode build or **hardware** SGX mode build, respectively.

### Verify Installation

Check the `RuntimeClasses` that got created.

```
kubectl get runtimeclass
```
Output:
```
NAME            HANDLER         AGE
kata            kata-qemu       9m55s
kata-clh        kata-clh        9m55s
kata-clh-tdx    kata-clh-tdx    9m55s
kata-qemu       kata-qemu       9m55s
kata-qemu-tdx   kata-qemu-tdx   9m55s
kata-qemu-sev   kata-qemu-sev   9m55s
kata-qemu-snp   kata-qemu-snp   9m55s
```

Details on each of the runtime classes:

- *kata* - standard kata runtime using the QEMU hypervisor including all CoCo building blocks for a non CC HW
- *kata-clh* - standard kata runtime using the cloud hypervisor including all CoCo building blocks for a non CC HW
- *kata-clh-tdx* - using the Cloud Hypervisor, with TD-Shim, and support for Intel TDX CC HW
- *kata-qemu* - same as kata
- *kata-qemu-tdx* - using QEMU, with TDVF, and support for Intel TDX CC HW, prepared for using Verdictd and EAA KBC.
- *kata-qemu-sev* - using QEMU, and support for AMD SEV HW
- *kata-qemu-snp* - using QEMU, and support for AMD SNP HW

If you are using `enclave-cc` you should see the following runtime classes.

```
kubectl get runtimeclass
```
Output:
```
NAME            HANDLER         AGE
enclave-cc      enclave-cc      9m55s
```

### Platform Setup

While the operator deploys all the required binaries and artifacts and sets up runtime classes that use them,
certain platforms may require additional configuration to enable confidential computing. For example, a specific 
host kernel or firmware may need to be utilized. The guides section has further instructions on how to apply
individual TEE environments.

# Using CoCo

The CoCo operator environment has been deployed and setup!

Below is a brief summary and description of some of the CoCo use cases:

- **Container Launch with Only Memory Encryption (No Attestation)** - Launch a container with memory encryption 
- **Container Launch with Encrypted Image** - Launch an encrypted container by proving the workload is running 
  in a TEE in order to retrieve the decryption key
- **Container Launch with Image Signature Verification** - Launch a container and verify the authenticity and 
  integrity of an image by proving the workload is running in a TEE
- **Sealed secret** - Implement wrapped kubernetes secrets that are confidential to the workload owner and are
  automatically decrypted by proving the workload is running in a TEE

The CoCo use cases are implemented differently for each TEE, and they are described in each corresponding 
[guide](./guides) section. To get started using CoCo without TEE hardware, follow the Non-TEE guide below:

- [Non-TEE](./guides/non-tee.md)
- [SEV(-ES)](./guides/sev.md)
- [SNP](./guides/snp.md)
- TDX
- SGX
- [Secure Enclave](./guides/enclave-cc.md)
- ...

Additonal CoCo Features

CoCo has full featured support for complete secure cloud virtualized environment. Here are some of the additional 
features it supports:

- **Ephemeral Storage** - temporary storage that is used during the lifecycle of the container but is cleared out 
  when a pod is restarted or finishes its task
- **Authenticated Registries** - secure container registries that require authentication to access and manage container 
  images that ensures that only trusted images are deployed in the Confidential Container
- **Secure Storage** - mechanisms and technologies used to protect data at rest, ensuring that sensitive information 
  remains confidential and tamper-proof
- **Peer Pods** - enables the creation of VMs on any environment without requiring bare metal servers or nested 
  virtualization support






