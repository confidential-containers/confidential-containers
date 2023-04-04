# EAA Verdictd Guide

EAA is used to perform attestation at runtime and provide guest with confidential resources such as keys.
It is based on [rats-tls](https://github.com/inclavare-containers/rats-tls).

[Verdictd](https://github.com/inclavare-containers/verdictd) is the Key Broker Service and Attestation Service of EAA.
The EAA KBC is an optional module in the attestation-agent at compile time,
which can be used to communicate with Verdictd.
The communication is established on the encrypted channel provided by rats-tls.

EAA can now be used on intel TDX and intel SGX platforms.

## Create encrypted image

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

## Deploy encrypted image

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
