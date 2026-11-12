# RFC: Persistent Confidential Volumes for CoCo

## Summary

Today a CoCo pod can protect its container images and its scratch space, but it cannot keep data across restarts without exposing that data to the host. This RFC proposes **persistent confidential volumes**: block volumes whose key and plaintext never leave the attested guest, used through an ordinary PVC and `volumeMount`, on both bare-metal Kata and Peer Pods.

Several people have already built parts of this in different directions. This RFC tries to bring that work together rather than start from scratch. It does three things:

1. It states the requirements we share, and splits the problem into five parts (section 1).
2. It compares the existing work, and proposes a choice for the two parts where the options differ most: how the disk reaches the guest, and what the disk looks like (section 2).
3. It lists the work as items that become sub-issues, grouped into two milestones (section 3).

### Terms used in this RFC

- **Guest**: the confidential VM that runs the pod. **Host**: everything outside it, which we do not trust.
- **PVC** and **CSI driver**: in Kubernetes a pod asks for storage with a PersistentVolumeClaim (PVC). A CSI driver is the plugin that creates and attaches the real disk. **Backing CSI** means the driver the user already runs, such as Ceph, Longhorn or EBS.
- **CDH** (Confidential Data Hub): the CoCo component inside the guest that handles secrets and encrypted storage.
- **Trustee / KBS**: the CoCo service that verifies attestation and releases keys to the guest.
- **DAV** (Direct-Assigned Volume): a Kata feature that hands a block device to the guest together with a small JSON file, `mountInfo`, so that the guest (not the host) mounts it.
- **Peer Pods**: the pod VM runs as a separate cloud VM, created by cloud-api-adaptor (CAA).
- **LUKS2**, **dm-integrity**, **dm-verity**: standard Linux tools for disk encryption, integrity of writable disks, and integrity of read-only disks.

## 1. Background and Requirements

### 1.1 Where we are today

