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

## Hardware Support
Confidential Containers is tested with attestation on the following platforms:
- Intel TDX
- AMD SEV

Confidential Containers can also be run on Linux without any Confidential Computing hardware
for testing or development.

The following platforms are untested or partially supported:
- AMD SEV-ES
- IBM Z SE

The following platforms are in development:
- Intel SGX
- AMD SEV-SNP

## Limitations

Confidential Containers is still maturing. See [release notes](./releases) for currrent limitations.

# Installing

You can enable Confidential Containers in an existing Kubernetes cluster using the Confidential Containers Operator.

:information_source: If you need to quickly deploy a single-node test cluster, you can
use the [run-local.sh
script](https://github.com/confidential-containers/operator/blob/main/tests/e2e/run-local.sh)
from the operator test suite, which will setup a single-node cluster on your
machine for testing purpose.
This script requires `ansible-playbook`, which you can install on CentOS/RHEL using
`dnf install ansible-core`, and the Ansible `docker_container` module, which you can
get using `ansible-galaxy colection install community.docker`.

:information_source: You can also use a Kind or Minikube cluster with containerd runtime to try out the CoCo stack
for development purposes.

## Prerequisites

- Ensure a minimum of 8GB RAM and 2 vCPU for the Kubernetes cluster node
- Only containerd runtime based Kubernetes clusters are supported with the current CoCo release
- The minimum Kubernetes version should be 1.24
- Ensure at least one Kubernetes node in the cluster is having the label `node-role.kubernetes.io/worker=`


For more details on the operator, including the custom resources managed by the operator, refer to the operator [docs](https://github.com/confidential-containers/operator)

## Operator Installation

### Deploy the the operator

```
kubectl apply -f https://raw.githubusercontent.com/confidential-containers/operator/main/deploy/deploy.yaml
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

# Running a workload

## Creating a sample CoCo workload

Once you've used the operator to install Confidential Containers, you can run a pod with CoCo by simply adding a runtime class.
First, we will use the `kata` runtime class which uses CoCo wihout hardware support.
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

## Creating a CoCo workload using a pre-existing encrypted image

We will now proceed to download and run a sample encrypted container image using the CoCo building blocks.

A demo container image is provided at [docker.io/katadocker/ccv0-ssh](https://hub.docker.com/r/katadocker/ccv0-ssh).
It is encrypted with [Attestation Agent](https://github.com/confidential-containers/attestation-agent)'s [offline file system key broker](https://github.com/confidential-containers/attestation-agent/tree/64c12fbecfe90ba974d5fe4896bf997308df298d/src/kbc_modules/offline_fs_kbc) and [`aa-offline_fs_kbc-keys.json`](https://github.com/confidential-containers/documentation/blob/main/demos/ssh-demo/aa-offline_fs_kbc-keys.json) as its key file.

We have prepared a sample CoCo operator custom resource that is based on the standard `ccruntime.yaml`, but in addition has the the decryption keys and configuration required to decrypt this sample container image.
> **Note**: All pods started with this sample resource will be able to decrypt the sample container and all keys shown are for demo purposes only and should not be used in production.

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

`kata-qemu-sev`
Export cert chain
Start KBS (even for unencrypted)

Use the sample image or an unencrypted image


## Building a new encrypted container image and deploying it as a CoCo workload

* *TBD: instructions to build encrypted container image and other requirements (attestation, key etc)* *

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

**Note:** The communication between Verdictd and EAA KBC is based on rats-tls,
so you need to confirm that [rats-tls](https://github.com/inclavare-containers/rats-tls) has been correctly installed in your running environment.

3. Agent Configuration

Add configuration `aa_kbc_params= 'eaa_kbc::<$IP>:<$PORT>'` to agent config file, the IP and PORT should be consistent with verdictd.

### Use offline SEV KBC and simple-kbs (SEV)

TODO: add instructions for simple-kbs with encrypted images

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

