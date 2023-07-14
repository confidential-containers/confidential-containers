---
name: New project release
about: Checklist for the coming project's release
title: "[Release] Check list for v<TARGET_RELEASE>"
labels: ''
assignees: ''
---

# v<TARGET_RELEASE>

## Code freeze

1. - [ ] Update Enclave CC to use the latest commit from image-rs

    * https://github.com/confidential-containers/enclave-cc/blob/main/src/enclave-agent/Cargo.toml
      * Change the revision
      * Run `cargo update -p image-rs`
        Note that you can point to your own fork here, so you don't actually do changes in the other projects
        before making sure this step works as expected.

2. - [ ] Update Kata Containers to use the latest commit from image-rs, attestation-agent and td-shim

    * image-rs
      * https://github.com/kata-containers/kata-containers/blob/CCv0/src/agent/Cargo.toml
      * Change the revision
      * Run `cargo update -p image-rs`
          Note that you can point to your own fork here, so you don't actually do changes in the other projects
          before making sure this step works as expected.
    * attestation-agent and td-shim
      * https://github.com/kata-containers/kata-containers/blob/CCv0/versions.yaml
        * Change the version

3. - [ ] Wait for kata-runtime-payload-ci to be successfully built
    * After the previous PR is merged wait for the kata-runtime-payload-ci (https://github.com/kata-containers/kata-containers/actions/workflows/cc-payload-after-push.yaml) has completed, so the latest kata-runtime-payload-ci contains the changes

4. - [ ] Check if there are new changes in the pre install payload script

    * https://github.com/confidential-containers/operator/tree/main/install/pre-install-payload
      * The last commit there must match what's in the following files as preInstall / postUninstall image
        * Enclave CC: https://github.com/confidential-containers/operator/blob/main/config/samples/enclave-cc/base/ccruntime-enclave-cc.yaml
        * Kata Containers:
              Note that for Kata Containers, we're looking for the newTag, below the quay.io/confidential-containers/container-engine-for-cc-payload image
          * default: https://github.com/confidential-containers/operator/blob/main/config/samples/ccruntime/default/kustomization.yaml

5. - [ ] Ensure the Operator is using the latest CI builds and that the Operator tests are passsing

    * Enclave CC:
      * SIM: https://github.com/confidential-containers/operator/blob/main/config/samples/enclave-cc/sim/kustomization.yaml
      * HW: https://github.com/confidential-containers/operator/blob/main/config/samples/enclave-cc/base/ccruntime-enclave-cc.yaml
      * Note that we need the quay.io/confidential-containers/runtime-payload-ci registry and enclave-cc-{SIM,HW}-latest tags
    * Kata Containers:
      * default: https://github.com/confidential-containers/operator/blob/main/config/samples/ccruntime/default/kustomization.yaml
      * peer-pods: https://github.com/confidential-containers/operator/blob/main/config/samples/ccruntime/peer-pods/kustomization.yaml
          Note that we need the quay.io/confidential-containers/runtime-payload-ci registry and kata-containers-latest tag

6. - [ ] Update peer-pods with latest commits of kata-containers and attestation-agent and test it, following the [release candidate testing process](https://github.com/confidential-containers/cloud-api-adaptor/blob/main/docs/Release-Process.md#release-candidate-testing)
    
7. - [ ] Cut an attestation-service v<TARGET_RELEASE> and make images for AS and RVPS, if changes happened in the project.

       * https://github.com/confidential-containers/attestation-service
       * Cut a release (AS/RVPS images will be automatically built triggered by release)

8. - [ ] Update kbs to use the latest commit from attestation-service, cut a release and make image

       * https://github.com/confidential-containers/kbs/blob/main/src/api_server/Cargo.toml
       * Change the revision for the following crates (both use `v<TARGET_RELEASE>`)
     * `as-types`
     * `attestation-service`
       * Cut a release (kbs image will be automatically built triggered by release)

9. - [ ] Cut a guest-components v<TARGET_RELEASE> release

10. - [ ] Cut a td-shim v<TARGET_RELEASE> release, if changes happened in the project

11. - [ ] Update Enclave CC to use the released version of image-rs

    * redo step 3, but now using v<TARGET_RELEASE>

12. - [ ] Update Kata Containers to the latest released version of:

    * image-rs (redo step 4, but now using the v<TARGET_RELEASE>)
    * attestation-agent (redo step 5, but now using the v<TARGET_RELEASE>)
    * td-shim (redo step 6, but now using the v<TARGET_RELEASE>)

13. - [ ] Update the operator to use the images generated from the latest commit of both Kata Containers and Enclave CC

    * redo step 8, but now targetting the latest payload image generated for Kata Containers and Enclave CC

14. - [ ] Make sure all the operator tests are passing

15. - [ ] Cut an Enclave CC release

17. - [ ] Add a new Kata Containers tag


18. - [ ] Wait for release kata-runtime-payload to be successfully built
    * After the Kata tag is created wait for (https://github.com/kata-containers/kata-containers/actions/workflows/cc-payload.yaml) to be successfully completed, so the latest commit kata-runtime-payload for the release is created

19. - [ ] Update peer pods to use the release versions and then cut a release following the [documented flow](https://github.com/confidential-containers/cloud-api-adaptor/blob/main/docs/Release-Process.md#cutting-releases)

## Release


20. - [ ] Update the operator to use the release tags coming from Enclave CC and Kata Containers

    * redo step 8, but now targeting the latest release of the payload image generated for Kata Containers eand Enclave CC

21. - [ ] Update the Operator version

    * https://github.com/confidential-containers/operator/blob/main/config/release/kustomization.yaml#L7

22. - [ ] Cut an operator release

23. - [ ] Make sure to update the release notes

    * https://github.com/confidential-containers/documentation/tree/main/releases/v<TARGET_RELEASE>.md
        
24. - [ ] Poke Wainer Moschetta (@wainersm) to update the release to the OperatorHub