CoCo already protects two kinds of storage: container images pulled inside the guest ([#123](https://github.com/confidential-containers/confidential-containers/issues/123)), and ephemeral volumes such as `emptyDir` ([#247](https://github.com/confidential-containers/confidential-containers/issues/247)). In the current implementation, both use CDH to encrypt a block device inside the guest with a key that is thrown away, so the data disappears with the pod.

This is fine for scratch data, but not for databases, model weights or checkpoints. For persistent data, users have a few choices today, and each gives something up:

- Share a host directory into the guest with virtio-fs. The host then sees every file in plaintext, and CoCo configurations disable this by default (`shared_fs = none`).
- Build your own custom solution with sidecar helpers, custom podvm image etc. This works, but every user builds it again, and the platform (for example agent policy) cannot see or check it.
- Wait for platform support. Users on bare-metal TDX and SEV-SNP have asked for it ([kata-containers#13638](https://github.com/kata-containers/kata-containers/issues/13638)). Today the agent can only ask CDH to create a new ephemeral volume. It cannot ask CDH to open an existing disk with a given key.

### 1.2 Requirements

1. **Key and plaintext stay in the guest.** The host only sees ciphertext. The key comes from Trustee after attestation, and never passes through the host, the CSI driver or any Kubernetes object.
2. **Integrity, not only encryption.** Both the data and the metadata that says how to open the disk must be authenticated. The [Trail of Bits analysis of LUKS2 in confidential VMs](https://blog.trailofbits.com/2025/10/30/vulnerabilities-in-luks2-disk-encryption-for-confidential-vms/) shows what can go wrong otherwise.
3. **Fail closed.** If a disk that should hold data fails to open, it is never treated as blank and formatted.
4. **Pre-provision and dynamic provision.** *Pre-provision*: a user prepares and seals a disk in advance with a tool. *Dynamic provision*: the storage backend creates an empty disk, and the first pod that uses it initializes it inside the guest. In both cases the host never formats or encrypts anything.
5. **Transparent to the application.** The workload sees a normal filesystem. No sidecar and no application change.
6. **Same on bare-metal Kata and Peer Pods**, ideally with the same bytes on disk.
7. **No patch per storage backend.** There are too many CSI drivers to change them one by one.
8. **The host cannot add volumes to a pod.** What a pod may mount must be checked by something the guest trusts, such as agent policy.

### 1.3 Non-goals

- **Rollback and freshness.** A malicious host can replace a volume with an older copy that is still valid. Detecting this needs state kept outside the disk, which could fit naturally with a KBS plugin. It is **not covered in this issue**, and will be handled in the attestation sub-issue (3.8).
- **Read-write-many and writer fencing.** Volumes have a single writer. Kubernetes access modes are enforced outside the guest, so a malicious host could attach one disk to two guests. We protect confidentiality and detect tampering, but we cannot guarantee availability.
- **Online resize and snapshots.** Later work.
- **Key lifecycle** (create, rotate, revoke). This belongs to Trustee. We only need a way to refer to a key.
- **Non-block storage** such as NFS and SMB.

### 1.4 How we split the problem

It helps to look at persistent confidential storage as five black boxes, each with a clear input and output.

```text
                  +-------------------+
  Pod, PVC  ----> | A. Delivery       | --- block device + volume description ---+
                  +-------------------+                                          |
                                                                                 v
                  +-------------------+                                 +------------------+
  volume    ----> | B. Format         | --- bytes on the disk --------> | C. Guest opener  | --> filesystem
  settings        +-------------------+                                 |   (CDH + agent)  |     in the container
                                                                        +------------------+
                  +-------------------+                                    ^           ^
                  | D. Trust          | ----------- key -------------------+           |
                  +-------------------+                                                |
                  +-------------------+                                                |
                  | E. Admission and  | ----------- rules -----------------------------+
                  |    policy         |
                  +-------------------+
```

| Box | Input → output | Status in this RFC |
|---|---|---|
| **A. Delivery** | Kubernetes objects → a block device plus a non-secret *volume description* inside the guest | Proposal in 2.2 |
| **B. Format** | Volume settings → bytes on the disk, and a tool to create and inspect them | Proposal in 2.3 |
| **C. Guest opener** | Device + description + key → a mounted filesystem (CDH and kata-agent) | To implement. The *volume description* is the contract between A, B and C |
| **D. Trust** | Attestation evidence → key release. Also key management and rollback protection | Later, in its own sub-issue (3.8) |
| **E. Admission and policy** | Rules for what a pod may mount, and whether a volume may be created or only opened | Later, in milestone 2 (section 3) |

A and B are the two questions presented to the community, because they decide the **major** engineering directions. They are not the whole architecture. C is where A and B meet, so it is the shared piece of work. D and E are cross-cutting: their design is mostly independent of the choices for A and B, although some details will depend on them.

A and B are also independent of each other. Any delivery mechanism can carry any format, as long as the volume description is well defined.

## 2. Related Work and Options

### 2.1 Related work

| Work                                                                                                                                                                                                                                                                                                                                                                                                          | Summary                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **DAV** in Kata ([design](https://github.com/kata-containers/kata-containers/blob/main/docs/design/direct-blk-device-assignment.md)), with the reference driver [`csi-kata-directvolume`](https://github.com/kata-containers/kata-containers/tree/main/src/tools/csi-kata-directvolume)                                                                                                                       | A CSI driver (or `kata-ctl direct-volume add`) writes a `mountInfo.json`, and Kata mounts the device inside the guest. It is the main Kata channel today for passing per-volume information from host to agent, so several of the options below build on it.                                                                                                                                               |
| **Confidential persistent block storage** by @noeljackson ([kata-containers#13638](https://github.com/kata-containers/kata-containers/issues/13638), [#13795](https://github.com/kata-containers/kata-containers/pull/13795), [guest-components#1648](https://github.com/confidential-containers/guest-components/pull/1648), [#1715](https://github.com/confidential-containers/guest-components/pull/1715)) | The user declares the volume in a pod annotation, genpolicy puts it into the measured agent policy, and CDH opens the disk with a manifest and key from Trustee. It shares the guest-side work (box C) with this RFC and already covers much of box E. It differs on box A (a pod annotation instead of a CRD) and on box B (the information on how to open the disk is kept in Trustee, not on the disk). |
| **Block passthrough via webhook** by @rophy ([kata-containers#12842](https://github.com/kata-containers/kata-containers/issues/12842))                                                                                                                                                                                                                                                                        | A webhook turns a filesystem PVC into a block PVC and rewrites `volumeMounts` into `volumeDevices`. It works with unchanged CSI drivers.                                                                                                                                                                                                                                                                   |
| **Kata prototypes** by @manuelh-dev ([CRD](https://github.com/manuelh-dev/kata-containers/tree/mahuber/csi-kata-crd-prototype), [annotation](https://github.com/manuelh-dev/kata-containers/tree/prototype/runtime-rs-volume-device-mount))                                                                                                                                                                   | Working prototypes of two delivery options in Kata. The CRD prototype is the expected starting point for 3.2, and the annotation prototype shows that the annotation route needs little code.                                                                                                                                                                                                              |
| **Peer Pods CSI** by @bpradipt and @mohammedadnan21 ([`caa-csi-block-driver`](https://github.com/confidential-devhub/caa-csi-block-driver), [#378](https://github.com/confidential-containers/confidential-containers/issues/378), CAA [#3155](https://github.com/confidential-containers/cloud-api-adaptor/pull/3155))                                                                                       | Creates cloud disks and attaches them to peer pod VMs, with LUKS support through CDH already in CAA. Peer Pods must create disks through the cloud API, so it needs its own driver. A move into the CoCo organization has been proposed.                                                                                                                                                                   |
| **confidential-disk-format** ([repo](https://github.com/Xynnn007/confidential-disk-format))                                                                                                                                                                                                                                                                                                                   | A survey of existing disk formats, a draft Confidential Disk Format (CDF), a library, a CLI and a demo CSI driver. Input for box B.                                                                                                                                                                                                                                                                        |
| **Sidecar setups** in downstream products. Experience shared from @burgerdev, @magowan, @Rohit-Singh43-1 and @SantoshMadhukar-K                                                                                                                                                                                                                                                                               | A helper container that opens dm-crypt or dm-verity. It works today, but is built per workload.                                                                                                                                                                                                                                                                                                            |

### 2.2 Delivery options (box A)

Delivery is how a block device, together with a non-secret description of it, gets into the guest. We compared the options at the Oct 22 community meeting ([recording](https://zoom.us/rec/share/bSpEh191Wj1wpx2WyS-ZzEu66EjRqJqv6Ssk5JDJyyXPBVYTLIZS4K7_YKYBlu0.1aPzf-63LbiTc3j9), [slides](https://docs.google.com/presentation/d/1sJDtpXXZNiIo2b4snRsR99o_pj6PI3XigPw-fwdEZac/edit)). All options end in the same guest-side path (box C). They only differ in how the disk and its description arrive.

| Option | How it works | Main drawback |
|---|---|---|
| **Per-CSI adapter** | Each existing CSI driver is changed to skip the host mount and write a `mountInfo` for Kata (for example [longhorn-manager#5090](https://github.com/longhorn/longhorn-manager/pull/5090)). | Every driver needs its own change, which does not scale. |
| **New confidential CSI** | One new CSI driver creates the disk itself and writes the `mountInfo`. | It has to support disk creation for every storage backend. (It is still the right answer for Peer Pods, where disks come from the cloud API.) |
| **Annotation** | The user provides a block PVC and writes the mount details into a pod annotation. Kata reads the annotation. | Users write a JSON value by hand, there is no hook for volume lifecycle events, and annotations are hard to manage at scale. |
| **Webhook rewrite** | A webhook automatically turns a filesystem PVC into a block PVC, rewrites `volumeMount` into `volumeDevice`, and adds the annotation. | The pod that runs differs from what the user wrote (for example in `fsGroup` behavior), which makes problems harder to debug. |
| **CRD (proposed)** | The user keeps a normal block PVC from the backing CSI. A `KataVolume` object links it to a second PVC that the pod mounts. A webhook adds the block PVC to the pod, and a small driver writes the `mountInfo` when the volume is published. | We need to maintain a CRD, a webhook, a small driver and some runtime-rs changes. |

**Proposal: use the CRD.** We think it gives the best balance: no storage driver has to change, users do not write JSON, volume lifecycle events are kept, and the webhook only adds the backing volume instead of rewriting what the user wrote. The annotation route is not excluded and can live in the same repository, because the guest side does not care which one produced the description.

On Peer Pods, the Peer Pods CSI stays the backing driver: it creates and attaches the cloud disk, and the CRD sits on top and adds the description.

### 2.3 Format options (box B)

The format decides what is on the disk. It should describe itself (profile, size, key location hint, where the header is), support writable and read-only volumes with integrity, work with any delivery option, and come with a tool to create and inspect volumes.

- **LUKS2 with a policy token.** LUKS2 is the whole image. A token in the LUKS2 header carries an HMAC and the settings. The guest checks the HMAC with a key from the KBS.
- **Confidential Disk Format (CDF).** A GPT partition table holds a small *contract* partition, stored in cleartext but authenticated with a MAC (volume ID, profile, generation, optional key hint), and the data partitions. Encrypted data is stored as LUKS2 with a detached header, and read-only volumes get an extra dm-verity partition. Only this outer layout is new.

| | LUKS2 token | Confidential Disk Format (CDF) |
|---|---|---|
| Open metadata is authenticated | Yes (HMAC in the token) | Yes (MAC over the contract) |
| Resists header replacement | Yes (detached header) | Yes (detached header named in the contract) |
| Clear meaning | Weaker: a volume without encryption still looks like LUKS | Stronger: finding the parts, the contract and the data are separate layers |
| Read-only volumes (dm-verity) | Awkward | Natural |
| Size and complexity | Smaller, simpler for CDH | Extra partitions and a GPT parser |
| Performance and user experience | About the same | About the same |

**Proposal: use the Confidential Disk Format (CDF).** Its layers are clearer, it supports read-only volumes naturally (which matters for protecting model weights), and the disk describes itself through an authenticated contract. The cost is somewhat more code than LUKS2 alone, which we think is acceptable. We also propose that the volume description passed to CDH carries a version, so that CDH can support other formats later if needed.

### 2.4 Proposed direction

- **Delivery**: DAV as the channel, with a `KataVolume` CRD that produces the `mountInfo`.
- **Format**: the Confidential Disk Format (CDF), with a tool to create and inspect volumes.
- **Guest side**: one CDH implementation, shared by every delivery option.
- **Drivers**: `csi-kata-directvolume` stays a Kata reference driver, and CoCo gets its own reference driver in the new repository.
- **Order**: two milestones, described in section 3.

## 3. Roadmap

The work is split into the items below. Each item becomes its own sub-issue. The two milestones after the list say what is delivered when.

### Work items

- [ ] **3.1 Kata: DAV interface and tests.** Improve the DAV interface, the reference driver `csi-kata-directvolume` and their test coverage, first for ordinary (not yet confidential) volumes.
- [ ] **3.2** `KataVolume` **CRD in Kata.** Land the CRD, the webhook, the small driver and the runtime-rs support in Kata, first for ordinary (not yet confidential) volumes.
- [ ] **3.3 Confidential Disk Format: definition and tools.** The specification, plus a library and a CLI to create and inspect volumes.
- [ ] **3.4 CDH: format support and interface changes.** Open an existing volume and initialize a new one, through a versioned interface.
- [ ] **3.5** `KataVolume` **CRD: confidential support.** Add the confidential settings (profile, key location) to the CRD.
- [ ] **3.6 Peer Pods CSI integration.** Make the Peer Pods CSI use the same volume description and format as bare metal.
- [ ] **3.7 CI for confidential volumes in Kata.** Cover both pre-provision and dynamic provision.
- [ ] **3.8 CDH and Trustee: attestable design.** Not expanded here. It also covers rollback and freshness protection. It has its own sub-issue and does not belong to the milestones below.

For item 3.3, 3.6 (and probably 3.5), it's proposed to have a new confidential storage code repository under confidential-containers org.

### Milestones

**Milestone 1: the full flow without admission and policy, with CI.**
A user can run a pod with a persistent confidential volume, on bare-metal Kata and on Peer Pods, with both pre-provisioned and dynamically provisioned volumes, and CI shows that it works (Peer Pods tests run in the cloud-api-adaptor pipeline).

This covers 3.1 to 3.7, without box E (admission and policy). 

At this stage the guest does not yet stop a malicious host from adding a volume to a pod or swapping in a blank disk. A disk that fails to open is still never formatted.

**Milestone 2: the full flow with admission and policy, with CI.**
Adds box E: agent policy rules for the new volume type, binding each volume to its pod and mount path, the choice between "open existing" and "create from empty", and optional checking of the expected volume ID.

CI adds the matching negative tests: a volume added by the host is rejected, and a blank disk swapped in is not initialized as a new volume.

## Acknowledgements

This RFC builds on ideas, prototypes and reviews from many people in the CoCo and Kata communities. Thanks to (in alphabetical order) @bpradipt, @burgerdev, @EmmEff, @fidencio, @fitzthum, @kailun-qin, @magowan, @manuelh-dev, @mateo-moon, @mkulke, @mohammedadnan21, @mythi, @noeljackson, @Rohit-Singh43-1, @rophy, @SantoshMadhukar-K, @snir911, @sprt, and @stevenhorsman.

## References

Community discussion

- Storage solution from IBM on s390x, community meeting on Oct 29, 2026 [recording](https://zoom.us/rec/share/YzI982HQRLAxdh6N1NtMUS7xoaU893NB5_h1T72TNupvoDApqfa2bQjCwL0bJjSl.WMPQqEHd1bDsbNrI)
- Persistent Confidential Volumes for CoCo, community meeting on Oct 22, 2026 [slides](https://docs.google.com/presentation/d/1sJDtpXXZNiIo2b4snRsR99o_pj6PI3XigPw-fwdEZac/edit?hl=zh-cn&slide=id.p#slide=id.p) and [recording](https://zoom.us/rec/share/bSpEh191Wj1wpx2WyS-ZzEu66EjRqJqv6Ssk5JDJyyXPBVYTLIZS4K7_YKYBlu0.1aPzf-63LbiTc3j9)
- Storage Discussion on CoCo meeting Oct 15, 2026 [recording](https://zoom.us/rec/share/tnmomoMX0T9Ir03C0yW0X_sUXu0QfCchMJAFLuYbP5osBbEC8rH2qDXTz63j5p_j.R8ZVAn4ayo0cxLYV)

Existing CoCo storage work

- [confidential-containers#123](https://github.com/confidential-containers/confidential-containers/issues/123): [RFC] Trusted storage proposal for CoCo
- [confidential-containers#247](https://github.com/confidential-containers/confidential-containers/issues/247): [RFC] Trusted Ephemeral Data Storage for CoCo

Kata Containers

- [Direct-Assigned Volume design](https://github.com/kata-containers/kata-containers/blob/main/docs/design/direct-blk-device-assignment.md)
- [`csi-kata-directvolume`](https://github.com/kata-containers/kata-containers/tree/main/src/tools/csi-kata-directvolume): reference CSI driver for DAV
- [kata-containers#14208](https://github.com/kata-containers/kata-containers/pull/14208): tests: extend direct-volume DAV test coverage
- [kata-containers#12842](https://github.com/kata-containers/kata-containers/issues/12842): Proposal: block volume passthrough via admission webhook
- [kata-containers#14179](https://github.com/kata-containers/kata-containers/pull/14179): RFC: propose composing Initdata from CRDs
- Kata delivery prototypes: [CRD](https://github.com/manuelh-dev/kata-containers/tree/mahuber/csi-kata-crd-prototype), [annotation](https://github.com/manuelh-dev/kata-containers/tree/prototype/runtime-rs-volume-device-mount)

Confidential persistent block storage

- [kata-containers#13638](https://github.com/kata-containers/kata-containers/issues/13638): [RFC] Confidential persistent block storage
- [kata-containers#13795](https://github.com/kata-containers/kata-containers/pull/13795): docs: propose confidential persistent storage for Kata
- [guest-components#1648](https://github.com/confidential-containers/guest-components/pull/1648): cdh: add crash-safe persistent LUKS volumes
- [guest-components#1715](https://github.com/confidential-containers/guest-components/pull/1715): cdh: propose confidential persistent volumes
- [longhorn-manager#5090](https://github.com/longhorn/longhorn-manager/pull/5090): feat(csi): add Kata confidential direct volumes

Peer Pods

- [`caa-csi-block-driver`](https://github.com/confidential-devhub/caa-csi-block-driver): CSI block driver for cloud-api-adaptor
- [confidential-containers#378](https://github.com/confidential-containers/confidential-containers/issues/378): New repo creation for CSI block driver for cloud-api-adaptor
- [cloud-api-adaptor#3155](https://github.com/confidential-containers/cloud-api-adaptor/pull/3155): Add LUKS encryption support for cloud volumes via CDH

Disk format

- [confidential-disk-format](https://github.com/Xynnn007/confidential-disk-format): survey of existing formats and the draft Confidential Disk Format (CDF)
- [Vulnerabilities in LUKS2 disk encryption for confidential VMs](https://blog.trailofbits.com/2025/10/30/vulnerabilities-in-luks2-disk-encryption-for-confidential-vms/), Trail of Bits, Oct 2025
