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

## Hardware Support and Limitations

Confidential Containers is still maturing. See [release notes](./releases) for currrent 
hardware support and limitations.

# Installing

You can enable Confidential Containers in an existing Kubernetes cluster using the Confidential Containers Operator.

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

## Prerequisites

- Ensure a minimum of 8GB RAM and 2 vCPU for the Kubernetes cluster node
- Only containerd runtime based Kubernetes clusters are supported with the current CoCo release
- The minimum Kubernetes version should be 1.24
- Ensure at least one Kubernetes node in the cluster is having the label `node-role.kubernetes.io/worker=`


For more details on the operator, including the custom resources managed by the operator, refer to the operator [docs](https://github.com/confidential-containers/operator).

## Operator Installation

### Deploy the the operator

Deploy the operator by running the following command  where `<RELEASE_VERSION>` needs to be substituted
with the desired [release tag](https://github.com/confidential-containers/operator/tags).

```
kubectl apply -k github.com/confidential-containers/operator/config/release?ref=<RELEASE_VERSION>
```

For example, to deploy the `v0.2.0` release run:
```
kubectl apply -k github.com/confidential-containers/operator/config/release?ref=v0.2.0
```

Wait until each pod has the STATUS of Running.

```
kubectl get pods -n confidential-containers-system --watch
```

### Create the custom resource

Creating a custom resource installs the required CC runtime pieces into the cluster node and creates
the `RuntimeClasses`

```
kubectl apply  -f https://raw.githubusercontent.com/confidential-containers/operator/main/config/samples/ccruntime.yaml
```

Wait until each pod has the STATUS of Running.

```
kubectl get pods -n confidential-containers-system --watch
```

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
- *kata-qemu-tdx* - using QEMU, with TDVF, and support for Intel TDX CC HW
- *kata-qemu-sev* - using QEMU, and support for AMD SEV HW

For the process based CoCo TEE (aka. `enclave-cc`) the operator setup steps are the same but instead
of `ccruntime.yaml`, either `ccruntime-enclave-cc-sim.yaml` or `ccruntime-enclave-cc.yaml` for the
**simulated** SGX mode build or **hardware** SGX mode build, respectively, should be used.

These result in a `RuntimeClass` as follows:

```
kubectl get runtimeclass
```
Output:
```
NAME            HANDLER         AGE
enclave-cc      enclave-cc      9m55s
```

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

## Creating a sample Coco workload using enclave-cc

Following the previous example that used the `kata` runtime class, we setup a sample *hello world*
workload with an encrypted and cosign signed image using the `enclave-cc` runtime class.
For the process based CoCo TEE (aka. `enclave-cc`) the operator setup steps are the same and the custom resources
can be deployed using either
```
kubectl apply -k github.com/confidential-containers/operator/config/samples/enclave-cc/sim?ref=<RELEASE_VERSION>
```
or
```
kubectl apply -k github.com/confidential-containers/operator/config/samples/enclave-cc/hw?ref=
```
for the **simulated** SGX mode build or **hardware** SGX mode build, respectively.

The example uses a trivial hello world C application:
```
apiVersion: v1
kind: Pod
metadata:
  name: enclave-cc-pod
spec:
  containers:
  - image: docker.io/eqmcc/helloworld_enc
    name: hello-world
    workingDir: "/run/rune/boot_instance/"
    resources:
      limits:
        sgx.intel.com/epc: 600Mi
    env:
    - name: OCCLUM_RELEASE_ENCLAVE
      value: "1"
    command:
    - /run/rune/boot_instance/build/bin/occlum-run
    - /bin/hello_world
  runtimeClassName: enclave-cc

```

**Note** When the hardware SGX mode payload is used in an SGX enabled cluster, `sgx.intel.com/epc: 600Mi`
resource request must be added to the pod spec.

Again, create a pod YAML file as previously described (this time we named it `enclave-cc-pod.yaml`) .

Create the workload:
```
kubectl apply -f enclave-cc-pod.yaml
```
Output:
```
pod/enclave-cc-pod created
```

Ensure the pod was created successfully (in running state):
```
kubectl get pods
```
Output:
```
NAME                 READY   STATUS    RESTARTS   AGE
enclave-cc-pod   1/1     Running   0          22s
```

Check the pod is running as expected:
```
kubectl logs enclave-cc-pod | head -5
```
Output:
```
["init"]
Hello world!

Hello world!

```

We can also verify the host does not have the image for others to use:
```
crictl -r unix:///run/containerd/containerd.sock image ls | grep helloworld_enc
```

## Creating a CoCo workload using a pre-existing encrypted image

We will now proceed to download and run a sample encrypted container image using the CoCo building blocks.

A demo container image is provided at [docker.io/katadocker/ccv0-ssh](https://hub.docker.com/r/katadocker/ccv0-ssh).
It is encrypted with [Attestation Agent](https://github.com/confidential-containers/attestation-agent)'s [offline file system key broker](https://github.com/confidential-containers/attestation-agent/tree/64c12fbecfe90ba974d5fe4896bf997308df298d/src/kbc_modules/offline_fs_kbc) and [`aa-offline_fs_kbc-keys.json`](https://github.com/confidential-containers/documentation/blob/main/demos/ssh-demo/aa-offline_fs_kbc-keys.json) as its key file.

We have prepared a sample CoCo operator custom resource that is based on the standard `ccruntime.yaml`, but in addition has the the decryption keys and configuration required to decrypt this sample container image.
> **Note** All pods started with this sample resource will be able to decrypt the sample container and all keys shown are for demo purposes only and should not be used in production.

 To test out creating a workload from the sample encrypted container image, we can take the following steps:

### Swap out the standard custom resource for our sample

Support for multiple custom resources in not available in the current release. Consequently, if a custom resource already exists, then you'll need to remove it first before deploying a new one. We can remove the standard custom resource with:
```
kubectl delete -f https://raw.githubusercontent.com/confidential-containers/operator/main/config/samples/ccruntime.yaml
```
and in it's place install the modified version with the sample container's decryption key:
```
kubectl apply -f https://raw.githubusercontent.com/confidential-containers/operator/main/config/samples/ccruntime-ssh-demo.yaml
```
Wait until each pod has the STATUS of Running.
```
kubectl get pods -n confidential-containers-system --watch
```
### Test creating a workload from the sample encrypted image

Create a new Kubernetes deployment that uses the `docker.io/katadocker/ccv0-ssh` container image with:
```
cat << EOF > ccv0-ssh-demo.yaml
kind: Service
apiVersion: v1
metadata:
  name: ccv0-ssh
spec:
  selector:
    app: ccv0-ssh
  ports:
  - port: 22
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: ccv0-ssh
spec:
  selector:
    matchLabels:
      app: ccv0-ssh
  template:
    metadata:
      labels:
        app: ccv0-ssh
    spec:
      runtimeClassName: kata
      containers:
      - name: ccv0-ssh
        image: docker.io/katadocker/ccv0-ssh
        imagePullPolicy: Always
EOF
```

Apply this with:
```
kubectl apply -f ccv0-ssh-demo.yaml
```
and waiting for the pod to start. This process should show that we are able to pull the encrypted image and using the decryption key configured in the CoCo sample guest image decrypt the container image and create a workload using it.

The demo image has an SSH host key embedded in it, which is protected by it's encryption, but we can download the sample private key and use this to ssh into the container and validate the host key to ensure that it hasn't been tampered with.

Download the SSH key with:
```
curl -Lo ccv0-ssh https://raw.githubusercontent.com/confidential-containers/documentation/main/demos/ssh-demo/ccv0-ssh
```
Ensure that the permissions are set correctly with:
```
chmod 600 ccv0-ssh
```

We can then use the key to ssh into the container:
```
$ ssh -i ccv0-ssh root@$(kubectl get service ccv0-ssh -o jsonpath="{.spec.clusterIP}")
```
You will be prompted about whether the host key fingerprint is correct. This fingerprint should match the one specified in the container image: `wK7uOpqpYQczcgV00fGCh+X97sJL3f6G1Ku4rvlwtR0.`

## Creating a CoCo workload using a pre-existing encrypted image on CC HW

For running one of the sample workloads provided in the previous step, but now taking advantage of a specific TEE vendor,
the user will have to set the runtime class of the workload accordingly in the workload yaml file.

### TDX
In case the user wants to run the workload on a TDX capable hardware, using QEMU (which uses TDVF as its firmware) the `kata-qemu-tdx` runtime class must be specified.  In case the user prefers using Cloud Hypervisor (which uses TD-Shim as its firmware) then the `kata-clh-tdx` runtime class must be specified.

### SEV

#### Platform Setup

To enable SEV on the host platform, first ensure that it is supported. Then follow these instructions to enable SEV:

[AMD SEV - Prepare Host OS](https://github.com/AMDESE/AMDSEV#prepare-host-os)

#### Install sevctl and Export SEV Certificate Chain

[sevctl](https://github.com/enarx/sevctl) is the SEV command line utility and is needed to export the SEV certificate chain.

Follow these steps to install `sevctl`:

* Debian / Ubuntu:

  ```
  # Rust must be installed to build
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source $HOME/.cargo/env
  sudo apt install -y musl-dev musl-tools

  # Additional packages are required to build
  sudo apt install -y pkg-config libssl-dev

  # Clone the repository
  git clone https://github.com/virtee/sevctl.git

  # Build
  (cd sevctl && cargo build)
  ```

* CentOS / Fedora / RHEL:

  ```
  sudo dnf install sevctl
  ```

If using the SEV kata configuration template file, the SEV certificate chain must be placed in `/opt/sev`. Export the SEV certificate chain using the following commands:

```
sudo mkdir -p /opt/sev
sudo ./sevctl/target/debug/sevctl export --full /opt/sev/cert_chain.cert
```

#### Setup and Run the simple-kbs

The [simple-kbs](https://github.com/confidential-containers/simple-kbs) is a basic key broker service that hosts secret storage and provides secret release policies configurable by container workload creators or users.

The `simple-kbs` is a prototype implementation under development and is not intended for production use at this time.

For the SEV encrypted image use case, it is required to host the key used to encrypt the container image from the `simple-kbs`.

The CoCo project has created a sample encrypted container image ([encrypted-image-tests](quay.io/kata-containers/encrypted-image-tests:encrypted)). This image is encrypted using a key that comes already provisioned inside the `simple-kbs` for ease of testing. No `simple-kbs` policy is required to get things running.

The image encryption key and key for SSH access have been attached to the CoCo sample encrypted container image as docker labels. This image is meant for TEST purposes only as these keys are published publicly. In a production use case, these keys would be generated by the workload administrator and kept secret. For further details, see the section how to [Create an Encrypted Image](#create-an-encrypted-image).

To learn more about creating custom policies, see the section on [Creating a simple-kbs Policy to Verify the SEV Firmware Measurement](#creating-a-simple-kbs-policy-to-verify-the-sev-firmware-measurement).

A KBS is not required to run unencrypted containers.
Instead, disable pre-attestation by editing the Kata config file located at `/opt/confidential-containers/share/defaults/kata-containers/configuration-qemu-sev.toml`.
```
guest_pre_attestation = false
```
Image decryption and signature validation will not work if pre-attestation is disabled.

> **Note** It is not recommended to edit the Kata configuration file manually.
These changes might be overwritten by the operator.


`docker-compose` is required to run the `simple-kbs` and its database in docker containers:

* Debian / Ubuntu:

  ```
  sudo apt install docker-compose
  ```

* CentOS / Fedora / RHEL:

  ```
  sudo dnf install docker-compose-plugin
  ```

Clone the repository for specified tag:
```
simple_kbs_tag="0.1.1"
git clone https://github.com/confidential-containers/simple-kbs.git
(cd simple-kbs && git checkout -b "branch_${simple_kbs_tag}" "${simple_kbs_tag}")
```

Run the service with `docker-compose`:

* Debian / Ubuntu:

  ```
  (cd simple-kbs && sudo docker-compose up -d)
  ```

* CentOS / Fedora / RHEL:

  ```
  (cd simple-kbs && sudo docker compose up -d)
  ```

#### Launch the Pod and Verify SEV Encryption

Here is a sample kubernetes service yaml for an encrypted image:

```
kind: Service
apiVersion: v1
metadata:
  name: encrypted-image-tests
spec:
  selector:
    app: encrypted-image-tests
  ports:
  - port: 22
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: encrypted-image-tests
spec:
  selector:
    matchLabels:
      app: encrypted-image-tests
  template:
    metadata:
      labels:
        app: encrypted-image-tests
    spec:
      runtimeClassName: kata-qemu-sev
      containers:
      - name: encrypted-image-tests
        image: quay.io/kata-containers/encrypted-image-tests:encrypted
        imagePullPolicy: Always
```

Save this service yaml to a file named `encrypted-image-tests.yaml`. Notice the image URL specified points to the previously described CoCo sample encrypted container image. `kata-qemu-sev` must also be specified as the `runtimeClassName`.

Start the service:

```
kubectl apply -f encrypted-image-tests.yaml
```

Check for pod errors:

```
pod_name=$(kubectl get pod -o wide | grep encrypted-image-tests | awk '{print $1;}')
kubectl describe pod ${pod_name}
```

If there are no errors, a CoCo encrypted container with SEV has been successfully launched!

#### Verify SEV Memory Encryption

The container `dmesg` report can be parsed to verify SEV memory encryption.

Get pod IP:

```
pod_ip=$(kubectl get pod -o wide | grep encrypted-image-tests | awk '{print $6;}')
```

Get the CoCo sample encrypted container image SSH access key from docker image label and save it to a file:

```
docker pull quay.io/kata-containers/encrypted-image-tests:encrypted
docker inspect quay.io/kata-containers/encrypted-image-tests:encrypted | \
  jq -r '.[0].Config.Labels.ssh_key' \
  | sed "s|\(-----BEGIN OPENSSH PRIVATE KEY-----\)|\1\n|g" \
  | sed "s|\(-----END OPENSSH PRIVATE KEY-----\)|\n\1|g" \
  > encrypted-image-tests
```

Set permissions on the SSH private key file:

```
chmod 600 encrypted-image-tests
```

Run a SSH command to parse the container `dmesg` output for SEV enabled messages:

```
ssh -i encrypted-image-tests \
  -o "StrictHostKeyChecking no" \
  -t root@${pod_ip} \
  'dmesg | grep SEV'
```

The output should look something like this:
```
[    0.150045] Memory Encryption Features active: AMD SEV
```

## Building a new encrypted container image and deploying it as a CoCo workload

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

> **Note** The communication between Verdictd and EAA KBC is based on rats-tls,
so you need to confirm that [rats-tls](https://github.com/inclavare-containers/rats-tls) has been correctly installed in your running environment.

3. Agent Configuration

Add configuration `aa_kbc_params= 'eaa_kbc::<$IP>:<$PORT>'` to agent config file, the IP and PORT should be consistent with verdictd.

### Use offline SEV KBC and simple-kbs (SEV)

#### Create an Encrypted Image

If SSH access to the container is desired, create a keypair:

```
ssh-keygen -t ed25519 -f encrypted-image-tests -P "" -C "" <<< y
```

The above command will save the keypair in a file named `encrypted-image-tests`.

Here is a sample Dockerfile to create a docker image:

```
FROM alpine:3.16

# Update and install openssh-server
RUN apk update && apk upgrade && apk add openssh-server

# Generate container ssh key
RUN ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -P ""

# A password needs to be set for login to work. An empty password is
# unproblematic as password-based login to root is not allowed.
RUN passwd -d root

# Copy the remote generated public key to the container authorized_keys
# Generate with 'ssh-keygen -t ed25519 -f encrypted-image-tests -P "" -C ""'
COPY encrypted-image-tests.pub /root/.ssh/authorized_keys

# Entry point - run sshd
ENTRYPOINT /usr/sbin/sshd -D
```

Store this `Dockerfile` in the same directory as the `encrypted-image-tests` ssh keypair.

Build image:

```
docker build -t encrypted-image-tests .
```

Tag and upload this unencrypted docker image to a registry:

```
docker tag encrypted-image-tests:latest [REGISTRY_URL]:unencrypted
docker push [REGISTRY_URL]:unencrypted
```

Be sure to replace `[REGISTRY_URL]` with the desired registry URL.

[skopeo](https://github.com/containers/skopeo) is required to encrypt the container image. Follow the instructions here to install `skopeo`:

[skopeo Installation](https://github.com/containers/skopeo/blob/main/install.md)

The Attestation Agent hosts a grpc service to support encrypting the image. Clone the repository:

```
attestation_agent_tag="v0.1.0"
git clone https://github.com/confidential-containers/attestation-agent.git
(cd simple-kbs && git checkout -b "branch_${attestation_agent_tag}" "${attestation_agent_tag}")
```

Run the offline_fs_kbs:

```
(cd attestation-agent/sample_keyprovider/src/enc_mods/offline_fs_kbs \
&& cargo run --release --features offline_fs_kbs -- --keyprovider_sock 127.0.0.1:50001 &)
```

Create the Attestation Agent keyprovider:

```
cat > attestation-agent/sample_keyprovider/src/enc_mods/offline_fs_kbs/ocicrypt.conf <<EOF
{
  "key-providers": {
    "attestation-agent": {
      "grpc": "127.0.0.1:50001"
}}}
EOF
```

Set a desired value for the encryption key:

```
enc_key="RcHGava52DPvj1uoIk/NVDYlwxi0A6yyIZ8ilhEX3X4="
```

Create a Key file:

```
cat > keys.json <<EOF
{
    "key_id1":"${enc_key}"
}
EOF
```

Run skopeo to encrypt the image created in the previous section:

```
sudo OCICRYPT_KEYPROVIDER_CONFIG=$(pwd)/attestation-agent/sample_keyprovider/src/enc_mods/offline_fs_kbs/ocicrypt.conf \
skopeo copy --insecure-policy docker-daemon:[REGISTRY_URL]:unencrypted \
docker-daemon:[REGISTRY_URL]:encrypted \
--encryption-key provider:attestation-agent:$(pwd)/keys.json:key_id1
```

Again, be sure to replace `[REGISTRY_URL]` with the desired registry URL.
`--insecure-policy` flag is used to connect to the attestation agent and will not impact the security of the project.

Push the encrypted image to the registry:

```
docker push [REGISTRY_URL]:encrypted
```

`mysql-client` is required to insert the key into the `simple-kbs` database. `jq` is required to json parse responses on the command line.

* Debian / Ubuntu:

  ```
  sudo apt install mysql-client jq
  ```

* CentOS / Fedora / RHEL:

  ```
  sudo dnf install [ mysql | mariadb | community-mysql ] jq
  ```

The `mysql-client` package name may differ depending on OS flavor and version.

The `simple-kbs` uses default settings and credentials for the MySQL database. These settings can be changed by the `simple-kbs` administrator and saved into a credential file. For the purposes of this quick start, set them in the environment for use with the MySQL client command line:

```
KBS_DB_USER="kbsuser"
KBS_DB_PW="kbspassword"
KBS_DB="simple_kbs"
KBS_DB_TYPE="mysql"
```

Retrieve the host address of the MySQL database container:

```
KBS_DB_HOST=$(docker network inspect simple-kbs_default \
  | jq -r '.[].Containers[] | select(.Name | test("simple-kbs[_-]db.*")).IPv4Address' \
  | sed "s|/.*$||g")
```

Add the key to the `simple-kbs` database without any verification policy:

```
mysql -u${KBS_DB_USER} -p${KBS_DB_PW} -h ${KBS_DB_HOST} -D ${KBS_DB} <<EOF
  REPLACE INTO secrets VALUES (10, 'key_id1', '${enc_key}', NULL);
  REPLACE INTO keysets VALUES (10, 'KEYSET-1', '["key_id1"]', NULL);
EOF
```

The second value in the keysets table (`KEYSET-1`) must match the `guest_pre_attestation_keyset` value specified in the SEV kata configuration file located here:

`/opt/confidential-containers/share/defaults/kata-containers/configuration-qemu-sev.toml`

Return to step [Launch the Pod and Verify SEV Encryption](#launch-the-pod-and-verify-sev-encryption) and finish the remaining process. Make sure to change the `encrypted-image-tests.yaml` to reflect the new `[REGISTRY_URL]`.

To learn more about creating custom policies, see the section on [Creating a simple-kbs Policy to Verify the SEV Firmware Measurement](#creating-a-simple-kbs-policy-to-verify-the-sev-guest-firmware-measurement).


#### Creating a simple-kbs Policy to Verify the SEV Guest Firmware Measurement

The `simple-kbs` can be configured with a policy that requires the kata shim to provide a matching SEV guest firmware measurement to release the key for decrypting the image. At launch time, the kata shim will collect the SEV guest firmware measurement and forward it in a key request to the `simple-kbs`.

These steps will use the CoCo sample encrypted container image, but the image URL can be replaced with a user created image registry URL.

To create the policy, the value of the SEV guest firmware measurement must be calculated. 

`pip` is required to install the `sev-snp-measure` utility.

* Debian / Ubuntu:

  ```
  sudo apt install python3-pip
  ```

* CentOS / Fedora / RHEL:

  ```
  sudo dnf install python3
  ```

[sev-snp-measure](https://github.com/IBM/sev-snp-measure) is a utility used to calculate the SEV guest firmware measurement with provided ovmf, initrd, kernel and kernel append input parameters. Install it using the following command:

```
sudo pip install sev-snp-measure
```

The path to the guest binaries required for measurement is specified in the kata configuration. Set them:

```
ovmf_path="/opt/confidential-containers/share/ovmf/OVMF.fd"
kernel_path="/opt/confidential-containers/share/kata-containers/vmlinuz-sev.container"
initrd_path="/opt/confidential-containers/share/kata-containers/kata-containers-initrd.img"
```

The kernel append line parameters are included in the SEV guest firmware measurement. A placeholder will be initially set, and the actual value will be retrieved later from the qemu command line:

```
append="PLACEHOLDER"
```

Use the `sev-snp-measure` utility to calculate the SEV guest firmware measurement using the binary variables previously set:

```
measurement=$(sev-snp-measure --mode=sev --output-format=base64 \
  --ovmf="${ovmf_path}" \
  --kernel="${kernel_path}" \
  --initrd="${initrd_path}" \
  --append="${append}" \
)
```

If the container image is not already present, pull it:

```
encrypted_image_url="quay.io/kata-containers/encrypted-image-tests:encrypted"
docker pull "${encrypted_image_url}"
```

Retrieve the encryption key from docker image label:

```
enc_key=$(docker inspect ${encrypted_image_url} \
  | jq -r '.[0].Config.Labels.enc_key')
```

Add the key, keyset and policy with measurement to the `simple-kbs` database:

```
mysql -u${KBS_DB_USER} -p${KBS_DB_PW} -h ${KBS_DB_HOST} -D ${KBS_DB} <<EOF
  REPLACE INTO secrets VALUES (10, 'key_id1', '${enc_key}', 10);
  REPLACE INTO keysets VALUES (10, 'KEYSET-1', '["key_id1"]', 10);
  REPLACE INTO policy VALUES (10, '["${measurement}"]', '[]', 0, 0, '[]', now(), NULL, 1);
EOF
```

Using the same service yaml from the section on [Launch the Pod and Verify SEV Encryption](#launch-the-pod-and-verify-sev-encryption), launch the service:

```
kubectl apply -f encrypted-image-tests.yaml
```

Check for pod errors:

```
pod_name=$(kubectl get pod -o wide | grep encrypted-image-tests | awk '{print $1;}')
kubectl describe pod ${pod_name}
```

The pod will error out on the key retrieval request to the `simple-kbs` because the policy verification failed due to a mismatch in the SEV guest firmware measurement. This is the error message that should display:

```
Policy validation failed: fw digest not valid
```

The `PLACEHOLDER` value that was set for the kernel append line when the SEV guest firmware measurement was calculated does not match what was measured by the kata shim. The kernel append line parameters can be retrieved from the qemu command line using the following scripting commands, as long as kubernetes is still trying to launch the pod:

```
duration=$((SECONDS+30))
set append

while [ $SECONDS -lt $duration ]; do
  qemu_process=$(ps aux | grep qemu | grep append || true)
  if [ -n "${qemu_process}" ]; then
    append=$(echo ${qemu_process} \
      | sed "s|.*-append \(.*$\)|\1|g" \
      | sed "s| -.*$||")
    break
  fi
  sleep 1
done

echo "${append}"
```

The above check will only work if the `encrypted-image-tests` guest launch is the only consuming qemu process running.

Now, recalculate the SEV guest firmware measurement and store the `simple-kbs` policy in the database:

```
measurement=$(sev-snp-measure --mode=sev --output-format=base64 \
  --ovmf="${ovmf_path}" \
  --kernel="${kernel_path}" \
  --initrd="${initrd_path}" \
  --append="${append}" \
)

mysql -u${KBS_DB_USER} -p${KBS_DB_PW} -h ${KBS_DB_HOST} -D ${KBS_DB} <<EOF
  REPLACE INTO secrets VALUES (10, 'key_id1', '${enc_key}', 10);
  REPLACE INTO keysets VALUES (10, 'KEYSET-1', '["key_id1"]', 10);
  REPLACE INTO policy VALUES (10, '["${measurement}"]', '[]', 0, 0, '[]', now(), NULL, 1);
EOF
```

The pod should now show a successful launch:

```
kubectl describe pod ${pod_name}
```

If the service is hung up, delete the pod and try to launch again:

```
# Delete
kubectl delete -f encrypted-image-tests.yaml

# Verify pod cleaned up
kubectl describe pod ${pod_name}

# Relaunch
kubectl apply -f encrypted-image-tests.yaml
```

Testing the SEV encrypted container launch can be completed by returning to the section on how to [Verify SEV Memory Encryption](#verify-sev-memory-encryption).

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

# Troubleshooting

Confidential Containers integrates several components. If you run into problems,
it can sometimes be difficult to figure out what is going on or how to move forward.
Here are some tips.

If you get stuck or find a bug, please make an issue on this repository or
the repository for the component in question, e.g.,
[the operator](https://github.com/confidential-containers/operator/issues).

## Kubernetes

To figure out which basic area you problem is in, first make sure that your Kubernetes
cluster can schedule non-confidential workloads on your worker node. Remove the `kata-*`
runtime class from your pod yaml and try to run a pod. If your pod still doesn't run,
please refer to a more general Kubernetes troubleshooting guide.

If your cluster is healthy but you cannot start confidential containers, you might
be able get some helpful information from Kubernetes.
Try `kubectl describe pod <your-pod>`
Sometimes this will give you a useful message pointing to a failed attestation
or some sort of missing environment setup. Most of the time you will see a
generic message such as the following:

```
Failed to create pod sandbox: rpc error: code = Unknown desc = failed to create containerd task: failed to create shim: Failed to Check if grpc server is working: rpc error: code = DeadlineExceeded desc = timed out connecting to vsock 637456061:1024: unknown
```

Unfortunately this is a generic message. You'll need to go deeper to figure out
what is going on.

## CoCo Debugging

A good next step is to figure out if things are breaking before or after the VM boots.
You can see if there is a hypervisor process running with something like this.
```bash
ps -ef | grep qemu
```

If you are using a different hypervisor, adjust command accordingly.
If there are no hypervisor processes running on the worker node, the VM has
either failed to start or was shutdown. If there is a hypervisor process,
the problem is probably inside the guest.

Now is a good time to enable debug output for Kata and containerd.
To do this, first look at the containerd config file located at
`/etc/containerd/config.toml`. At the bottom of the file there should
be a section for each runtime class. For example:

```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-qemu-sev]
  cri_handler = "cc"
  runtime_type = "io.containerd.kata-qemu-sev.v2"
  privileged_without_host_devices = true
  pod_annotations = ["io.katacontainers.*"]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-qemu-sev.options]
    ConfigPath = "/opt/confidential-containers/share/defaults/kata-containers/configuration-qemu-sev.toml"
```

The `ConfigPath` entry on the final line shows the path to the Kata configuration file that will be used
for that runtime class.

While you are looking at the containerd config, find the `[debug]` section near the top and  set `level`
to `debug`. Make sure to restart containerd after editing the containerd config file.
You can do this with `sudo systemctl restart containerd`.

Now go to the Kata config file that matches your runtime class and enable every debug option available.
You do not need to restart any daemons when changing the Kata config file; just run another pod
or hope that Kubernetes restarts your existing pod. Note that enabling debug options in the Kata
config file can change the attestation evidence of a confidential guest.

Now you should be able to view logs from containerd with the following:
```
sudo journalctl -xeu containerd
```

Kata writes many messages to this log. It's good to know what you're looking for. There are many
generic messages that are not significant, often arising from a VM not shutting down cleanly
after an unrelated issue.

### VM Doesn't Start
If the VM has failed to start, you might have a problem with confidential
computing support on your worker node. Make sure that you can start
confidential VMs without confidential containers.

Check the containerd log for any obvious errors regarding VM boot.
Try searching the log for the string `error` or for the name
of your hypervisor i.e. `qemu` or `qemu-system-x86_64`.

If there are no obvious errors, try finding the hypervisor
commandline. This should be in the containerd log if you have enabled
debug messages correctly.

It might be tempting to try running the hypervisor command directly
from the command line, but this usually isn't productive. Instead,
try starting a standalone VM using the same kernel, initrd/disk,
command line, firmware, and hypervisor that Kata uses.
This might uncover some kind of system misconfiguration.
You can also find these values in the Kata config file, but looking
in the log is more direct.

Another way to print the hypervisor command is to create a bash script
that prints any arguments it is called with to a file. Then modify the
Kata config file so that the hypervisor path points to this scipt
rather than to the hypervisor. This method can also be used to add
additional parameters to the command line. Just have the bash script
call the hypervisor with whatever arguments it received plus any that
you want to add. This could be useful for enabling debugging or tracing
flags in your hypervisor. For instance, if you are using QEMU and SEV
you might want to add the argument `--trace 'kvm_sev_*'`. Make sure
that QEMU was built with an appropriate tracing backend.

### VM Does Start

If the VM does start, search the containerd log for the string `vmconsole`.
This will show you any guest serial output. You might see some errors
coming from the kernel as the guest tries to boot. You might also see the
Kata agent starting. If the Kata agent has started, you can match
the output to the source to get some clues about what is happening.
You might also see something more obvious, like a panic coming from
the Kata agent.


#### Debug Console

One very useful deugging tool is the Kata guest debug console. You can
enable this by editing the Kata agent configuration file and adding the lines
``` toml
debug_console = true
debug_console_vport = 1026
```

Unfortunately, the agent config file is inside the guest rootfs. If you are
using an initrd, you can update the config file by unpacking the initrd,
changing the file, and then compressing it again. To rebuild the initrd,
use Kata's initrd builder script:
```
kata-containers/tools/osbuilder/initrd-builder/initrd-builder.sh
```

Once you've started a pod with the new initrd, get the id of the pod
you want to access. Do this via `ps -ef | grep qemu` or equivalent.
The id is the long id that shows up in many different arguments.
It should look like `1a9ab65be63b8b03dfd0c75036d27f0ed09eab38abb45337fea83acd3cd7bacd`.
Once you have the id, you can use it to access the debug console.
```
sudo /opt/confidential-containers/bin/kata-runtime exec <id>
```
You might need to symlink the appropriate Kata configuration file for your runtime
class if the `kata-runtime` tries to look at the wrong one.

The debug console gives you access to the guest VM. This is a great way to
investigate missing dependencies or incorrect configurations.

#### Guest Firmware Logs

If the VM is running but there is no guest output in the log,
the guest might have stalled in the firmware. Firmware output will
depend on your firmware and hypervisor. If you are using QEMU and OVMF,
you can see the OVMF output by adding `-global isa-debugcon.iobase=0x402`
and `-debugcon file:/tmp/ovmf.log` to the QEMU command line using the
redirect script described above.

