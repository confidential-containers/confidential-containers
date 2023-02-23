---
name: New project release
about: Checklist for the coming project's release
title: "[Release] Check list for v<TARGET_RELEASE>"
labels: ''
assignees: ''
---

# v<TARGET_RELEASE>

## Code freeze

- [ ] - 1. Update image-rs to use the latest commit from ocicrypt-rs
        
        * https://github.com/confidential-containers/image-rs/blob/main/Cargo.toml
          * Change the revision
          * Run `cargo update -p ocicrypt-rs`

- [ ] - 2. Update image-rs to use the latest commit from attestation-agent

        * https://github.com/confidential-containers/image-rs/blob/main/Cargo.toml
          * Change the revision
          * Run `cargo update -p attestation_agent`

- [ ] - 3. Update Enclave CC to use the latest commit from image-rs

        * https://github.com/confidential-containers/enclave-cc/blob/main/src/enclave-agent/Cargo.toml
          * Change the revision
          * Run `cargo update -p image-rs`
        Note that you can point to your own fork here, so you don't actually do changes in the other projects
        before making sure this step works as expected.

- [ ] - 4. Update Kata Containers to use the latest commit from image-rs

        * https://github.com/kata-containers/kata-containers/blob/CCv0/src/agent/Cargo.toml
          * Change the revision
          * Run `cargo update -p image-rs`
        Note that you can point to your own fork here, so you don't actually do changes in the other projects
        before making sure this step works as expected.

- [ ] - 5. Update Kata Containers to use the latest attestation-agent

        * https://github.com/kata-containers/kata-containers/blob/CCv0/versions.yaml
          * Change the version

- [ ] - 6. Update Kata Containers to use the latest td-shim

        * https://github.com/kata-containers/kata-containers/blob/CCv0/versions.yaml
          * Change the version

- [ ] - 7. Check if there are new changes in the pre install payload script

        * https://github.com/confidential-containers/operator/tree/main/install/pre-install-payload
          * The last commit there must match what's in the following files as preInstall / postUninstall image
            * Enclave CC: https://github.com/confidential-containers/operator/blob/main/config/samples/enclave-cc/base/ccruntime-enclave-cc.yaml
            * Kata Containers:
              Note that for Kata Containers, we're looking for the newTag, below the quay.io/confidential-containers/container-engine-for-cc-payload image
              * s390x: https://github.com/confidential-containers/operator/blob/main/config/samples/ccruntime/s390x/kustomization.yaml
              * x86_64: https://github.com/confidential-containers/operator/blob/main/config/samples/ccruntime/default/kustomization.yaml

- [ ] - 8. Ensure the Operator is using the latest CI builds and that the Operator tests are passsing

        * Enclave CC:
          * SIM: https://github.com/confidential-containers/operator/blob/main/config/samples/enclave-cc/sim/kustomization.yaml
          * HW: https://github.com/confidential-containers/operator/blob/main/config/samples/enclave-cc/base/ccruntime-enclave-cc.yaml
          * Note that we need the quay.io/confidential-containers/runtime-payload-ci registry and enclave-cc-{SIM,HW}-latest tags
        * Kata Containers:
          * s390x: https://github.com/confidential-containers/operator/blob/main/config/samples/ccruntime/s390x/kustomization.yaml
          * x86_64: https://github.com/confidential-containers/operator/blob/main/config/samples/ccruntime/default/kustomization.yaml
          Note that we need the quay.io/confidential-containers/runtime-payload-ci registry and kata-containers-latest tag

- [ ] - 9. Cut an ocicrypt-rs v<TARGET_RELEASE> release, if changes happened in the project

- [ ] - 10. Cut an attestation-agent v<TARGET_RELEASE>, if changes happened in the project

- [ ] - 11. Cut an image-rs v<TARGET_RELEASE> release, using the latest release of:

        * ocicrypt-rs (redo step 1, but now using v<TARGET_RELEASE>)
        * attestation-agent (redo step 2, but now using v<TARGET_RELEASE>)

- [ ] - 12. Cut a td-shim v<TARGET_RELEASE> release, if changes happened in the project

- [ ] - 13. Update Enclave CC to use the released version of image-rs

        * redo step 3, but now using v<TARGET_RELEASE>

- [ ] - 14. Update Kata Containers to the latest released version of:

        * image-rs (redo step 4, but now using the v<TARGET_RELEASE>)
        * attestation-agent (redo step 5, but now using the v<TARGET_RELEASE>)
        * td-shim (redo step 6, but now using the v<TARGET_RELEASE>)

- [ ] - 15. Update the operator to use the images generated from the latest commit of both Kata Containers and Enclave CC

        * redo step 8, but now targetting the latest payload image generated for Kata Containers and Enclave CC

- [ ] - 16. Make sure all the operator tests are passing

- [ ] - 17. Cut an Enclave CC release

- [ ] - 18. Add a new Kata Containers tag

## Release

- [ ] - 19. Update the operator to use the release tags coming from Enclave CC and Kata Containers

        * redo step 8, but now targetting thje latest release of the payload image generated for Kata Containers eand Enclave CC

- [ ] - 20. Update the Operator version

        * https://github.com/confidential-containers/operator/blob/main/config/release/kustomization.yaml#L7

- [ ] - 21. Cut an operator release

- [ ] - 22. Make sure to update the release notes

        * https://github.com/confidential-containers/documentation/tree/main/releases/v<TARGET_RELEASE>.md
        
- [ ] - 23. Poke Jens Freimann (jfreiman@redhat.com) to update the release to the OperatorHub
