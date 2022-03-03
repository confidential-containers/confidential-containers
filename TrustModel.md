# Trust Model for Confidential Containers
A clear definition of trust for the confidential containers project is needed to ensure the 
components and architecture deliver the security principles expected for cloud native 
confidential computing. It provides the solid foundations and unifying security principles 
against which we can assess architecture and implementation ideas and discussions.

## Trust Model Definition
The [Trust Modeling for Security Architecture Development article](https://www.informit.com/articles/article.aspx?p=31546) 
defines Trust Modeling as :

>    A trust model identifies the specific mechanisms that are necessary to respond to a specific 
>    threat profile.

>    A trust model must include implicit or explicit validation of an entity's identity or the 
>    characteristics necessary for a particular event or transaction to occur.

## Trust Boundary
 The trust model also helps determine the location and direction of the trust boundaries where a 
[trust boundary](https://en.wikipedia.org/wiki/Trust_boundary) describes a location where 
 program data or execution changes its level of "trust", or where two principals with different 
 capabilities exchange data or commands. Specific to Confidential Containers is the trust 
 boundary that corresponds to the boundary of the Trusted Execution Environment (TEE). The TEE 
 side of the trust boundary will be hardened to prevent the violation of the trust 
 boundary.

## Required Documentation
In order to describe and understand particular threats we need to establish trust boundaries and 
trust models relating to the key aspects, components and actors involved in Cloud Native 
Confidential Computing. We explore trust using different orthogonal ways of considering cloud 
native approaches when they use an underlying TEE technology and 
identifying where there may be considerations to preserve the value of using a TEE.

Further documentation will highlight specific [threat vectors](./ThreatsOverview.md) in detail, 
considering risk, 
impact, mitigation etc as the project progresses. The Security Assurance section, Page 32, of 
Cloud Native Computing Foundation (CNCF) 
[Cloud Native Security Paper](https://github.com/cncf/tag-security/blob/main/security-whitepaper/CNCF_cloud-native-security-whitepaper-Nov2020.pdf)
 will guide this more detailed threat vector effort.

### Related Prior Effort

Confidential Containers brings confidential computing into a cloud native context and should 
therefore refer to and build on trust and security models already defined.

For example: 

- Confidential Computing Consortium (CCC) published 
  "[A Technical Analysis of Confidential Computing](https://confidentialcomputing.io/wp-content/uploads/sites/85/2021/03/CCC-Tech-Analysis-Confidential-Computing-V1.pdf)" 
  section 5 of which defines the threat model for confidential computing.
- CNCF Security Technical Advisory Group published 
  "[Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/security-whitepaper/CNCF_cloud-native-security-whitepaper-Nov2020.pdf)" 
- Kubernetes provides documentation :
  "[Overview of Cloud Native Security](https://kubernetes.io/docs/concepts/security/overview/)"
- Open Web Application Security Project -
  "[Docker Security Threat Modeling](https://github.com/OWASP/Docker-Security/blob/main/001%20-%20Threats.md)"
  
The commonality between confidential containers project and confidential computing is to reduce
the ability for unauthorised access to data and code inside TEEs sufficiently such that this path 
is not an economically or logically viable attack during execution (5.1 Goal within the CCC 
publication
[A Technical Analysis of Confidential Computing](https://confidentialcomputing.io/wp-content/uploads/sites/85/2021/03/CCC-Tech-Analysis-Confidential-Computing-V1.pdf)).

This means our trust and threat modelling should 
- Focus on which aspects of code and data have integrity and/or confidentiality protections.
- Focus on enhancing existing Cloud Native models in the context of exploiting TEEs.
- Consider existing Cloud Native technologies and the role they can play for confidential containers.
- Consider additional technologies to fulfil a role in Cloud Native exploitation of TEEs.

### Out of Scope

The following items are considered out-of-scope for the trust/threat modelling within confidential 
containers : 

- Vulnerabilities within the application/code which has been requested to run inside a TEE. 
- Availability part of the Confidentiality/Integrity/Availability in CIA Triad.
- Software TEEs. At this time we are focused on hardware TEEs.
- Certain security guarantees are defined by the underlying TEE and these 
  may vary between TEEs and generations of the same TEE. We take these guarantees at face value 
  and will only highlight them where they become relevant to the trust model or threats we 
  consider. 

### Summary

In practice, those deploying workloads into TEE environments may have varying levels of trust 
in the personas who have privileges regarding orchestration or hosting the workload. This trust 
may be based on factors such as the relationship with the owner or operator of the host, the 
software and hardware it comprises, and the likelihood of physical, software, or  social 
engineering compromise.

Confidential containers will have specific focus on preventing potential security threats at 
the TEE boundary and ensure privileges which are accepted within cloud native environment as 
crossing the boundary are mitigated from threats within the boundary. We cannot allow the 
security of the TEE to be under control of operations outside the TEE or from areas not trusted 
by the TEE.
