# Enclave-CC

`enclave-cc` provides process-based isolation using SGX.
This guide assumes that you already have a Kubernetes cluster
and have deployed the operator as described in the **Installation**
section of the [quickstart guide](../quickstart.md).

## Configuring Kubernetes cluster when using SGX hardware mode build

Additional setup steps when using the hardware SGX mode are needed:

1. The cluster needs to have [Intel Software Guard Extensions (SGX) device plugin for Kubernetes](
https://intel.github.io/intel-device-plugins-for-kubernetes/cmd/sgx_plugin/README.html#prerequisites) running.
1. The cluster needs to have [Intel DCAP aesmd](
https://github.com/intel/SGXDataCenterAttestationPrimitives) running on every SGX node and the nodes must be registered.

**Note** kind/minikube based clusters are not recommended when using hardware mode SGX.

## Configuring enclave-cc custom resource to use a different KBC

**Note** Before configuring KBC, please refer to the
[guide](coco-dev.md#deploy-and-configure-tenant-side-coco-key-broker-system-cluster) to deploy KBS cluster.

**Note** The KBC configuration changes to the enclave-cc custom resource yaml 
must be made **before** deploying it. 

Enclave CC supports cc-kbc and sample-kbc, in order to use them, users will have to
properly configure a `decrypt_config.conf`, in order to set the `KBC` (`cc_kbc`
or `sample_kbc`) `IP`,`PORT`, and the `SECURITY_VALIDATE` (`false` or  `true`).

```json
{
    "key_provider": "provider:attestation-agent:KBC::IP:PORT",
     "security_validate": SECURITY_VALIDATE
}
```

The following is an example of `cc_kbc`:

```json
{
    "key_provider": "provider:attestation-agent:cc_kbc::http://127.0.0.1:8080",
    "security_validate": true
}
```
The following is an example of `sample_kbc`:

```json
{
    "key_provider": "provider:attestation-agent:sample_kbc::127.0.0.1:50000",
    "security_validate": false
}
```

Once that's set according to the users needs, the user will then have to run:
`cat decrypt_config.conf | base64 -w 0` in order to get the data encoded and
set it accordingly [here](https://github.com/confidential-containers/operator/blob/6f241fbc056f0a5d9e1bd2c10b2cedc0782b99ff/config/samples/enclave-cc/base/ccruntime-enclave-cc.yaml#L124).

## Creating a sample CoCo workload using enclave-cc

As an example, we setup a sample *hello world*
workload with an encrypted and cosign signed container image using the `enclave-cc` runtime class for process based TEEs. 
This encrypted image is only used for testing. 
If you want to use it in your own production use cases, please refer to
the [guide](../quickstart.md#encrypting-an-image) to create a new encrypted image and deploy it.

The deployment below assumes the hardware SGX mode build is installed by the operator. To try on a non-TEE system, please
use simulate SGX mode build.

The example uses a trivial hello world C application:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: enclave-cc-pod
spec:
  containers:
  - image: ghcr.io/confidential-containers/test-container-enclave-cc:encrypted
    name: hello-world
    workingDir: "/run/rune/occlum_instance/"
    resources:
      limits:
        sgx.intel.com/epc: 600Mi
    env:
    - name: OCCLUM_RELEASE_ENCLAVE
      value: "1"
    command:
    - /run/rune/occlum_instance/build/bin/occlum-run
    - /bin/hello_world
  runtimeClassName: enclave-cc

```

**Note** When the hardware SGX mode payload is used in an SGX enabled cluster, `sgx.intel.com/epc: 600Mi`
resource request must be added to the pod spec.

Again, create a pod YAML file as previously described (this time we named it `enclave-cc-pod.yaml`) .

Create the workload:
```sh
kubectl apply -f enclave-cc-pod.yaml
```
Output:
```
pod/enclave-cc-pod created
```

Ensure the pod was created successfully (in running state):
```sh
kubectl get pods
```
Output:
```
NAME                 READY   STATUS    RESTARTS   AGE
enclave-cc-pod   1/1     Running   0          22s
```

Check the pod is running as expected:
```sh
kubectl logs enclave-cc-pod | head -5
```
Output:
```
["init"]
Hello world!

Hello world!

```

**NOTE** When running in the hardware SGX mode, the logging is disabled
by default.

We can also verify the host does not have the image for others to use:
```sh
crictl -r unix:///run/containerd/containerd.sock image ls | grep helloworld_enc
```
