# IBM Secure Execution Guide

This document explains how to install and run a confidential container on an IBM Secure 
Execution-enabled Z machine (s390x). A secure image is an encrypted Linux image comprising a kernel image,
an initial RAM file system (initrd) image, and a file specifying kernel parameters (parmfile).
It is an essential component for running a confidential container. The public key used for
encryption is associated with a private key managed by a trusted firmware called
[ultravisor](https://www.ibm.com/docs/en/linux-on-systems?topic=execution-components).

This means that a secure image is machine-specific, resulting in its absence from a released
payload image in `ccruntime`. To use it, you need to build a secure image with your own public
key and create a payload image bundled with it.

## Prerequisites

Kindly review the [section](https://github.com/confidential-containers/confidential-containers/blob/main/quickstart.md#prerequisites) titled identically in the `QuickStart`.

## Build a Payload Image via kata-deploy

If you have a local container registry running at `localhost:5000`, refer to the
[document](https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/how-to-run-kata-containers-with-SE-VMs.md)
on Kata Containers for details on building a payload image for IBM Secure Execution.

## Install CoCo

For installation instructions using Helm charts, please refer to the
[charts repository](https://github.com/confidential-containers/charts).

## Verify the Installation

Once installed, verify that the runtime classes are available:

```
$ kubectl get runtimeclass
NAME           HANDLER        AGE
kata           kata-qemu      60s
kata-qemu      kata-qemu      61s
kata-qemu-se   kata-qemu-se   61s
```

To verify the installation, use the `kata-qemu-se` runtime class:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-kata
spec:
  runtimeClassName: kata-qemu-se
  containers:
  - name: nginx
    image: nginx
EOF
pod/nginx-kata created
$ kubectl get pods
NAME         READY   STATUS    RESTARTS   AGE
nginx-kata   1/1     Running   0          15s
```

## Uninstall Resources

For uninstallation instructions, refer to the [charts repository](https://github.com/confidential-containers/charts).
