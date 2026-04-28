# Confidential Containers and Other Projects

Confidential Containers is connected to many other open source project.
Generally, Confidential Containers is a platform. CoCo can be deployed
on top of different environments (i.e. different Kubernetes distributions
and host operating systems).
Furthermore, many projects can be deployed on top of CoCo.
For example, `KServe` for confidential inferencing or `Tekton` for confidential build pipelines.
Many Kubernetes projects are not designed with confidentiality in mind.
When deploying such a project in CoCo, an admin should think carefully about
reconciling the trust models of the two projects.

CoCo also has direct dependencies.
For instance Confidential Containers relies on a CRI runtime such as `containerd` or `cri-o`.

This page is non-exhaustive, but should give an idea of the types of ways that CoCo
can integrate with other projects.

## Directly Related

These projects are central to how Confidential Containers is built and deployed. With Confidential Containers, container images are pulled inside the enclave and are essentially not present on the host.

### CNCF Projects

- **[containerd](https://containerd.io/)**: The default container runtime used by Kubernetes. containerd's pluggable image snapshotter architecture is a key dependency for Confidential Containers, enabling the custom snapshotters needed to support secure image pulling.

- **[CRI-O](https://cri-o.io/)**: An alternative container runtime for Kubernetes. Similar to containerd, CRI-O runtime support was extended to enable secure image guest pull for Confidential Containers.

- **[Nydus](https://nydus.dev/)**: Confidential Containers uses the Nydus containerd snapshotter plugin to implement secure image pulling inside the confidential guest pod, keeping image data within the trusted execution environment.

- **[Helm](https://helm.sh/)**: Confidential Containers releases are distributed as Helm charts and maintained in a dedicated charts repository, making deployment on Kubernetes clusters straightforward.

- **[Operator Framework](https://operatorframework.io/)**: CoCo subprojects such as the Trustee operator are built using the Operator Framework and publish releases via [operatorhub.io](https://operatorhub.io/).

- **[OPA](https://www.openpolicyagent.org/)**: CoCo uses Rego policies in several components.

### Non-CNCF Projects

- **[Kata Containers](https://katacontainers.io/)**: The primary runtime requirement for Confidential Containers. Kata Containers provides the ability to sandbox pods inside virtual machines, forming the foundation on which CoCo's hardware-based isolation is built.

- **[Open Container Initiative (OCI)](https://opencontainers.org/)**: Confidential Containers is one of the adopters of the drafted and proposed OCI encrypted container images specification, aligning with emerging standards for protecting image content.

- **[IETF Remote Attestation Procedures (RATS) Architecture](https://www.rfc-editor.org/rfc/rfc9334)**: The CoCo attestation architecture closely follows the IETF RATS architecture, providing a standards-based foundation for verifying the trustworthiness of confidential workloads.

- **[skopeo](https://github.com/containers/skopeo)**: A useful container image manipulation tool that developers working with Confidential Containers can use to inspect, copy, and manage encrypted or signed container images across registries.

## Workload Integrations

While just about any workload can be deployed with CoCo, the following
are projects where specific integrations have been put forward.

### Kyverno

[Kyverno](https://kyverno.io/) has policy integrations for CoCo. These can be used to automatically
set various CoCo annotations (such as Init-Data) from a config map.

### KServe

[KServe](https://kserve.github.io/website/) can be be used with CoCo to provide confidential inferencing. 
Currently you can use [modelcar](https://kserve.github.io/website/docs/model-serving/storage/providers/oci) functionality to provide signed or encrypted OCI images with model weights. You can also use custom [storage initializer](https://kserve.github.io/website/docs/model-serving/storage/storage-containers).
Additional CoCo integration via providing a default confidential-capable storage initializer implementation is work in progress.

### SPIFFE/SPIRE

The community has spent years workings on [SPIFFE and SPIRE](https://spiffe.io/) integration.
Confidential Identity is one of the most subtle concepts in confidential computing.
After several prototypes and design documents, the community is converging on an official integration.

### KubeArmor

[KubeArmor](https://www.kubearmor.io/) has provisions for runtime security based on CoCo.

## Additional Work 

These are more general integrations.

### Service Mesh

A service mesh ([Istio](https://istio.io/), [Envoy](https://www.envoyproxy.io/)) could be a good way to extend the security guarantees of Confidential Containers to the network, essentially by ensuring that traffic is encrypted prior to leaving the enclave. The service mesh would need to be configured such that the CSP could not manipulate sensitive guest network policies. In the case of Istio, the Istio Daemon has a broad authority to reconfigure networking rules. This would break the trust model of Confidential Containers.

There has been some work to integrate [Nebula](https://nebula.defined.net/docs/) to create confidential overlay networks.

### Observability 

With Confidential Containers, logs must be carefully configured to avoid exposing Confidential information to the CSP. Locking down the workload logging, monitoring, and tracing difficult. The CNCF has many projects that standardize or centralize logs. These include [Fluentd](https://www.fluentd.org/), [Jaeger](https://www.jaegertracing.io/), [Open Telemetry](https://opentelemetry.io/), [Thanos](https://thanos.io/), and [Cortex](https://cortexmetrics.io/). Perhaps one of these could be used to securely deliver confidential logs to the guest owner. More investigation is needed  

Trustee has support for Prometheus.
