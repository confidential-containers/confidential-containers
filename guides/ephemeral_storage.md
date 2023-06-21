# Trusted Ephemeral Storage for container images

With CoCo, container images are pulled inside the guest VM.
By default container images are saved in guest memory which is protected by CC hardware.
Since memory is an expensive resource, CoCo implemented [trusted ephemeral storage](https://github.com/confidential-containers/documentation/issues/39) for container image and RW layer.

This solution is verified with Kubernetes CSI driver [open-local](https://github.com/alibaba/open-local). Please follow this [user guide](https://github.com/alibaba/open-local/blob/main/docs/user-guide/user-guide.md) to install open-local.

We can use following example `trusted_store_cc.yaml` to have a try:
```yaml
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
```sh
kubectl apply -f trusted_store_cc.yaml
```

Ensure the pod was created successfully (in running state):
```sh
kubectl get pods
```

Output:
```
NAME                READY   STATUS    RESTARTS   AGE
trusted-lvm-block   2/2     Running   0          31s
```

After we enable the debug option, we can login into the VM with `ccv0.sh` script:
```sh
./ccv0.sh -d open_kata_shell
```

Check container image is saved in encrypted storage with following commands:
```sh
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
