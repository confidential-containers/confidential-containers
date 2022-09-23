# Confidential Containers and Other Projects

Confidential Containers are connected to a wide array of projects. Some projects are directly implicated in the design of Confidential Containers. Others might be a good pairing for Confidential Containers, and others might be transparently supported or consumed by or via Confidential Containers. If work needs to be done to align a project with Confidential Containers, it will generally involve reconciling the strict trust model of Confidential Containers and the tradional cloud native trust model.

## Directly Related

Given that Confidential Containers are deployed via containerd/cri-o and Kubernetes, these projects are directly implicated. With Confidential Containers, container images are pulled inside the enclave and are essentially not present on the host. Some changes will be needed higher up the stack to accommodate this. Work is already ongoing in at least one of these communities (containerd) to support Confidential Containers.

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
