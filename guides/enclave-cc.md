# Enclave-CC

`enclave-cc` provides process-based isolation using SGX.
This guide assumes that you already have a Kubernetes cluster
and have deployed the operator as described in the **Installation**
section of the [quickstart guide](../quickstart.md).

## Configuring enclave-cc custom resource to use a different KBC

**Note** The KBC configuration changes to the enclave-cc custom resource yaml 
must be made **before** deploying it. 

Enclave CC supports Verdictd and in order to use it, users will have to
properly configure a decrypt_config.conf, in order to set the `KBC` (`sample_kbc`
or `eaa_kbc`) `IP`,`PORT`, and the `SECURITY_VALIDATE` (`false` or  `true`)
```
{
    "key_provider": "provider:attestation-agent:KBC::IP:PORT",
     "security_validate": SECURITY_VALIDATE
}
```

Once that's set according to the users needs, the user will then have to run:
`cat decrypt_config.conf | base64 -w 0` in order to get the data encoded and
set it accordingly [here](https://github.com/confidential-containers/operator/blob/6f241fbc056f0a5d9e1bd2c10b2cedc0782b99ff/config/samples/enclave-cc/base/ccruntime-enclave-cc.yaml#L124).

## Creating a sample CoCo workload using enclave-cc

As an example, we setup a sample *hello world*
workload with an encrypted and cosign signed container image using the `enclave-cc` runtime class for process based TEEs.
The deployment below assumes the hardware SGX mode build is installed by the operator. To try on a non-TEE system, please
use simulate SGX mode build.

The example uses a trivial hello world C application:
```
apiVersion: v1
kind: Pod
metadata:
  name: enclave-cc-pod
spec:
  containers:
  - image: ghcr.io/confidential-containers/test-container-enclave-cc:encrypted
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
