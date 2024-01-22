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
- Ensure at least one Kubernetes node in the cluster is having the label `node-role.kubernetes.io/worker=`
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

> **Note** You can also use a Kind or Minikube cluster with containerd runtime to try out the CoCo stack
for development purposes.  Make sure to use the `kata-clh` runtime class for your workloads when using Kind or
Minikube, [as QEMU is known to **not** be working with Kind or Minikube](https://github.com/confidential-containers/operator/issues/124).
Also, with the `enclave-cc` runtime class, the cluster must be prepared so that `/opt/confidential-containers`
on the worker nodes is **not** on an overlayfs mount but the path is a `hostPath` mount (see
[a sample configuration](https://github.com/confidential-containers/operator/blob/cf6a4f38114f7c5b71daec6cb666b1b40bcea140/tests/e2e/enclave-cc-kind-config.yaml#L6-L8))

## Operator Installation

### Deploy the operator

Deploy the operator by running the following command  where `<RELEASE_VERSION>` needs to be substituted
with the desired [release tag](https://github.com/confidential-containers/operator/tags).

```
kubectl apply -k github.com/confidential-containers/operator/config/release?ref=<RELEASE_VERSION>
```

For example, to deploy the `v0.8.0` release run:
```
kubectl apply -k github.com/confidential-containers/operator/config/release?ref=v0.8.0
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

For example, to deploy the `v0.8.0` release for `x86_64`, run:
```
kubectl apply -k github.com/confidential-containers/operator/config/samples/ccruntime/default?ref=v0.8.0
```

And to deploy `v0.8.0` release for `s390x`, run:
```
kubectl apply -k github.com/confidential-containers/operator/config/samples/ccruntime/s390x?ref=v0.8.0
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
kata            kata            9m55s
kata-clh        kata-clh        9m55s
kata-clh-tdx    kata-clh-tdx    9m55s
kata-qemu       kata-qemu       9m55s
kata-qemu-tdx   kata-qemu-tdx   9m55s
kata-qemu-sev   kata-qemu-sev   9m55s
```

Details on each of the runtime classes:

- *kata* - standard kata runtime using the QEMU hypervisor including all CoCo building blocks for a non CC HW
- *kata-clh* - standard kata runtime using the cloud hypervisor including all CoCo building blocks for a non CC HW
- *kata-clh-tdx* - using the Cloud Hypervisor, with TD-Shim, and support for Intel TDX CC HW
- *kata-qemu* - same as kata
- *kata-qemu-tdx* - using QEMU, with TDVF, and support for Intel TDX CC HW, prepared for using Verdictd and EAA KBC.
- *kata-qemu-sev* - using QEMU, and support for AMD SEV HW

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
certain platforms may require additional configuration to enable confidential computing. For example, the host
kernel and firmware might need to be configured.
See the [guides](./guides) for more information.

# Running a workload

## Creating a sample CoCo workload

Once you've used the operator to install Confidential Containers, you can run a pod with CoCo by simply adding a runtime class.
First, we will use the `kata` runtime class which uses CoCo without hardware support.
Initially we will try this with an unencrypted container image.

In our example we will be using the bitnami/nginx image as described in the following yaml:
```
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
  name: nginx
  annotations:
    io.containerd.cri.runtime-handler: kata
spec:
  containers:
  - image: bitnami/nginx:1.22.0
    name: nginx
  dnsPolicy: ClusterFirst
  runtimeClassName: kata
```

Setting the runtimeClassName is usually the only change needed to the pod yaml, but some platforms
support additional annotations for configuring the enclave. See the [guides](./guides) for
more details.

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

## Encrypted and/or signed images with attestation

The previous example does not involve any attestation because the workload container isn't signed or encrypted
and the workload itself does not require any secrets.

This is not the case for most real workloads. It is recommended to use CoCo with signed and/or encrypted images.
The workload itself can also request secrets from the attestation agent in the guest.

Secrets are provisioned to the guest in conjunction with an attestation, which is based on hardware evidence.
The rest of this guide focuses on setting up more substantial encrypted/signed workloads using attestation
and confidential hardware.

See [this guide](./guides/nontee_demo.md) if you would like to deploy an example encrypted image without
confidential hardware.

CoCo has a modular attestation interface and there are a few options for attestation.
CoCo provides a generic Key Broker Service (KBS) that the rest of this guide will be focused on.
The SEV runtime class uses `simple-kbs`, which is described in the [SEV guide](./guides/sev.md).
There is also `eaa_kbc`/`verdictd` which is described [here](./guides/eaa_verdictd.md).

### Select Runtime Class

To use CoCo with confidential hardware, first switch to the appropriate runtime class.
TDX has two runtime classes, `kata-qemu-tdx` and `kata-clh-tdx`. One uses QEMU as VMM and TDVF as firmware. The other uses Cloud Hypervisor as VMM and TD-Shim as firmware.

For SEV(-ES) use the `kata-qemu-sev` runtime class and follow the [SEV guide](./guides/sev.md).

For `enclave-cc` follow the [enclave-cc guide](./guides/enclave-cc.md).

### Deploy and Configure tenant-side CoCo Key Broker System cluster

The following describes how to run and provision the generic KBS.
The KBS should be run in a trusted environment. The KBS is not just one service,
but a combination of several.

A tenant-side CoCo Key Broker System cluster includes:
- Key Broker Service (KBS): Brokering service for confidential resources.
- Attestation Service (AS): Verifier for remote attestation.
- Reference Value Provicer Service (RVPS): Provides reference values for AS.
- CoCo Keyprovider: Component to encrypt the images following ocicrypt spec.

To quick start the KBS cluster, a `docker compose` yaml is provided to launch.

```shell
# Clone KBS git repository
git clone https://github.com/confidential-containers/kbs.git
cd kbs
export KBS_DIR_PATH=$(pwd)

# Generate a user auth key pair
openssl genpkey -algorithm ed25519 > config/private.key
openssl pkey -in config/private.key -pubout -out config/public.pub

# Start KBS cluster
docker compose up -d
```

If configuration of KBS cluster is required, edit the following config files and restart the KBS cluster with `docker compose`:

- `$KBS_DIR_PATH/config/kbs-config.json`: configuration for Key Broker Service.
- `$KBS_DIR_PATH/config/as-config.json`: configuration for Attestation Service.
- `$KBS_DIR_PATH/config/sgx_default_qcnl.conf`: configuration for Intel TDX/SGX verification.

When KBS cluster is running, you can modify the policy file used by AS policy engine ([OPA](https://www.openpolicyagent.org/)) at any time:

- `$KBS_DIR_PATH/data/attestation-service/opa/policy.rego`: Policy file for evidence verification of AS, refer to [AS Policy Engine](https://github.com/confidential-containers/attestation-service#policy-engine) for more infomation.

### Encrypting an Image

[skopeo](https://github.com/containers/skopeo) is required to encrypt the container image.
Follow the [instructions](https://github.com/containers/skopeo/blob/main/install.md) to install `skopeo`.

Use `skopeo` to encrypt an image on the same node of the KBS cluster (use busybox:latest for example):

```shell
# edit ocicrypt.conf
tee > ocicrypt.conf <<EOF
{
    "key-providers": {
        "attestation-agent": {
            "grpc": "127.0.0.1:50000"
        }
    }
}
EOF

# encrypt the image
OCICRYPT_KEYPROVIDER_CONFIG=ocicrypt.conf skopeo copy --insecure-policy --encryption-key provider:attestation-agent docker://library/busybox oci:busybox:encrypted
```

The image will be encrypted, and things happens in the KBS cluster background include:

- CoCo Keyprovider generates a random key and a key-id. Then encrypts the image using the key.
- CoCo Keyprovider registers the key with key-id into KBS.

Then push the image to registry:

```shell
skopeo copy oci:busybox:encrypted [SCHEME]://[REGISTRY_URL]:encrypted
```
Be sure to replace `[SCHEME]` with registry scheme type like `docker`, replace `[REGISTRY_URL]` with the desired registry URL like `docker.io/encrypt_test/busybox`.

### Signing an Image

[cosign](https://github.com/sigstore/cosign) is required to sign the container image. Follow the instructions here to install `cosign`:

[cosign installation](https://docs.sigstore.dev/cosign/installation/)

Generate a cosign key pair and register the public key to KBS storage:

```shell
cosign generate-key-pair
mkdir -p $KBS_DIR_PATH/data/kbs-storage/default/cosign-key && cp cosign.pub $KBS_DIR_PATH/data/kbs-storage/default/cosign-key/1
```

Sign the encrypted image with cosign private key:

```shell
cosign sign --key cosign.key [REGISTRY_URL]:encrypted
```

Be sure to replace `[REGISTRY_URL]` with the desired registry URL of the encrypted image generated in previous steps.

Then edit an image pulling validation policy file.
Here is a sample policy file `security-policy.json`:

```json
{
    "default": [{"type": "reject"}],
    "transports": {
        "docker": {
            "[REGISTRY_URL]": [
                {
                    "type": "sigstoreSigned",
                    "keyPath": "kbs:///default/cosign-key/1"
                }
            ]
        }
    }
}
```

Be sure to replace `[REGISTRY_URL]` with the desired registry URL of the encrypted image.

Register the image pulling validation policy file to KBS storage:

```shell
mkdir -p $KBS_DIR_PATH/data/kbs-storage/default/security-policy
cp security-policy.json $KBS_DIR_PATH/data/kbs-storage/default/security-policy/test
```

### Deploy encrypted image as a CoCo workload on CC HW

Here is a sample yaml for encrypted image deploying:

```shell
cat << EOT | tee encrypted-image-test-busybox.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: encrypted-image-test-busybox
  name: encrypted-image-test-busybox
  annotations:
    io.containerd.cri.runtime-handler: [RUNTIME_CLASS]
spec:
  containers:
  - image: [REGISTRY_URL]:encrypted
    name: busybox
  dnsPolicy: ClusterFirst
  runtimeClassName: [RUNTIME_CLASS]
EOT
```

Be sure to replace `[REGISTRY_URL]` with the desired registry URL of the encrypted image generated in previous step, replace `[RUNTIME_CLASS]` with kata runtime class for CC HW.

Then configure `/opt/confidential-containers/share/defaults/kata-containers/configuration-<RUNTIME_CLASS_SUFFIX>.toml` to add `agent.aa_kbc_params=cc_kbc::<KBS_URI>` to kernal parameters. Here `RUNTIME_CLASS_SUFFIX` is something like `qemu-tdx`, `KBS_URI` is the address of Key Broker Service in KBS cluster like `http://123.123.123.123:8080`.

Deploy encrypted image as a workload:

```shell
kubectl apply -f encrypted-image-test-busybox.yaml
```
