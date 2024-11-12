# SEV-ES Guide

## Platform Setup


> [!WARNING]
>
> In order to launch SEV or SNP memory encrypted guests, the host must be prepared with a compatible kernel, `6.8.0-rc5-next-20240221-snp-host-cc2568386`. AMD custom changes and required components and repositories will eventually be upstreamed. 

> [Sev-utils](https://github.com/amd/sev-utils/blob/coco-202402240000/docs/snp.md) is an easy way to install the required host kernel, but it will unnecessarily build AMD compatible guest kernel, OVMF, and QEMU components. The additional components can be used with the script utility to test launch and attest a base QEMU SNP guest. However, for the CoCo use case, they are already packaged and delivered with Kata.
Alternatively, refer to the [AMDESE guide](https://github.com/confidential-containers/amdese-amdsev/tree/amd-snp-202402240000?tab=readme-ov-file#prepare-host) to manually build the host kernel and other components.

## Getting Started

This guide covers platform-specific setup for SEV and walks through the complete flows for the different CoCo use cases:

- [Container Launch with Memory Encryption](#container-launch-with-memory-encryption)
- [Pre-Attestation Utilizing Signed and Encrypted Images](#pre-attestation-utilizing-signed-and-encrypted-images)

## Container Launch With Memory Encryption

### Launch a Confidential Service 

To launch a container with SEV memory encryption, the SEV runtime class (`kata-qemu-sev`) must be specified as an annotation in the yaml. A base alpine docker container ([Dockerfile](https://github.com/kata-containers/kata-containers/blob/main/tests/integration/kubernetes/runtimeclass_workloads/confidential/unencrypted/Dockerfile)) has been previously built for testing purposes. This image has also been prepared with SSH access and provisioned with a [SSH public key](https://github.com/kata-containers/kata-containers/blob/main/tests/integration/kubernetes/runtimeclass_workloads/confidential/unencrypted/ssh/unencrypted.pub) for validation purposes.

Here is a sample service yaml specifying the SEV runtime class: 

```yaml
kind: Service
apiVersion: v1
metadata:
  name: "confidential-unencrypted"
spec:
  selector:
    app: "confidential-unencrypted"
  ports:
  - port: 22
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: "confidential-unencrypted"
spec:
  selector:
    matchLabels:
      app: "confidential-unencrypted"
  template:
    metadata:
      labels:
        app: "confidential-unencrypted"
      annotations:
        io.containerd.cri.runtime-handler: kata-qemu-sev
    spec:
      runtimeClassName: kata-qemu-sev
      containers:
      - name: "confidential-unencrypted"
        image: ghcr.io/kata-containers/test-images:unencrypted-nightly
        imagePullPolicy: Always
```

Save the contents of this yaml to a file called `confidential-unencrypted.yaml`.

Start the service:

```shell 
kubectl apply -f confidential-unencrypted.yaml
```

Check for errors:

```shell
kubectl describe pod confidential-unencrypted
```

If there are no errors in the Events section, then the container has been successfully created with SEV memory encryption.

### Validate SEV Memory Encryption

The container dmesg log can be parsed to indicate that SEV memory encryption is enabled and active. The container image defined in the yaml sample above was built with a predefined key that is authorized for SSH access.

Get the pod IP:

```shell
pod_ip=$(kubectl get pod -o wide | grep confidential-unencrypted | awk '{print $6;}')
```

Download and save the [SSH private key](https://github.com/kata-containers/kata-containers/raw/main/tests/integration/kubernetes/runtimeclass_workloads/confidential/unencrypted/ssh/unencrypted) and set the permissions.

```shell
wget https://github.com/kata-containers/kata-containers/raw/main/tests/integration/kubernetes/runtimeclass_workloads/confidential/unencrypted/ssh/unencrypted -O confidential-image-ssh-key

chmod 600 confidential-image-ssh-key
```

The following command will run a remote SSH command on the container to check if SEV memory encryption is active:

```shell
ssh -i confidential-image-ssh-key \
  -o "StrictHostKeyChecking no" \
  -t root@${pod_ip} \
  'dmesg | grep "Memory Encryption Features"'
```

If SEV is enabled and active, the output should return:

```shell
[    0.150045] Memory Encryption Features active: AMD SEV
```

## Create an Encrypted Image

If SSH access to the container is desired, create a keypair:

```shell
ssh-keygen -t ed25519 -f encrypted-image-tests -P "" -C "" <<< y
```

The above command will save the keypair in a file named `encrypted-image-tests`.

Here is a sample Dockerfile to create a docker image:

```Dockerfile
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

```shell
docker build -t encrypted-image-tests .
```

Tag and upload this unencrypted docker image to a registry:

```shell
docker tag encrypted-image-tests:latest [REGISTRY_URL]:unencrypted
docker push [REGISTRY_URL]:unencrypted
```

Be sure to replace `[REGISTRY_URL]` with the desired registry URL.

[skopeo](https://github.com/containers/skopeo) is required to encrypt the container image. Follow the instructions here to install `skopeo`:

[skopeo Installation](https://github.com/containers/skopeo/blob/main/install.md)

The Attestation Agent hosts a grpc service to support encrypting the image. Clone the repository:

```shell
attestation_agent_tag="v0.1.0"
git clone https://github.com/confidential-containers/attestation-agent.git
(cd attestation-agent && git checkout -b "branch_${attestation_agent_tag}" "${attestation_agent_tag}")
```

Run the offline_fs_kbs:

```shell
(cd attestation-agent/sample_keyprovider/src/enc_mods/offline_fs_kbs \
&& cargo run --release --features offline_fs_kbs -- --keyprovider_sock 127.0.0.1:50001 &)
```

Create the Attestation Agent keyprovider:

```shell
cat > attestation-agent/sample_keyprovider/src/enc_mods/offline_fs_kbs/ocicrypt.conf <<EOF
{
  "key-providers": {
    "attestation-agent": {
      "grpc": "127.0.0.1:50001"
}}}
EOF
```

Set a desired value for the encryption key that should be a 32-bytes and base64 encoded value:

```shell
enc_key="RcHGava52DPvj1uoIk/NVDYlwxi0A6yyIZ8ilhEX3X4="
```

Create a Key file:

```shell
cat > keys.json <<EOF
{
    "key_id1":"${enc_key}"
}
EOF
```

Run skopeo to encrypt the image created in the previous section:

```shell
sudo OCICRYPT_KEYPROVIDER_CONFIG=$(pwd)/attestation-agent/sample_keyprovider/src/enc_mods/offline_fs_kbs/ocicrypt.conf \
skopeo copy --insecure-policy \
docker:[REGISTRY_URL]:unencrypted \
docker:[REGISTRY_URL]:encrypted \
--encryption-key provider:attestation-agent:$(pwd)/keys.json:key_id1
```

Again, be sure to replace `[REGISTRY_URL]` with the desired registry URL.
`--insecure-policy` flag is used to connect to the attestation agent and will not impact the security of the project.

Make sure to use the `docker` prefix in the source and destination URL when running the `skopeo copy` command as demonstrated above.
Utilizing images via the local `docker-daemon` is known to have issues, and the `skopeo copy` command does not return an adequate error
response. A remote registry known to support encrypted images like GitHub Container Registry (GHCR) is required.

At this point it is a good idea to inspect the image was really encrypted as skopeo can silently leave it unencrypted. Use
`skopeo inspect` as shown below to check that the layers MIME types are **application/vnd.oci.image.layer.v1.tar+gzip+encrypted**:

```shell
skopeo inspect docker-daemon:[REGISTRY_URL]:encrypted
```

Push the encrypted image to the registry:

```shell
docker push [REGISTRY_URL]:encrypted
```

`mysql-client` is required to insert the key into the `simple-kbs` database. `jq` is required to json parse responses on the command line.

* Debian / Ubuntu:
  
  ```shell
  sudo apt install mysql-client jq
  ```

* CentOS / Fedora / RHEL:
  
  ```shell
  sudo dnf install [ mysql | mariadb | community-mysql ] jq
  ```

The `mysql-client` package name may differ depending on OS flavor and version.

The `simple-kbs` uses default settings and credentials for the MySQL database. These settings can be changed by the `simple-kbs` administrator and saved into a credential file. For the purposes of this quick start, set them in the environment for use with the MySQL client command line:

```shell
KBS_DB_USER="kbsuser"
KBS_DB_PW="kbspassword"
KBS_DB="simple_kbs"
KBS_DB_TYPE="mysql"
```

Retrieve the host address of the MySQL database container:

```shell
KBS_DB_HOST=$(docker network inspect simple-kbs_default \
  | jq -r '.[].Containers[] | select(.Name | test("simple-kbs[_-]db.*")).IPv4Address' \
  | sed "s|/.*$||g")
```

Add the key to the `simple-kbs` database without any verification policy:

```shell
mysql -u${KBS_DB_USER} -p${KBS_DB_PW} -h ${KBS_DB_HOST} -D ${KBS_DB} <<EOF
  REPLACE INTO secrets VALUES (10, 'key_id1', '${enc_key}', NULL);
  REPLACE INTO keysets VALUES (10, 'KEYSET-1', '["key_id1"]', NULL);
EOF
```

The second value in the keysets table (`KEYSET-1`) must match the `guest_pre_attestation_keyset` value specified in the SEV kata configuration file located here:

`/opt/confidential-containers/share/defaults/kata-containers/configuration-qemu-sev.toml`

Return to step [Launch the Pod and Verify SEV Encryption](#launch-the-pod-and-verify-sev-encryption) and finish the remaining process. Make sure to change the `encrypted-image-tests.yaml` to reflect the new `[REGISTRY_URL]`.

To learn more about creating custom policies, see the section on [Creating a simple-kbs Policy to Verify the SEV Firmware Measurement](#creating-a-simple-kbs-policy-to-verify-the-sev-guest-firmware-measurement).

