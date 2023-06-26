# IBM Secure Execution Guide

Confidential Containers supports IBM Secure Execution.

This guide covers platform-specific setup for Secure Execution and walks through how to deploy/verify it.

## Prerequisite

### Platform Setup

> To be replaced with a link when a document in kata containers is ready

To leverage the IBM Secure Execution capability, the host machine on which you intend
to run workloads must be an IBM z15 (or a newer model) or an IBM LinuxONE III (or a newer
model). In addition to the hardware requirement, you need to verify the CPU facility and
kernel configuration, as outlined below:

```
$ # To check the protected virtualization support from kernel
$ grep -q 'prot_virt=1' /etc/zipl.conf && echo "found" || echo "not found"
found
$ # To check if an ultravior reserves a memory for the current boot
$ dmesg | grep -i ultravisor
[    0.063630] prot_virt.f9efb6: Reserving 98MB as ultravisor base storage
$ # To check a facility bit for Secure Execution
$ cat /proc/cpuinfo | grep 158
facilities      :  ... numbers ... 158 ... numbers ...
```

If any of the results are not identifiable, please reach out to the responsible cloud
provider to enable the secure execution capability. Alternatively, if you possess
administrative privileges and the facility bit is set, you can enable the Secure Execution
capability by configuring `prot_virt=1` and performing a system reboot with:

```
$ sudo sed -i 's/^\(parameters.*\)/\1 prot_virt=1/g' /etc/zipl.conf
$ sudo zipl -V
$ sudo systemctl reboot
```

### Genprotimg Tool

> To be replaced with a link when a document in kata containers is ready

`genprotimg` is a utility designed to generate an IBM Secure Execution image. It can be
installed either from the package manager of a distribution or from the source code.
The tool is included in the `s390-tools` package. Please ensure that you have a version
of the tool equal to or greater than `2.17.0`. If not, you will need to specify an
additional argument, `--x-pcf '0xe0'`, when running the command. Here is an example
of a native build from the source:

```
$ tool_version=v2.25.0
$ git clone -b $tool_version https://github.com/ibm-s390-linux/s390-tools.git && cd s390-tools
$ pushd genprotimg && pushd boot && make
$ popd && pushd src && make
$ popd && sudo make install && popd
```

### Host Key Document

> To be replaced with a link when a document in kata containers is ready

