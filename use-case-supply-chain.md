# Secure Supply Chain

A trusted CI/CD pipeline prevents malicious code from infiltrating the software and ensures that the software can be traced and verified.

- Compliance Frameworks require Software Bill Of Materials (SBOM)
  - What was the OCI Image was built from?
- Confidential Computing requires a way to verify the OCI Images being used. (Signatures, Encrypted Layers etc.)
  - Is this the OCI Image I am looking for?

Being able to be able to verify the image is not sufficient for Confidential Computing if we do not trust the environment in which the evidence for verification was created.

**Can we ever have a Confidential Computing Environment if we do not trust the environment in which the application has been built?** 

## What environment was used to 
- Build the OCI Images?
- Define/Generate the SBOM we later use to inform our choice of Image?
- Sign or encrypt the Image?



## We need to use CoCo to establish a Secure Supply Chain.
- To ensure the SBOM accurately reflects how the OCI Image was built
- No ability to tamper with the build
- To protect the keys used to establish signatures or encrypt the Images.
- To make the signatures, keys, SBOMs available for use/audit purposes later.

## But considering OCI Images is not enough our Supply chain also includes:
- AI Use Cases woule include training Data and AI Models
- CoCo VM (with SBOM)
- Attestation Measurements to verify the CoCo VM
- Generation and protection of Keys/Secrets/Policies/Configuration
- Trustee (KBS/Attestation) and Remote Verification Services
- Potentially updates to Firmware for the TEE in use.

### One of the key considerations for the confidential containers project is
- Transparent deployment of unmodified containers

For a Secure Supply Chain it is reasonable to conclude that in order to build the unmodified containers we should start by considered pre-existing CI/CD systems which can be deployed within a Kubernetes Environment. Such systems could be deployed to Confidential Containers with CI/CD system then securely building, signing, encrypting unmodified containers and SBOMs. One such CI/CD system being investigated is [Tekton](https://tekton.dev/docs/) 

## Bootstrap Problem
This Use Case needs to consider how to solve the bootstrap problem.
- How can we use a CoCo VM to securely build a CoCo VM?


