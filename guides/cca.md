# Arm CCA Guide

This document explains how to build and run Confidential Containers on the Arm CCA
(Confidential Compute Architecture) platform.

Arm CCA support is **experimental** and not yet included in released CoCo/kata-containers
artifacts. There is no `kata-qemu-cca` runtime class in the [charts](https://github.com/confidential-containers/charts)
today, and CCA is not installable through the Helm-based flow described in the
[QuickStart](../quickstart.md). To try it out, you currently need to build
kata-containers with the CCA-specific kernel and hypervisor patches yourself (not yet
merged into kata-containers `main` - see Prerequisites below) and wire up the runtime
class by hand. This guide walks through that process, along with the attestation flow
and a few workarounds needed for encrypted images.

## Prerequisites

Kindly review the [Prerequisites](../quickstart.md#prerequisites) section in the `QuickStart`.

In addition:

- An Arm64 host or VM capable of running CCA Realms: either real CCA-capable hardware,
  or QEMU's CCA simulation (`machine=virt`, `cpu=max,x-rme=on`) backed by a CCA-enabled
  firmware stack (TF-A + TF-RMM + EDK2). The simulation path is what this guide's
  commands assume; on real hardware the same kata-containers/QEMU bits apply, but
  firmware setup is platform-specific.
- A QEMU build with CCA (`x-rme`) support, used as the Kata VMM. As of this writing
  that means building from the CCA branch of `git.codelinaro.org/linaro/dcap/qemu`
  (`cca/2025-05-28`) rather than a stock QEMU release.
- kata-containers built with the CCA kernel config fragment and CCA-aware
  `configuration-qemu-cca.toml`. As of this writing, these changes are not fully on
  kata-containers `main` yet:
  - [kata-containers#PR-13579](https://github.com/kata-containers/kata-containers/pull/13579)
    (open) restores the CCA experimental stack, including its own
    `configuration-qemu-cca.toml.in`. It is not yet wired into `kata-deploy`.
  - [kata-containers#PR-13438](https://github.com/kata-containers/kata-containers/pull/13438)
    (merged) added `CONFIG_CFS_BANDWIDTH=y` to the CCA kernel config
    fragment, required for cgroup v2 `cpu.max` support under Kata/CCA.
  - An earlier PR covering CCA timeouts and simulation config
    ([kata-containers#PR-13436](https://github.com/kata-containers/kata-containers/pull/13436))
    was closed in favor of PR-13579's broader restoration; PR-13579 does not yet cover
    everything PR-13436 did.
  Track [kata-containers#PR-13579](https://github.com/kata-containers/kata-containers/pull/13579)
  for current status; PR-13438 is already merged, so once PR-13579 lands, a branch
  built from kata-containers `main` will include both.

## Build kata-containers with CCA Support

Build the kata kernel with the CCA confidential kernel config fragment applied
(including the `CONFIG_CFS_BANDWIDTH=y` fix from kata-containers#PR-13438, merged,
above), and build/install the
CCA-capable QEMU described above as the hypervisor binary. Install the resulting kata
artifacts under `/opt/kata` (or your usual kata-deploy payload path) on the worker
node.

## Configure the Runtime

Since there is no packaged `kata-qemu-cca` runtime class yet, configure Kata directly
instead of relying on the Helm chart's generated config:

```bash
sudo mkdir -p /etc/kata-containers
sudo cp /opt/kata/share/defaults/kata-containers/configuration-qemu-cca.toml \
        /etc/kata-containers/configuration.toml
```

A few settings need to differ from the non-confidential defaults:

- **Shared filesystem** - CCA QEMU forces `iommu_platform=true` on all virtio devices.
  The default `virtio-fs` does not support this and QEMU will fail to start. Use
  `virtio-9p` instead:
  ```bash
  sudo sed -i 's/shared_fs = "[^"]*"/shared_fs = "virtio-9p"/' \
      /etc/kata-containers/configuration.toml
  ```
  This is the right setting for plain (non-encrypted) images, which is what the rest
  of this section assumes. If you plan to run encrypted images, see
  [Encrypted Images on CCA](#encrypted-images-on-cca) below - that flow requires a
  different `shared_fs` value and is not compatible with `virtio-9p`.
- **Guest components** - to run plain (non-attested) CCA containers without a KBS,
  disable the attestation-agent launch, otherwise kata-agent crashes before binding
  its vsock port:
  ```bash
  sudo sed -i '/^kernel_params/s/"$/ agent.guest_components_procs=none"/' \
      /etc/kata-containers/configuration.toml
  ```
  Once you configure a KBS for attestation (below), change this to
  `agent.guest_components_procs=api-server-rest` so the attestation agent, CDH, and
  the REST API server start inside the Realm.
- **Timeouts** - a CCA Realm takes noticeably longer to boot than an unattested VM,
  especially under emulation. Increase `dial_timeout` and `create_container_timeout`
  (e.g. to `1800`) to avoid spurious timeouts while the Realm is still booting.

Register a `containerd` runtime class pointing at this config, following the same
pattern as the other `kata-qemu-*` handlers in
[quickstart.md](../quickstart.md#verify-installation).

## Attestation Flow

CoCo's attestation for CCA uses the same Trustee (KBS + Attestation Service + RVPS)
stack as other platforms - see [coco-dev.md](./coco-dev.md) for the general model.
The CCA-specific sequence is:

1. kata-agent starts the attestation agent (AA), confidential data hub (CDH), and
   `api-server-rest` inside the Realm (via `agent.guest_components_procs=api-server-rest`).
2. The AA gathers CCA evidence - the RMM signing chain plus the platform and realm
   certificate chains - and calls `POST /kbs/v0/auth` then `POST /kbs/v0/attest`
   against the KBS.
3. The Attestation Service verifies the evidence and evaluates policy, returning an
   EAR token (JWT) to the KBS, which returns it to the AA.
4. Any workload inside the Realm can then fetch that token locally via
   `http://127.0.0.1:8006/aa/token?token_type=kbs`, or let the CDH use it
   transparently to unseal secrets / decrypt images.

To sanity-check the flow end-to-end, run a pod whose entrypoint requests a token from
the local `api-server-rest` endpoint and inspect its logs; you should see a token
beginning with `eyJ...` on success. Expect the first boot of a Realm to take on the
order of minutes rather than seconds, particularly in emulated/simulated CCA
environments - this is normal Realm-creation and firmware-attestation overhead, not a
hang.

## Encrypted Images on CCA

`shared_fs = "none"` and `experimental_force_guest_pull = true` are required for
encrypted image support on CCA - the host never sees decrypted image content, and
kata-agent re-pulls and decrypts each image entirely inside the Realm. This is a
different setting from the `virtio-9p` used in [Configure the Runtime](#configure-the-runtime)
above: `shared_fs` is a single global option, so `virtio-9p` and `none` are mutually
exclusive within one `configuration.toml`. Switch with:

```bash
sudo sed -i \
    -e 's/shared_fs = "[^"]*"/shared_fs = "none"/' \
    -e 's/experimental_force_guest_pull = .*/experimental_force_guest_pull = true/' \
    /etc/kata-containers/configuration.toml
```

If you need both plain (9p-shared) and encrypted (guest-pull) workloads available at
the same time, register two separate runtime classes - e.g. `kata-qemu-cca` and
`kata-qemu-cca-encrypted` - each pointing at its own `configuration.toml` with the
appropriate `shared_fs` value, rather than trying to toggle a single config back and
forth.

This works well for a single-pod `nerdctl`/`ctr` flow, but running the same setup
under Kubernetes surfaces a few gaps that are worth knowing about up front.

### containerd still needs a matching image on the host

Even with guest pull enabled, containerd calls `PullImage` on the host **before**
handing off to kata-agent. If the host's image store has no image matching the pod
spec's reference, the pod enters `ErrImagePull` before the guest ever gets a chance
to pull and decrypt it itself.

**Workaround:** import a plain (unencrypted) stub image tagged with the exact same
reference as the encrypted image into the `k8s.io` containerd namespace before
deploying the pod:

```bash
docker tag <plain-image> registry.example.com/<enc-name>:latest
docker save registry.example.com/<enc-name>:latest -o /tmp/stub.tar
sudo ctr -n k8s.io images import /tmp/stub.tar
```

containerd is satisfied by the stub's presence; the guest still pulls and decrypts
the real, encrypted layers itself.

### `coco-keyprovider` and restricted Docker sockets

`coco-keyprovider`, used to encrypt images before pushing them to a registry, may
fail against the `docker-daemon:` transport on systems with a restricted or
non-default Docker socket path. If so, go through a local OCI archive instead:

```bash
docker save <image>:<tag> -o /tmp/image.tar
skopeo copy docker-archive:/tmp/image.tar dir:/tmp/image-src
# use dir:/tmp/image-src as the source for coco-keyprovider
```

### A single `RESTARTS: 1` after token expiry is expected

If the attestation agent's cached EAR token has expired when a pod restarts, you'll
typically see this sequence:

1. Pod starts; AA presents its cached (now-expired) token; KBS returns
   `401 ExpiredSignature`.
2. kata-agent fails to mount the image; the pod enters `RunContainerError`.
3. kubelet restarts the container - `RESTARTS: 1`.
4. AA re-attests from scratch and receives a fresh token - `200 OK`.
5. Image decryption succeeds and the pod moves to `Running`.

This is expected, self-healing behavior, not a crash. Avoid force-deleting the pod
during the `RESTARTS: 1` window - it recovers on its own once re-attestation
completes. If restarts keep climbing beyond that, treat it as a real failure and see
[troubleshooting.md](./troubleshooting.md).

## Further Reading

For general CoCo debugging techniques (containerd debug logging, the Kata debug
console, reading guest firmware/console logs), see
[troubleshooting.md](./troubleshooting.md) - everything there applies to CCA Realms
as well as other platforms.
