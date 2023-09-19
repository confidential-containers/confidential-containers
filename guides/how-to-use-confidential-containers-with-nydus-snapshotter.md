# How to Use Confidential Containers with Nydus Snapshotter
This document provides an overview on how to run Confidential Containers with [Nydus Snapshotter](https://github.com/containerd/nydus-snapshotter). 

## Introduction
Confidential Containers (CoCo) protects data in Trusted Execution Environment (TEE) by pulling images in the guest with forked containerd.
To optimize resource usage and avoid the need for forking containerd while enabling image pulls within the guest, we employ the Nydus Snapshotter as a proxy plugin. 
This external plugin for containerd offers two modes: one for sharing images on the host with data integrity, and the other for pulling images within the guest. 
See [Image management proposal](https://github.com/confidential-containers/confidential-containers/issues/137) for detailed design.

## Requirements
- Confidential Containers
- Nydus Snapshotter
- Vanilla Containerd

## Install Confidential Containers

Follow [How to build, run and test Kata CCv0
](https://github.com/kata-containers/kata-containers/blob/CCv0/docs/how-to/how-to-build-and-test-ccv0.md) or [Operator Installation](https://github.com/confidential-containers/operator/blob/main/docs/INSTALL.md) to install and configure Confidential Containers.

## Install Vanilla Containerd

```bash
export containerd_tarball_url="https://github.com/containerd/containerd/releases/download"
export containerd_tarball_version="v1.7.0"
export containerd_version=${containerd_tarball_version#v}
export containerd_tarball_name="containerd-${containerd_version}-${CONTAINERD_OS}-${CONTAINERD_ARCH}.tar.gz"
export containerd_tarball_url="${tarball_url}/${containerd_tarball_version}/${tarball_name}"
tmp_dir=$(mktemp -d -t install-vanilla-containerd-tmp.XXXXXXXXXX)
curl -OL -f "${containerd_tarball_url}
sudo tar -xvf "${containerd_tarball_name}" -C $tmp_dir/
systemctl stop containerd
sudo install -D -m 755 "$tmp_dir/bin/containerd" "/usr/local/bin/containerd"
systemctl restart containerd
```

## Install and configure Nydus Snapshotter

### Install Nydus Snapshotter
Because upstream currently only provides the nydus-snapshotter tarball for x86_64 platform. Therefore, for non-x86_64 platforms, the binary can only be obtained through source code compilation. 
- install from tarball (for x86_64):
```bash
export nydus_snapshotter_version="v0.13.0"
export nydus_snapshotter_repo="https://github.com/containerd/nydus-snapshotter"
export nydus_snapshotter_tarball_url="${nydus_snapshotter_repo}/releases/download/${nydus_version}/nydus-snapshotter-${nydus_snapshotter_version}-x86_64.tgz
tmp_dir=$(mktemp -d -t install-nydus-snapshotter-tmp.XXXXXXXXXX)
sudo curl -Ls "${nydus_snapshotter_tarball_url}" | sudo tar xfz - -C ${tmp_dir} --strip-components=1
sudo install -D -m 755 "${tmp_dir}/containerd-nydus-grpc" "/usr/local/bin/"
sudo install -D -m 755 "${tmp_dir}/nydus-overlayfs" "/usr/local/bin/"
"
```

- install from source codes (for all platforms):
```bash
export ARCH="$(uname -m)"
export GOARCH=$(case "$ARCH" in
		aarch64) echo "arm64";;
		ppc64le) echo "ppc64le";;
		x86_64) echo "amd64";;
		s390x) echo "s390x";;
	esac)
export nydus_snapshotter_version="v0.13.0"
export nydus_snapshotter_repo="https://github.com/containerd/nydus-snapshotter"
export nydus_snapshotter_repo_dir="${GOPATH}/src/${nydus_snapshotter_repo}"

sudo mkdir -p "${nydus_snapshotter_repo_dir}"
sudo git clone ${nydus_snapshotter_repo_git} "${nydus_snapshotter_repo_dir}" || true
pushd "${nydus_snapshotter_repo_dir}"
sudo git checkout "${nydus_snapshotter_version}"
sudo -E PATH=$PATH:$GOPATH/bin make
sudo install -D -m 755 "bin/containerd-nydus-grpc" "/usr/local/bin/containerd-nydus-grpc"
sudo install -D -m 755 "bin/nydus-overlayfs" "/usr/local/bin/nydus-overlayfs"
popd
```

### Install Nydus Snapshotter config files
```bash
sudo curl -L https://raw.githubusercontent.com/containerd/nydus-snapshotter/main/misc/snapshotter/config-coco-guest-pulling.toml -o "/usr/local/share/config-coco-guest-pulling.toml"
sudo curl -L https://raw.githubusercontent.com/containerd/nydus-snapshotter/main/misc/snapshotter/config-coco-host-sharing.toml -o "/usr/local/share/config-coco-host-sharing.toml"
```

### Install nydus-image (only for sharing images on the host)
For sharing images on the host, we need `nydus-image` binary to convert oci images to tar files. 
>**Note:**: Currently the nydus-image can not work on s390x platform.
```bash
export ARCH="$(uname -m)"
export GOARCH=$(case "$ARCH" in
		aarch64) echo "arm64";;
		ppc64le) echo "ppc64le";;
		x86_64) echo "amd64";;
	esac)
export nydus_repo=${nydus_repo:-"https://github.com/dragonflyoss/image-service"}
export nydus_version=${nydus_version:-"v2.3.0-alpha.0"}
export nydus_tarball_url="${nydus_repo}/releases/download/${nydus_version}/nydus-static-${nydus_version}-linux-$goarch.tgz"
tmp_dir=$(mktemp -d -t install-nydus-tmp.XXXXXXXXXX)
sudo curl -Ls "${nydus_tarball_url}" | sudo tar xfz - -C ${tmp_dir} --strip-components=1
sudo install -D -m 755 "${tmp_dir}/nydus-image" "/usr/local/bin/"
```

### Configure Containerd for Nydus Snapshotter
- set snapshotter plugin in containerd config file (default path of the config file is /etc/containerd/config.toml)
```toml
[proxy_plugins]
  [proxy_plugins.nydus]
    type = "snapshot"
    address = "/run/containerd-nydus/containerd-nydus-grpc.sock"
```
- enable passing annotations to remote snapshotter
  
1. containerd config version 1:
```toml
[plugins.cri]
  [plugins.cri.containerd]
    snapshotter = "nydus"
    disable_snapshot_annotations = false
```

2. containerd config version 2:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd]
   snapshotter = "nydus"
   disable_snapshot_annotations = false
```

## Run

### Run Nydus Snapshotter
- For image sharing on the host:
```bash
/usr/local/bin/containerd-nydus-grpc --config /usr/local/share/config-coco-host-sharing.toml >/dev/stdout 2>&1 &
```
- For image pulling in the guest:
```
/usr/local/bin/containerd-nydus-grpc --config /usr/local/share/config-coco-guest-pulling.toml >/dev/stdout 2>&1 &
```

### Run pod
- Create an pod configuration
```bash
$ cat > pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  runtimeClassName: kata
  containers:
  - name: busybox
    image: quay.io/library/busybox:latest
```

- Create the pod
  ```bash
  $ sudo -E kubectl apply -f pod.yaml
  ```

- Check pod is running

  ```bash
  $ sudo -E kubectl get pods
  ```

