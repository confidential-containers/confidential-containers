# Confidential Containers Adopters

This page contains a list of organizations/companies and projects/products who use confidential containers as adopters in different usage levels (development, beta, production, GA etc...)

**NOTE:** For adding your organization/company and project/product to this table (alphabetical order) fork the repository and open a PR with the required change.
See list of adopter types at the bottom of this page.

## Adopters

| Organization/Company                                              | Project/Product                                               | Usage level              | Adopter type                     | Details                                                                   |
|-------------------------------------------------------------------|---------------------------------------------------------------|--------------------------|----------------------------------|---------------------------------------------------------------------------|
|[Alibaba Cloud (Aliyun)](https://www.alibabacloud.com/)| [Elastic Algorithm Service](https://www.alibabacloud.com/help/en/pai/user-guide/eas-model-serving/?spm=a2c63.p38356.0.0.2b2b6679Pjozxy) and [Elastic GPU Service](https://www.alibabacloud.com/help/en/egs/) | Beta | Service Provider | Both services use sub-projects of confidential containers to protect the user data and AI model from being exposed to CSP (For details mading.ma@alibaba-inc.com) |
| [Edgeless Systems](https://www.edgeless.systems/)                 | [Contrast](https://github.com/edgelesssys/contrast)           | Beta                     | Service Provider / Consultancy   | Contrast runs confidential container deployments on Kubernetes at scale.                                |
| [IBM](https://www.ibm.com/z)                                    | [IBM LinuxONE](https://www.ibm.com/linuxone)                  | Beta                     | Service Provider                 | Confidential Containers with Red Hat OpenShift Container Platform and IBM® Secure Execution for Linux (see [details](https://www.ibm.com/blog/confidential-containers-with-red-hat-openshift-container-platform-and-ibm-secure-execution-for-linux/))  |
|NanhuLab|Trusted Big Data Sharing System |Beta |Service Provider |The system uses confidential containers to ensure that data users can utilize the data without being able to view the raw data.(No official website yet. For details: yzc@nanhulab.ac.cn) |
| [KubeArmor](https://www.kubearmor.io/) | Runtime Security | Beta | Another project | An open source project that leverages CoCo as part of their solution, integrates with for compatibility and interoperability, or is used in the supply chain of another project [(5GSEC)](https://github.com/5GSEC/nimbus/blob/main/examples/clusterscoped/coco-workload-si-sib.yaml). |
| [Red Hat](https://www.redhat.com/en) | [OpenShift confidential containers](https://www.redhat.com/en/blog/learn-about-confidential-containers) | Beta | Service Provider | Confidential Containers are available from [OpenShift sandboxed containers release version 1.7.0](https://docs.redhat.com/en/documentation/openshift_sandboxed_containers/1.7/) as a tech preview on Azure cloud for both Intel TDX and AMD SEV-SNP. The tech preview also includes support for confidential containers on IBM Z and LinuxONE using Secure Execution for Linux (IBM SEL).|
| [ByteDance](https://www.bytedance.com/) | Jeddak Sandbox | Beta | End-User / Service Provider | Jeddak Sandbox leverages CoCo to protect the data privacy in the process of the company's business  (for details chendian.imtyrant@bytedance.com) |
| [Intel](https://www.intel.com/) | [Enterprise-RAG](https://github.com/opea-project/Enterprise-RAG/blob/main/docs/tdx.md)<br>[OPEA](https://github.com/opea-project/GenAIInfra/tree/main/helm-charts/TDX.md) | Beta | End-User / Service Provider | Intel runs confidential container deployments on Kubernetes with Intel TDX |
| [Switchboard](https://www.switchboard.xyz/) | [Decentralized Crypto Oracle](https://docs.switchboard.xyz/) | Production | Service Provider | Running our Decentralized Oracles code in CoCo on AMD SEV SNP bare metal machines |
|[JDCloud](https://www.jdcloud.com)|JoyScale |Beta |End-User / Service Provider  | JoyScale leverages CoCo to protect the AI data privacy in the process of the company's business and end user. (For details: huoqifeng1@jd.com)|
|[Kubermatic](https://www.kubermatic.com/)| Kubeone | Beta | Service Provider / Consultancy | Running confidential containers on baremetal kubeone clusters. |
|TBD| | | | |
|TBD| | | | |

## Adopter types

See CNCF [definition of an adopter](https://github.com/cncf/toc/blob/main/FAQ.md#what-is-the-definition-of-an-adopter) <br>

Any single company can fall under several categories at once in which case it should enumerate all that apply and only be listed once
- **End-User** (CNCF member) - Companies and organizations who are End-User members of the CNCF
- **Another project** - an open source project that leverages a CNCF project as part of their solution, integrates with for compatibility and interoperability,
  or is used in the supply chain of another project
- **end users** (non CNCF member)- companies and organizations that are not CNCF End-User members that use the project and cloud native technologies internally, or build upon
  a cloud native open source project but do not sell the cloud native project externally as a service offering (those are Service Providers). This group is identified in the written
  form by the convention end user, uncapitalized and unhyphenated
- **Service Provider** - a Service Provider is an organization that repackages an open source project as a core component of a service offering, sells cloud native services externally.
  A Service Provider’s customers are considered transitive adopters and should be excluded from identification within the ADOPTERS.md file.
  Examples of Service Providers (and not end users) include cloud providers (e.g., Alibaba Cloud, AWS, Google Cloud, Microsoft Azure), some infrastructure software vendors,
  and telecom operators (e.g., AT&T, China Mobile)
- **Consultancy** - an entity whose purpose is to assist other organizations in developing a solution leveraging cloud native technology. They may be embedded in the end user team and
  is responsible for the execution of the service. Service Providers may also provide consultancy services, they may also package cloud native technologies for reuse
  as part of their offerings. These function as proxies for an end user