A host key document is a public key employed for encrypting a secure image, which is
subsequently decrypted using a corresponding private key during the VM bootstrap process.
You can obtain the host key document either through IBM's designated
[resource link](http://www.ibm.com/servers/resourcelink) or by requesting it from the
cloud provider responsible for the IBM Z and LinuxONE instances where your workloads are intended to run.

## Deployment

It is important to note that a secure image, deployable via a confidential containers
(referred to as CC hereafter) operator, is linked to a specific host key document.
This linkage imposes significant constraints on users desiring to test a Secure Excution-enabled
container from a released operator and ccruntime.

The subsequent sections provide detailed instructions on how users can locally construct
their own CC operator/runtime and deploy a Secure Execution-enabled CC container.

### Build CC Runtime

It is assumed that you have already set up your own local container registry with port
5000 accessible. To initiate the build process of the ccruntime, please issue the
following commands from the kata containers 
[project](https://github.com/kata-containers/kata-containers):

```
$ mkdir $GOPATH/src/github.com/kata-containers
$ cd $GOPATH/src/github.com/kata-containers
$ git clone https://github.com/kata-containers/kata-containers.git
$ cd kata-containers
$ # It is assume that you place a host key document at the location below
$ host_key_document=$HOME/host-key-document/HKD-0000-0000000.crt
$ mkdir hkd_dir && cp $host_key_document hkd_dir
$ # kernel and rootfs-initrd are built automactially by the command below
$ sudo -E PATH=$PATH TEE_TYPE=se HKD_PATH=hkd_dir SE_KERNEL_PARAMS="agent.log=debug" \
make boot-image-se-tarball
$ sudo -E PATH=$PATH make qemu-tarball
$ sudo -E PATH=$PATH make virtiofsd-tarball
$ # shim-v2 should be built after kernel due to dependency
$ sudo -E PATH=$PATH make shim-v2-tarball
$ mkdir kata-artifacts
$ build_dir=$(readlink -f build)
$ sudo cp -r $build_dir/*.tar.xz kata-artifacts
$ sudo chown -R $(id -u):$(id -g) kata-artifacts
$ ./tools/packaging/kata-deploy/local-build/kata-deploy-merge-builds.sh kata-artifacts
$ ./tools/packaging/kata-deploy/local-build/kata-deploy-build-and-upload-payload.sh \
kata-static.tar.xz "localhost:5000/runtime-payload" "kata-containers-s390x"
```

If a rootfs-image is required for testing purposes without Secure Execution functionality,
it is necessary to enter the following command before running 
`kata-deploy-merge-builds.sh`:

```
$ sudo -E PATH=$PATH make rootfs-image-tarball
```

At this point, the image for ccruntime can be accessed at 
`localhost:5000/runtime-payload:kata-containers-s390x`.

### Build CC operator

Building an operator from the upstream 
[repository](https://github.com/confidential-containers/operator) is 
a straightforward process:

```
$ mkdir -p $HOME/go/src/github.com/confidential-containers
$ cd $HOME/go/src/github.com/confidential-containers
$ git clone https://github.com/confidential-containers/operator.git && cd operator
$ export IMG=localhost:5000/cc-operator
$ make docker-build && make docker-push
```

### Deploy Operator and CC Runtime

Assuming you already have a running k8s cluster, we can proceed to deploy a confidential
container utilizing the CC operator/runtime in your local registry:

```
$ cd $HOME/go/src/github.com/confidential-containers/operator
$ sed -i "s~\(.*newName: \).*~\1${IMG}~g" config/manager/kustomization.yaml
$ kubectl apply -k config/default
namespace/confidential-containers-system created
customresourcedefinition.apiextensions.k8s.io/ccruntimes.confidentialcontainers.org created
serviceaccount/cc-operator-controller-manager created
role.rbac.authorization.k8s.io/cc-operator-leader-election-role created
clusterrole.rbac.authorization.k8s.io/cc-operator-manager-role created
clusterrole.rbac.authorization.k8s.io/cc-operator-metrics-reader created
clusterrole.rbac.authorization.k8s.io/cc-operator-proxy-role created
rolebinding.rbac.authorization.k8s.io/cc-operator-leader-election-rolebinding created
clusterrolebinding.rbac.authorization.k8s.io/cc-operator-manager-rolebinding created
clusterrolebinding.rbac.authorization.k8s.io/cc-operator-proxy-rolebinding created
configmap/cc-operator-manager-config created
service/cc-operator-controller-manager-metrics-service created
deployment.apps/cc-operator-controller-manager created
$ kubectl get po -n confidential-containers-system
NAME                                             READY   STATUS    RESTARTS   AGE
cc-operator-controller-manager-ccbbcfdf7-vgrpj   2/2     Running   0          55s
$ kubectl create -k config/samples/ccruntime/s390x
ccruntime.confidentialcontainers.org/ccruntime-sample-s390x created
$ kubectl get po -n confidential-containers-system
NAME                                             READY   STATUS    RESTARTS   AGE
cc-operator-controller-manager-ccbbcfdf7-vgrpj   2/2     Running   0          2m4s
cc-operator-daemon-install-45wzn                 1/1     Running   0          23s
cc-operator-pre-install-daemon-8nts9             1/1     Running   0          25s
$ kubectl get runtimeclass
NAME           HANDLER        AGE
kata           kata           37s
kata-qemu      kata-qemu      37s
kata-qemu-se   kata-qemu-se   37s
```

## Verification

The verification process is as follows:

```
$ cat <<EOF | kubectl apply -f -
> apiVersion: v1
> kind: Pod
> metadata:
>   name: nginx-kata
> spec:
>   runtimeClassName: kata-qemu-se
>   containers:
>   - name: nginx
>     image: nginx
> EOF
pod/nginx-kata created
$ kubectl get po
NAME         READY   STATUS    RESTARTS   AGE
nginx-kata   1/1     Running   0          15s
```
