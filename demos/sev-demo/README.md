# CCv0 with AMD SEV

CCv0 can be used with AMD SEV. Check out this [demo video](https://youtu.be/SXZ-hzhjahU) to see it in action. This guide explains how to take an SEV node and use CCv0 with it. This guide does not cover configuring an SEV machine. You need to have a node where you can start SEV VMs. This guide also does not cover setting up CCv0. You need a working deployment of CCv0. You will update this deployment to use SEV. 
Soon many of these steps will be automated via [Kata Deploy](https://github.com/kata-containers/kata-containers/tree/main/tools/packaging/kata-deploy) and the [Confidential Containers Operator](https://github.com/confidential-containers/operator).

## OVMF

You will need to use OVMF. Specifically, you will need to use the `AmdSev` build of OVMF. An appropriate [firmware binary](https://github.com/confidential-containers-demo/bin/blob/main/ccv0-sev/latest/OVMF.fd) is available.
The provided binary is built from commit `f0f3f5aae7c4d346ea5e24970936d80dc5b60657` and has md5 checksum `bc40de8b6e743e03b3912de64e7d4884`. Any release after [edk2-stable202108](https://github.com/tianocore/edk2/releases/tag/edk2-stable202108) should work.

You can also build from source. This is optional. To do so, first clone the source and checkout the submodules.
```
git clone https://github.com/tianocore/edk2.git
cd edk2 
git submodule init
git submodule update
```
Setup the build tools.
```
make -C BaseTools/
source edksetup.sh
```
Currently the `AmdSev` firmware expects to be built with Grub for reasons unrelated to Confidential Containers. Since Kata uses direct boot instead, you don't need to build Grub, but you will need to create a dummy Grub file located at `OvmfPkg/AmdSev/Grub/grub.efi`
```
touch OvmfPkg/AmdSev/Grub/grub.efi
```
Now you can build the `AmdSev` firmware. The output binary will be located at `Build/AmdSev/DEBUG_GCC5/FV/OVMF.fd`.
```
build -t GCC5 -a X64 -p OvmfPkg/AmdSev/AmdSevX64.dsc
```


Update the Kata configuration file to point to your new firmware. You'll need to do this if you built your own firmware or used the provided firmware. The configuration file is usually located at `/etc/kata-containers/configuration.toml`. QEMU's default firmware does not support SEV with secret injection and measured direct boot. 
```
# Path to the firmware.
# If you want that qemu uses the default firmware leave this option empty
firmware = "/<path-to-fw>/OVMF.fd"
```

## Rootfs and Kernel
 
Create the rootfs as you normally would for CCv0, but set `AA_KBC` to `offline_sev_kbc` so that the Attestation Agent is built with the correct key broker client. 

```
sudo make USE_DOCKER=yes DISTRO=ubuntu AGENT_INIT=yes DOCKER_RUNTIME=runc AA_KBC=offline_sev_kbc SKOPEO_UMOCI=yes rootfs
```

You will need to add the agent configuration file to the initrd. Again, this is a typical CCv0 requirement, but you will need to specify parameters for your KBC. Specifically be sure to add this parameter.
```
aa_kbc_params = "offline_sev_kbc::null"
```

The `offline_sev_kbc` uses the `efi_secret` kernel module to expose injected secrets to the filesystem. You'll need to add the kernel module to the initrd. You can do this by setting the `KERNEL_MODULES_DIR` when you build your rootfs or you can copy the kernel module directly into the rootfs that is created. Either way, your rootfs should look something like this. 
```
$ tree ubuntu_rootfs/lib/modules
lib/modules
└── 5.15.0-rc5+
    ├── kernel
    │   └── drivers
    │       └── virt
    │           └── coco
    │               └── efi_secret
    │                   └── efi_secret.ko
    ├── modules.alias
    ├── modules.alias.bin
    ├── modules.builtin
    ├── modules.builtin.alias.bin
    ├── modules.builtin.bin
    ├── modules.builtin.modinfo
    ├── modules.dep
    ├── modules.dep.bin
    ├── modules.devname
    ├── modules.order
    ├── modules.softdep
    ├── modules.symbols
    └── modules.symbols.bin
```

Make sure that the module matches your kernel version. Speaking of which, `efi_secret` also requires some minor kernel patches. These patches and the module are not currently upstream. You can find the v6 patch [here](https://lore.kernel.org/lkml/20211129114251.3741721-1-dovmurik@linux.ibm.com/T/) and a tree containing the v6 patch [here](https://github.com/confidential-containers-demo/linux/tree/conf-comp-secret-v6).

Assuming some x86_64 base config file, you can build a kernel and module like so. 
```
cp some-base-config .config
./scripts/config --enable CONFIG_AMD_MEM_ENCRYPT
./scripts/config --enable AMD_MEM_ENCRYPT_ACTIVE_BY_DEFAULT
./scripts/config --enable CONFIG_SECURITYFS
./scripts/config --enable CONFIG_VIRT_DRIVERS
./scripts/config --module CONFIG_EFI_SECRET
make olddefconfig

DIR=/path/to/linux-guest-kernel
make -j $(($(nproc)-1))
make INSTALL_PATH=$DIR install
make -j16 INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$DIR modules_install
```

Once you generate an initrd from the updated rootfs, update your Kata configuration file to point to the new initrd. You will also need to update the kernel field in the configuration file to point to your new kernel. For CCv0 you should have already added `agent.config_file=<agent-config-path>` to the `kernel_params` field. 

## Kata Runtime

Since SEV and SEV-ES use pre-attestation driven from outside of the guest, some changes are required for the Kata shim. These changes are not currently upstream. You will need to build your Kata shim with [this PR](https://github.com/kata-containers/kata-containers/pull/3025). 
You will also need a few changes to `govmm`. For now the easiest way to get them is via [this tree](https://github.com/confidential-containers-demo/govmm/tree/sev-attestation).
This will work best with QEMU 6.2.0rc0 given that newer version of QEMU will expect to find the `kernel-hashes=on` flag, which is not currently set by the shim. See [here](https://www.mail-archive.com/qemu-devel@nongnu.org/msg851132.html) for details.

You will also need to set the following parameters in the Kata configuration file.

First, you'll need to enable SEV via the `confidential_guest` parameter.
```
# Enable confidential guest support.
# Toggling that setting may trigger different hardware features, ranging
# from memory encryption to both memory and CPU-state encryption and integrity.
# The Kata Containers runtime dynamically detects the available feature set and
# aims at enabling the largest possible one.
# Default false
confidential_guest = true
```

Next you'll need to enable (pre-)attestation.
```
# Enable guest attestation
# (default: false)
guest_attestation=true
#
# Guest owner proxy that handles remote attestation
guest_attestation_proxy="localhost:50051"
#
# Preattestation keyset ID for injected secrets
guest_attestation_keyset="KEYSET-1"
```
Here, we are specifying a local KBS. You can also run the KBS remotely. For this demo we specify the `keyset` in the configuration file. In the future this will be overridden via a Kubernetes annotation. The `keyset` parameter will be described more below. For now, you can just leave it set to `KEYSET-1`. 

Finally, switch from `virtio-fs` to `virtio-9p`. The former is not currently compatible with SEV. 
```
# Shared file system type:
#   - virtio-fs (default)
#   - virtio-9p
shared_fs = "virtio-9p"
```

## KBS 

You can use the `offline_sev_kbc` manually by injecting a specially formatted JSON file, but you will probably want to use our [key broker server](https://github.com/confidential-containers-demo/scripts/tree/main/guest-owner-proxy) instead. 
Note that the SEV KBS is often referred to as a Guest Owner Proxy (GOP). This was our original terminology. 
First, install `gop-client.py` on the worker node by placing the file at `/opt/sev/guest-owner-proxy/gop-client.py`. You should check the `gop-client.py` file and make sure that the `hw_api_major`, `hw_api_minor`, and `hw_build_id` match the parameters reported by the AMD-SP. 
You can verify these parameters using [SEV-Tool](https://github.com/AMDESE/sev-tool). These parameters will be set automatically in the future and the functionality of `gop-client.py` may be added to the Kata runtime.

You can run `gop-server.py` wherever you would like, just make sure that `guest_attestation_proxy` is set accordingly, e.g. `guest_attestation_proxy="localhost:50051"`. 
`gop-server.py` requires [SEV-Tool](https://github.com/AMDESE/sev-tool). By default `gop-server.py` expects the `sevtool` binary to be in the same directory, but this is configurable via `sevtool_path` variable.

The KBS is configured using two files. First, `keys.json` stores the keys that the KBS can send to a guest. Generating these keys is described below. There is also a file called `keysets.json` which defines groups of keys and the policies that correspond to their release. Since the `offline_sev_kbc` is an offline KBC, keys cannot be request individually at runtime. Instead, all the keys that are needed for the duration of the guest need to be provided at boot. Thus, we use a keyset to group keys into one bundle that is injected. 

We can step through the `keysets.json` file.
```
{
   "KEYSET-1":{
```
Currently we are hard--coding our `keyset` in the Kata configuration file (see above) to match `KEYSET-1` specified here. 
```
      "allowed_digests":[
         "a11cc9f32b3e64a0846b5eadf773e5e4ee7b4187d984b7a72a3b4fc99e34374c",
         "dcf332c8abb68cc534d7f1e523ffe9e072308e0d92dc98e3884b313caaea379b"
      ],
```
Firmware digests that are allowed for this `keyset`. You can calculate a firmware digest using the `calculate_hash.py` tool. Be sure to specify the correct, kernel, initrd, firmware, and kernel parameters. These will be included in the hash (this is an extension of the original SEV behavior). 
You should have the path to these components in your kata configuration file. Do not use the kernel parameters field from the configuration file, though, because it only contains additional parameters rather than the full command line. The easiest way to get the full kernel parameters is to start a container with Kata and then check the QEMU arguments via `journalctl -xe -u containerd` or `dmesg | grep qemu`.
Note that viewing the kernel command line from inside the guest via `cat /proc/cmdline` might not accurately reflect the firmware's view of the kernel commandline, which is what the measurement is based on.  
```
      "allowed_keys":[
         "key_id1"
      ],
```
This should correspond to the key in `keys.json`.
```
      "allowed-policies":[
         0
      ],
      "min-api-major":0,
      "min-api-minor":0,
      "allowed-build-ids":[
         13
      ]
```
These parameters should be familiar if you have launched any SEV guests before. Note that you can set multiple allowed policies or allowed build IDs for each `keyset`.
```
   }
}
```

Once you have the KBS/GOP configuration files setup, simply run the KBS. Note that you can start the KBS with the `-u` flag to skip verification of the measurement. This can be useful for debugging. 

## Preparing an image 

Finally, it's time to prepare an image. You can use the `offline_fs_kbs` sample KBS as a keyprovider. It is compatible with `offline_sev_kbc`. See the [README](https://github.com/confidential-containers/attestation-agent/blob/main/sample_kbs/src/enc_mods/offline_fs_kbs/README.md) for guidance. We will use `skopeo` (which uses `ocicrypt`) to encrypt each layer of our image. Rather than specify a fixed encryption key, we specify the KBS as the keyprovider. The KBS will wrap each layer encryption key. These will later be unwrapped by the KBC in the guest. You should end up using a `skopeo` command that looks something like this. 
```
OCICRYPT_KEYPROVIDER_CONFIG=ocicrypt.conf skopeo copy docker://docker.io/<username>/<some-container>:unencrypted docker://docker.io/<username>/<some-container>:encrypted --encryption-key provider:attestation-agent:keys.json:key_id1
```
Make sure the sample KBS is running per the linked instructions. You may need to run `skopeo login`. `key_id1` in `keys.json` is exactly the key that needs to be added to `keys.json` in the KBS directory.

## Conclusion

To recap, you will need to make configuration changes to almost every component. Specifically, 
* OVMF - You need the `AmdSev` firmware build.
* Kernel - You need a kernel with `efi_secret` patches.
* Initrd - You need the `efi_secret` module, the AA built with `offline_sev_kbc`, and an agent config file with the correct KBC.
* Shim - You need a PR for the shim and a number of configuration file changes.
* KBS - You need to provision `keys.json` and `keysets.json` and install the `gop-client`. 
* Image - You need to encrypt and image using the sample KBS

Make sure that you have updated the Kata configuration file to point to your new firmware, kernel, and initrd.
