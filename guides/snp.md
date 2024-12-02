# SNP Guide

## Platform Setup

In order to launch SEV or SNP memory encrypted guests, the host must be prepared with a compatible kernel. Required changes in external components are still under development but are planned to be upstream soon.

The easiest way to initialize SEV or SNP on a platform is to follow the sev-utils [guide](https://github.com/amd/sev-utils/blob/coco-202402240000/docs/snp.md). The provided script builds and installs the required host kernel version.

Alternatively, refer to the [AMDESE guide](https://github.com/confidential-containers/amdese-amdsev/tree/amd-snp-202402240000?tab=readme-ov-file#prepare-host) to manually build the host kernel and other components.

## Getting Started

This guide covers platform-specific setup for SNP and walks through the complete flows for the different CoCo use cases:

- [Container Launch with Memory Encryption](#container-launch-with-memory-encryption)
- [Pre-Attestation Utilizing Signed and Encrypted Images](#pre-attestation-utilizing-signed-and-encrypted-images)

## Container Launch With Memory Encryption - No Attestation

### Launch a Confidential Service 

To launch a container with SNP memory encryption, the SNP runtime class (`kata-qemu-snp`) must be specified as an annotation in the yaml. A base alpine docker container ([Dockerfile](https://github.com/kata-containers/kata-containers/blob/main/tests/integration/kubernetes/runtimeclass_workloads/confidential/unencrypted/Dockerfile)) has been previously built for testing purposes. This image has also been prepared with SSH access and provisioned with a [SSH public key](https://github.com/kata-containers/kata-containers/blob/main/tests/integration/kubernetes/runtimeclass_workloads/confidential/unencrypted/ssh/unencrypted.pub) for validation purposes.

Here is a sample service yaml specifying the SNP runtime class: 

```
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
        io.containerd.cri.runtime-handler: kata-qemu-snp
        io.katacontainers.config.pre_attestation.enabled: "false"
    spec:
      runtimeClassName: kata-qemu-snp
      containers:
      - name: "confidential-unencrypted"
        image: ghcr.io/kata-containers/test-images:unencrypted-nightly
        imagePullPolicy: Always
```

Save the contents of this yaml to a file called confidential-unencrypted.yaml.

Notice that pre-attestation enabled annotation is set to false. This is required, otherwise the scheduler will expect an encrypted container image and initiate a key request.

Start the service:

  ```
  kubectl apply -f confidential-unencrypted.yaml
  ```

Check for errors:

```
kubectl describe pod confidential-unencrypted
```

If there are no errors in the Events section, then the container has been successfully created with SNP memory encryption.

### Validate SNP Memory Encryption

The container dmesg log can be parsed to indicate that SNP memory encryption is enabled and active. The container image defined in the yaml sample above was built with a predefined key that is authorized for SSH access.

Get the pod IP:

```
pod_ip=$(kubectl get pod -o wide | grep confidential-unencrypted | awk '{print $6;}')
```

Download and save the SSH private key and set the permissions.
```
wget https://github.com/kata-containers/kata-containers/raw/main/tests/integration/kubernetes/runtimeclass_workloads/confidential/unencrypted/ssh/unencrypted -O confidential-image-ssh-key

chmod 600 confidential-image-ssh-key
```

The following command will run a remote SSH command on the container to check if SNP memory encryption is active:

```
ssh -i confidential-unencrypted \
  -o "StrictHostKeyChecking no" \
  -t root@${pod_ip} \
  'dmesg | grep SNP'
```

If SNP is enabled and active, the output should return:

```
[    0.150045] Memory Encryption Features active: AMD SNP
```

## Launching a CoCo Container with SNP Attestation Using Trustee

### Prerequisites
In order to launch a container with SNP attestation using Trustee, these conditions need to be met first.

- To use the trustee services, it is required to have an operator version of at least 0.9.0. Refer back to the [quickstart](../quickstart.md#deploy-the-operator) guide for instructions on how to do so.


### Install Trustee and start the KBS Cluster

Trustee is a repository containing tools and components for attesting a confidential guest. The Key Broker Service (KBS) cluster acts as a server that facilitates remote attestation and secret delivery. 

Follow these steps to install [trustee](https://github.com/confidential-containers/trustee) and start the KBS cluster:

```
git clone https://github.com/confidential-containers/trustee.git

cd trustee

openssl genpkey -algorithm ed25519 > kbs/config/private.key
openssl pkey -in kbs/config/private.key -pubout -out kbs/config/public.pub

docker-compose up -d
```

The kbs cluster is launched now. To ensure it is up and running use the ``` docker ps ``` command. 

The expected outcome is:

```
$ docker ps

CONTAINER ID   IMAGE                                                     COMMAND                  CREATED         STATUS         PORTS                                           NAMES
7e7e518e650a   ghcr.io/confidential-containers/coco-keyprovider:latest   "coco_keyprovider --…"   4 seconds ago   Up 2 seconds   0.0.0.0:50000->50000/tcp, :::50000->50000/tc trustee-keyprovider-1
8a99f310c8e2   trustee-kbs                                               "/usr/local/bin/kbs …"   4 seconds ago   Up 3 seconds   0.0.0.0:8080->8080/tcp, :::8080->8080/tcp       trustee-kbs-1
3cb19c1eee2c   trustee-as                                                "grpc-as --socket 0.…"   4 seconds ago   Up 3 seconds   0.0.0.0:50004->50004/tcp, :::50004->50004/tcp   trustee-as-1
f41c5cae6fe0   trustee-rvps                                              "rvps"                   4 seconds ago   Up 3 seconds   0.0.0.0:50003->50003/tcp, :::50003->50003/tcp   trustee-rvps-1

```

### Store the Key

In order to utilize attestation on an encrypted image with trustee, the first step is to store the key with KBS. This is done by running the KBS cluster, which is already covered [above](#install-trustee-and-start-the-kbs-cluster), and then using the kbs client to store the key.

To store the key to a snp guest container

  1. Install the dependencies listed [here](https://github.com/confidential-containers/trustee/blob/main/kbs/quickstart.md).
  2. Run ```cargo build``` inside the trustee/tools/kbs-client/ directory.
  3. Generate the key2 file that will be used to store the key to access the container. Generate the file with a temporary value for the time being using ```echo "testing a key" > ../key2``` from the trustee/ directory.
  4. Run the kbs-client from trustee/ as below (where .../key2 is the key file)
    ```
    ./target/debug/kbs-client --url http://127.0.0.1:8080 config --auth-private-key kbs/config/private.key set-resource --path default/key/key2 --resource-file ../key2
    ```
  5. Verify the key under trustee/kbs/data/kbs-storage/default/key.
    
### Create the Certificate-Chain

Another key component in creating a container with SNP attestation is the certificate chain (cert-chain). Use the following commands to create a cert-chain for SNP attestation using snphost.

```
git clone https://github.com/virtee/snphost.git && cd snphost/
cargo build
mkdir /tmp/certs
./target/debug/snphost fetch vcek der /tmp/certs
./target/debug/snphost import /tmp/certs /opt/snp/cert_chain.cert
```

Certificate chains are an essential piece for creating a secure and trusted environment, ensuring that data is processed securely and that all components involved are verified and trustworthy.

### Edit the SNP Config File

In order to use SNP with attestation, the Kata SNP configuration file needs to be edited first. The config file can be found under ``` /opt/kata/share/defaults/kata-containers/configuration-qemu-snp.toml ```.

First, the location of the certificate chain needs to be specified under ```snp_certs_path```.

```
snp_certs_path = "{PATH TO cert_chain.cert}"
```

The next thing that needs to be addressed in the Kata SNP config file is the ```kernel_param``` line.

``` kernel_params = "agent.guest_components_rest_api=resource agent.aa_kbc_params=cc_kbc::http://{IP TO YOUR MACHINE}:8080" ```

The ```kernel_params``` line is used to specify additional parameters that should be passed to the kernel when it boots. In the line above there are two parameters being added. The first being ``` agent.guest_components_rest_api=resource ```. This parameter is enabling a REST API for the guest components within the Kata Container. This indicates that the guest components should be configured to manage or interact with specific resources within the guest environment.

The other parameter being specified is ```agent.aa_kbc_params=cc_kbc::http://{IP TO YOUR MACHINE}:8080```. This parameter is configuring the Attestation Agent (AA) to use a Key Broker Client (KBC) for secure key management. The cc_kbc refers to the type of KBC being used, and the URL with the IP of the machine being used specifies the endpoint where the KBC is running. This step is crucial for secure communication and key management between the guest and the host.

### Launch your Pod

To launch a container with SNP attestation, the SNP runtime class (```kata-qemu-snp```) is required. Below is a sample pod yaml utilizing the SNP runtime class.

```
apiVersion: v1
kind: Pod
metadata:
  name: pod-snp
spec:
  runtimeClassName: kata-qemu-snp
  restartPolicy: Always
  containers:
    - name: cc-snp
      image: storytel/alpine-bash-curl:latest
      imagePullPolicy: Always
      command:
        - sh
        - -c
        - |
          curl http://127.0.0.1:8006/cdh/resource/default/key/key2; sleep 100
```
Save the contents of the above yaml file to ```pod-kata-qemu-snp.yaml```.

Notice the runtimeclass that is specified, ```kata-qemu-snp```. Also take note of the final command in the pod yaml file. The curl command is used to access the KBS service to attest the SNP container. 

Start the pod:
``` kubectl apply -f pod-kata-qemu-snp.yaml ```

Check for errors:
```kubectl describe pod pod-snp```

If there are no errors, a pod with SNP attestation has been successfully deployed.

### Validate Attestation

The ```docker``` and ```kubectl``` logs can be used to validate that the attestation step occurred. 

After launching the pod, run ```docker ps``` to see the running trustee kbs client services running.

```
CONTAINER ID   IMAGE                                                     COMMAND                  CREATED      STATUS      PORTS                                           NAMES
7e7e518e650a   ghcr.io/confidential-containers/coco-keyprovider:latest   "coco_keyprovider --…"   2 days ago   Up 2 days   0.0.0.0:50000->50000/tcp, :::50000->50000/tcp   trustee-keyprovider-1
8a99f310c8e2   trustee-kbs                                               "/usr/local/bin/kbs …"   2 days ago   Up 2 days   0.0.0.0:8080->8080/tcp, :::8080->8080/tcp       trustee-kbs-1
3cb19c1eee2c   trustee-as                                                "grpc-as --socket 0.…"   2 days ago   Up 2 days   0.0.0.0:50004->50004/tcp, :::50004->50004/tcp   trustee-as-1
f41c5cae6fe0   trustee-rvps                                              "rvps"                   2 days ago   Up 2 days   0.0.0.0:50003->50003/tcp, :::50003->50003/tcp   trustee-rvps-1
```

Look at the logs for ```trustee_kbs_1```.

```
$ docker logs trustee_kbs_1
[2024-08-23T20:41:13Z INFO  kbs] Using config file /etc/kbs-config.toml
[2024-08-23T20:41:13Z INFO  kbs::attestation::coco::grpc] Default AS connection pool size (100) is used
[2024-08-23T20:41:13Z INFO  kbs::attestation::coco::grpc] connect to remote AS [http://as:50004] with pool size 100
[2024-08-23T20:41:13Z INFO  kbs] Starting HTTP server at [0.0.0.0:8080]
[2024-08-23T20:41:13Z INFO  actix_server::builder] starting 64 workers
[2024-08-23T20:41:13Z INFO  actix_server::server] Tokio runtime found; starting in existing Tokio runtime
[2024-08-26T05:35:22Z INFO  actix_web::middleware::logger] 172.19.0.1 "POST /kbs/v0/resource/default/key/key2 HTTP/1.1" 200 0 "-" "kbs-client/0.1.0" 0.001008
[2024-08-26T05:39:24Z INFO  kbs::http::attest] Auth API called.
[2024-08-26T05:39:24Z INFO  actix_web::middleware::logger] 172.19.0.1 "POST /kbs/v0/auth HTTP/1.1" 200 74 "-" "attestation-agent-kbs-client/0.1.0" 0.000163
[2024-08-26T05:39:24Z INFO  kbs::http::attest] Attest API called.
[2024-08-26T05:39:24Z INFO  actix_web::middleware::logger] 172.19.0.1 "POST /kbs/v0/attest HTTP/1.1" 200 2652 "-" "attestation-agent-kbs-client/0.1.0" 0.014426
[2024-08-26T05:39:24Z WARN  kbs::token::coco] No Trusted Certificate in Config, skip verification of JWK cert of Attestation Token
[2024-08-26T05:39:24Z INFO  kbs::http::resource] Get resource from kbs:///default/key/key2
[2024-08-26T05:39:24Z INFO  kbs::http::resource] Resource access request passes policy check.
[2024-08-26T05:39:24Z INFO  actix_web::middleware::logger] 172.19.0.1 "GET /kbs/v0/resource/default/key/key2 HTTP/1.1" 200 506 "-" "attestation-agent-kbs-client/0.1.0" 0.002890

```

The trustee kbs client connects to the attestation service and makes a call for the passkey belonging to the container. Once the calls for the attestation service has been made and the message stating *Resource access request passes policy check* is shown, run ```kubectl logs {NAME OF DEPLOYED POD}``` to confirm that the passkey was received correctly.

```
$ kubectl logs pod-snp
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
Testing a key
100    14  100    14    0     0     33      0 --:--:-- --:--:-- --:--:--    33
```
After the attestation has occurred, the kubectl logs prints out the password, *Testing a key*, that was set in the key2 file. This confirms that attesation has happened and the container is secure.
