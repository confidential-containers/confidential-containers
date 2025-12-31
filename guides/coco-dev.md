# Running a workload

## Creating a sample CoCo workload

Once you've used the operator to install Confidential Containers, you can run a pod with CoCo by simply adding a runtime class.
First, we will use the `kata-qemu-coco-dev` runtime class which uses CoCo without hardware support.
Initially we will try this with an unencrypted container image.

In this example, we will be using the bitnami/nginx image as described in the following yaml:
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
  name: nginx
  annotations:
    io.containerd.cri.runtime-handler: kata-qemu-coco-dev
spec:
  containers:
  - image: bitnami/nginx:1.22.0
    name: nginx
  dnsPolicy: ClusterFirst
  runtimeClassName: kata-qemu-coco-dev
```

Setting the `runtimeClassName` is usually the only change needed to the pod yaml, but some platforms
support additional annotations for configuring the enclave. See the [guides](../guides) for
more details.

With Confidential Containers, the workload container images are never downloaded on the host.
For verifying that the container image doesn’t exist on the host, you should log into the k8s node and ensure the following command returns an empty result:
```shell
root@cluster01-master-0:/home/ubuntu# crictl -r unix:///run/containerd/containerd.sock image ls | grep bitnami/nginx
```
You will run this command again after the container has started.

Create a pod YAML file as previously described (we named it `nginx.yaml`) .

Create the workload:
```shell
kubectl apply -f nginx.yaml
```

Output:
```shell
pod/nginx created
```

Ensure the pod was created successfully (in running state):
```shell
kubectl get pods
```

Output:
```shell
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          3m50s
```

Now go back to the k8s node and ensure that you don’t have any bitnami/nginx images on it:
```shell
root@cluster01-master-0:/home/ubuntu# crictl  -r  unix:///run/containerd/containerd.sock image ls | grep bitnami/nginx
```

## Encrypted and/or signed images with attestation

The previous example does not involve any attestation because the workload container isn't signed or encrypted,
and the workload itself does not require any secrets.

This is not the case for most real workloads. It is recommended to use CoCo with signed and/or encrypted images.
The workload itself can also request secrets from the attestation agent in the guest.

Secrets are provisioned to the guest in conjunction with an attestation, which is based on hardware evidence.
The rest of this guide focuses on setting up more substantial encrypted/signed workloads using attestation
and confidential hardware.

CoCo has a modular attestation interface and there are a few options for attestation.
CoCo provides a generic Key Broker Service (KBS) that the rest of this guide will be focused on.

### Select Runtime Class

To use CoCo with confidential hardware, first switch to the appropriate runtime class.
TDX has one runtime class, `kata-qemu-tdx`. 

For SNP, use the `kata-qemu-snp` runtime class and follow the [SNP guide](https://confidentialcontainers.org/docs/examples/snp-container-launch/).

### Deploy and Configure tenant-side CoCo Key Broker System cluster

The following describes how to run and provision the generic KBS.
The KBS should be run in a trusted environment. The KBS is not just one service,
but a combination of several.

A tenant-side CoCo Key Broker System cluster includes:
- Key Broker Service (KBS): Brokering service for confidential resources.
- Attestation Service (AS): Verifier for remote attestation.
- Reference Value Provider Service (RVPS): Provides reference values for AS.
- CoCo Keyprovider: Component to encrypt the images following ocicrypt spec.

To quick start the KBS cluster, a `docker compose` yaml is provided to launch.

```shell
# Clone KBS git repository
git clone https://github.com/confidential-containers/trustee.git
cd trustee/kbs
export KBS_DIR_PATH=$(pwd)

# Generate a user auth key pair
openssl genpkey -algorithm ed25519 > config/private.key
openssl pkey -in config/private.key -pubout -out config/public.pub

cd ..

# Start KBS cluster
docker compose up -d
```

If configuration of KBS cluster is required, edit the following config files and restart the KBS cluster with `docker compose`:

- `$KBS_DIR_PATH/config/kbs-config.toml`: configuration for Key Broker Service.
- `$KBS_DIR_PATH/config/as-config.json`: configuration for Attestation Service.
- `$KBS_DIR_PATH/config/sgx_default_qcnl.conf`: configuration for Intel TDX/SGX verification. See [details](https://github.com/confidential-containers/trustee/blob/main/attestation-service/docs/grpc-as.md#quick-start).

When KBS cluster is running, you can modify the policy file used by AS policy engine ([OPA](https://www.openpolicyagent.org/)) at any time:

- `$KBS_DIR_PATH/data/attestation-service/opa/default.rego`: Policy file for evidence verification of AS, refer to [AS Policy Engine](https://github.com/confidential-containers/attestation-service#policy-engine) for more infomation.

### Encrypting an Image

[skopeo](https://github.com/containers/skopeo) is required to encrypt the container image.
Follow the [instructions](https://github.com/containers/skopeo/blob/main/install.md) to install `skopeo`.
If building with Ubuntu 22.04, make sure to follow the instructions to build skopeo from source, otherwise 
there will be errors regarding version incompatibility between ocicrypt and skopeo. Make sure the downloaded
skopeo version is at least 1.16.0. Ubuntu 22.04 builds skopeo with an outdated ocicrypt version, which does
not support the keyprovider protocol we depend on. 

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

Then push the image to a registry:

```shell
skopeo copy oci:busybox:encrypted [SCHEME]://[REGISTRY_URL]:encrypted
```
Be sure to replace `[SCHEME]` with registry scheme type like `docker`, replace `[REGISTRY_URL]` with the desired registry URL like `docker.io/encrypt_test/busybox`.

### Signing an Image

[cosign](https://github.com/sigstore/cosign) is required to sign the container image. Follow the instructions here to install `cosign`:

To install cosign, find and unpackage the corresponding package to the machine being used from their [release page](https://github.com/sigstore/cosign/releases).

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

### Deploy an Encrypted Image as a CoCo workload on CC HW

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

Then configure `/opt/confidential-containers/share/defaults/kata-containers/configuration-<RUNTIME_CLASS_SUFFIX>.toml` to add `agent.aa_kbc_params=cc_kbc::<KBS_URI>` to kernel parameters. Here `RUNTIME_CLASS_SUFFIX` is something like `qemu-coco-dev`, `KBS_URI` is the address of Key Broker Service in KBS cluster like `http://123.123.123.123:8080`.

Deploy encrypted image as a workload:

```shell
kubectl apply -f encrypted-image-test-busybox.yaml
``` 
