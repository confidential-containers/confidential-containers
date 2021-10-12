# Confidential containers roadmap 

When looking at the project's roadmap we distinguish between short term roadmap (2-4 month) vs the mid-long term roadmap (4-12 month):
- The **short term roadmap** is focused on achieving an end-to-end easy to deploy confidential containers solution using at 
least one HW encryption solution and integrated to k8s (with forked versions if needed)
- The **mid/long term solutions** focuses on maturing the components of the short term solution and adding a number of 
enhancements both to the solution and the project (such as CI, interoperability with other projects etc...)

# Short term roadmap
The short term roadmap aims to achieve the following:
- MVP stack for running confidential containers
- Based on and compatible with Kata Containers 2
- Based on at least one confidential computing implementation (SEV, TDX, SE, etc)
- Integration with Kubernetes: kubectl apply -f confidential-pod.yaml

The work is targeted to be completed by end of November 2021 and includes 3 milestones:
- **September 2021**
  - Unencrypted image pulled inside the guest, kept in tmpfs
  - Pod/Container runs from pulled image
  - Agent API is restricted
  - crictl only
- **October 2021**
  - Encrypted image pulled inside the guest, kept in tmpfs
  - Image is decrypted with a pre-provisioned key (No attestation)
- **November 2021**
  - Image is optionally stored on an encrypted, ephemeral block device
  - Image is decrypted with a key obtained from a key brokering service (KBS)
  - Integration with kubelet

For additional details on each milestone see [Confidential Containers v0](https://docs.google.com/presentation/d/1SIqLogbauLf6lG53cIBPMOFadRT23aXuTGC8q-Ernfw/edit#slide=id.p)

Tasks are tracked on a weekly basis through a dedicated spreadsheet. 
For more information see [Confidential Containers V0 Plan](https://docs.google.com/spreadsheets/d/1M_MijAutym4hMg8KtIye1jIDAUMUWsFCri9nq4dqGvA/edit#gid=0&fvid=1397558749).


# Mid/long term roadmap 

TBD

