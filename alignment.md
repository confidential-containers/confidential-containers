# Confidential Containers and Other Projects

Confidential Containers are connected to a wide array of projects. Some projects are directly implicated in the design of Confidential Containers. Others might be a good pairing for Confidential Containers, and others might be transparently supported or consumed by or via Confidential Containers. If work needs to be done to align a project with Confidential Containers, it will generally involve reconciling the strict trust model of Confidential Containers and the tradional cloud native trust model.

## Directly Related

These projects are central to how Confidential Containers is built and deployed. With Confidential Containers, container images are pulled inside the enclave and are essentially not present on the host.

### CNCF Projects

- **[containerd](https://containerd.io/)**: The default container runtime used by Kubernetes. containerd's pluggable image snapshotter architecture is a key dependency for Confidential Containers, enabling the custom snapshotters needed to support secure image pulling.

- **[CRI-O](https://cri-o.io/)**: An alternative container runtime for Kubernetes. Similar to containerd, CRI-O runtime support was extended to enable secure image guest pull for Confidential Containers.

- **[Nydus](https://nydus.dev/)**: Confidential Containers uses the Nydus containerd snapshotter plugin to implement secure image pulling inside the confidential guest pod, keeping image data within the trusted execution environment.

- **[Helm](https://helm.sh/)**: Confidential Containers releases are distributed as Helm charts and maintained in a dedicated charts repository, making deployment on Kubernetes clusters straightforward.

- **[Operator Framework](https://operatorframework.io/)**: CoCo subprojects such as the Trustee operator are built using the Operator Framework and publish releases via [operatorhub.io](https://operatorhub.io/).

### Non-CNCF Projects

- **[Kata Containers](https://katacontainers.io/)**: The primary runtime requirement for Confidential Containers. Kata Containers provides the ability to sandbox pods inside virtual machines, forming the foundation on which CoCo's hardware-based isolation is built.

- **[Open Container Initiative (OCI)](https://opencontainers.org/)**: Confidential Containers is one of the adopters of the drafted and proposed OCI encrypted container images specification, aligning with emerging standards for protecting image content.

- **[IETF Remote Attestation Procedures (RATS) Architecture](https://www.rfc-editor.org/rfc/rfc9334)**: The CoCo attestation architecture closely follows the IETF RATS architecture, providing a standards-based foundation for verifying the trustworthiness of confidential workloads.

- **[skopeo](https://github.com/containers/skopeo)**: A useful container image manipulation tool that developers working with Confidential Containers can use to inspect, copy, and manage encrypted or signed container images across registries.

## Potentially Related

These projects might pair nicely with Confidential Containers, but are not required.

### SPIFFE/SPIRE

[SPIFFE and SPIRE](https://spiffe.io/) can be used to assign a provable identity to every workload. With some adjustments this might be a good way to deliver secrets to confidential containers or even the containers themselves. The attestation process would most likely have to be linked to platform-specific hardware attestation, perhaps in conjunction with the Attestation Agent. The SPIRE agent would need to be moved inside the enclave and the SPIRE server could not be provided by the Cloud Service Provider (CSP). Further investigation is encouraged.

### Service Mesh

A service mesh ([Istio](https://istio.io/), [Envoy](https://www.envoyproxy.io/)) could be a good way to extend the security guarantees of Confidential Containers to the network, essentially by ensuring that traffic is encrypted prior to leaving the enclave. The service mesh would need to be configured such that the CSP could not manipulate sensitive guest network policies. In the case of Istio, the Istio Daemon has a broad authority to reconfigure networking rules. This would break the trust model of Confidential Containers.

### Observability 

With Confidential Containers, logs must be carefully configured to avoid exposing Confidential information to the CSP. Locking down the workload logging, monitoring, and tracing difficult. The CNCF has many projects that standardize or centralize logs. These include [Fluentd](https://www.fluentd.org/), [Jaeger](https://www.jaegertracing.io/), [Open Telemetry](https://opentelemetry.io/), [Thanos](https://thanos.io/), and [Cortex](https://cortexmetrics.io/). Perhaps one of these could be used to securely deliver confidential logs to the guest owner. More investigation is needed  

## Consumable

Since Confidential Containers are a drop-in replacement for traditional containers, Confidential Containers should be able to consume or support a wide range of container-related projects including container registries like [Harbor](https://goharbor.io/) or [Dragonfly](https://d7y.io/). Tools for defining applications or creating build pipelines should work with minimal modification. Of course any services that can be deployed as containers should also work as Confidential Containers with new security properties.
