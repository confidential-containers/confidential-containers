# Encrypted Container Images without Hardware Support

Without Confidential Computing hardware, there is no way to securely provision
the keys for an encrypted image. Nonetheless, in this demo we describe how to
test encrypted images support with the non-tee `kata`/`kata-qemu` runtimeclass.

## Creating a CoCo workload using a pre-existing encrypted image

We will now proceed to download and run a sample encrypted container image using the CoCo building blocks.

A demo container image is provided at [docker.io/katadocker/ccv0-ssh](https://hub.docker.com/r/katadocker/ccv0-ssh).
It is encrypted with [Attestation Agent](https://github.com/confidential-containers/attestation-agent)'s [offline file system key broker](https://github.com/confidential-containers/attestation-agent/tree/64c12fbecfe90ba974d5fe4896bf997308df298d/src/kbc_modules/offline_fs_kbc) and [`aa-offline_fs_kbc-keys.json`](https://github.com/confidential-containers/documentation/blob/main/demos/ssh-demo/aa-offline_fs_kbc-keys.json) as its key file.

We have prepared a sample CoCo operator custom resource that is based on the standard `ccruntime.yaml`, but in addition has the the decryption keys and configuration required to decrypt this sample container image.
> **Note** All pods started with this sample resource will be able to decrypt the sample container and all keys shown are for demo purposes only and should not be used in production.

 To test out creating a workload from the sample encrypted container image, we can take the following steps:

### Swap out the standard custom resource for our sample

Support for multiple custom resources in not available in the current release. Consequently, if a custom resource already exists, then you'll need to remove it first before deploying a new one. We can remove the standard custom resource with:
```sh
kubectl delete -k github.com/confidential-containers/operator/config/samples/ccruntime/<CCRUNTIME_OVERLAY>?ref=<RELEASE_VERSION>
```
and in it's place install the modified version with the sample container's decryption key:
```sh
kubectl apply -k github.com/confidential-containers/operator/config/samples/ccruntime/ssh-demo?ref=<RELEASE_VERSION>
```
Wait until each pod has the STATUS of Running.
```sh
kubectl get pods -n confidential-containers-system --watch
```
### Test creating a workload from the sample encrypted image

Create a new Kubernetes deployment that uses the `docker.io/katadocker/ccv0-ssh` container image with:
```sh
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
```sh
kubectl apply -f ccv0-ssh-demo.yaml
```
and wait for the pod to start. This process should show that we are able to pull the encrypted image, and using the decryption key configured in the CoCo sample guest image, decrypt the container image and create a workload using it.

The demo image has an SSH host key embedded in it, which is protected by it's encryption, but we can download the sample private key and use this to ssh into the container to validate it hasn't been tampered with.

Download the SSH key with:
```sh
curl -Lo ccv0-ssh https://raw.githubusercontent.com/confidential-containers/documentation/main/demos/ssh-demo/ccv0-ssh
```
Ensure that the permissions are set correctly with:
```sh
chmod 600 ccv0-ssh
```

We can then use the key to ssh into the container:
```sh
$ ssh -i ccv0-ssh root@$(kubectl get service ccv0-ssh -o jsonpath="{.spec.clusterIP}")
```
You will be prompted about whether the host key fingerprint is correct. This fingerprint should match the one specified in the container image: `wK7uOpqpYQczcgV00fGCh+X97sJL3f6G1Ku4rvlwtR0.`
