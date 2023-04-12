# Troubleshooting

Confidential Containers integrates several components. If you run into problems,
it can sometimes be difficult to figure out what is going on or how to move forward.
Here are some tips.

If you get stuck or find a bug, please make an issue on this repository or
the repository for the component in question, e.g.,
[the operator](https://github.com/confidential-containers/operator/issues).

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

#### failed to create shim task: failed to mount "/run/kata-containers/shared/containers/CONTAINER_NAME/rootfs"

If your CoCo Pod gets an error like showed below then it is likely the image pull policy is set to **IfNotPresent** and the image has been found in the kubelet cache. It fails because the container runtime will not delegate to the Kata agent to pull the image inside the VM and the agent in turn will try to mount the bundle rootfs that only exist in the host filesystem.

Therefore, you must ensure that the image pull policy is set to **Always** for any CoCo Pod. This ways the images are always handled entirely by the agent inside the VM. Worth mentioning we recognize that this behavior is suboptimal and so the community has worked on solutions to avoid constant images downloads for each and every workload.

```
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  20s               default-scheduler  Successfully assigned default/coco-fedora-69d9f84cd7-j597j to virtlab1012
  Normal   Pulled     5s (x3 over 19s)  kubelet            Container image "docker.io/wainersm/coco-fedora_sshd@sha256:a7108f9f0080c429beb66e2cf0abff143c9eb9c7cf4dcde3241bc56c938d33b9" already present on machine
  Normal   Created    5s (x3 over 19s)  kubelet            Created container coco-fedora
  Warning  Failed     5s (x3 over 19s)  kubelet            Error: failed to create containerd task: failed to create shim task: failed to mount "/run/kata-containers/shared/containers/coco-fedora/rootfs" to "/run/kata-containers/coco-fedora/rootfs", with error: ENOENT: No such file or directory: unknown
  Warning  BackOff    4s (x3 over 18s)  kubelet            Back-off restarting failed container
```

#### Debug Console

One very useful deugging tool is the Kata guest debug console. You can
enable this by editing the Kata agent configuration file and adding the lines
``` toml
debug_console = true
debug_console_vport = 1026
```

Enabling the debug console via the Kata Configuration file will overwrite
any settings in the agent configuration file in the guest initrd.
Enabling the debug console will change the launch measurement.

Once you've started a pod with the new configuration, get the id of the pod
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
