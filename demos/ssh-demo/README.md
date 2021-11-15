# SSH demo

To demonstrate confidential containers capabilities, we run a pod with SSH public key authentication.

Compared to the execution of and login to a shell on a pod, an SSH connection is cryptographically secured and requires a private key.
It cannot be established by unauthorized parties, such as someone who controls the node.
The container image contains the SSH host key that can be used for impersonating the host we will connect to.
Because this container image is encrypted, and the key to decrypting this image is only provided in measurable ways (e.g. attestation or encrypted initrd), and because the pod/guest memory is protected, even someone who controls the node cannot steal this key.

## Building the container image

The image built should be encrypted.
To receive a decryption key at run time, the Confidential Containers project utilizes the [Attestation Agent](https://github.com/confidential-containers/attestation-agent).

### Generating SSH keys

```sh
$ ssh-keygen -t ed25519 -f ccv0-ssh -P "" -C ""
```

generates an SSH key `ccv0-ssh` and the correspondent public key `ccv0-ssh.pub`.

### Building the image

The provided `Dockerfile` expects `ccv0-sh.pub` to exist.
Using Docker, you can build with

```sh
$ docker build -t ccv0-ssh .
```

Alternatively, Buildah can be used (`buildah build` or formerly `buildah bud`).
The SSH host key fingerprint is displayed during the build.

## Connecting to the guest

Running the image depends on your exact confidential containers setup.
A Kubernetes YAML file specifying the [Kata Containers](https://github.com/kata-containers/kata-containers) runtime is included, but the image is still a placeholder at this time.
With common CNI setups, on the same host, with the service running, you can connect via SSH with

```sh
$ ssh -i ccv0-ssh root@$(kubectl get service ccv0-ssh -o jsonpath="{.spec.clusterIP}")
```

You will be prompted about whether the host key fingerprint is correct.
This fingerprint should match the one displayed in the Docker build.

A `crictl`-compatible sandbox configuration is also included, which forwards the pod SSH port (22) to 2222 on the host (use the `-p` flag in SSH).
