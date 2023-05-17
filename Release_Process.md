# Confidential Container Release Process

## Process
- Code Freeze
- Issue created from [Release Check list template](https://github.com/confidential-containers/community/issues/new?assignees=&labels=&template=release-check-list.md&title=%5BRelease%5D+Check+list+for+v%3CTARGET_RELEASE%3E)
- "[Release Owner](https://github.com/confidential-containers/community/wiki/Release-Team-Rota)" identifies owners for Check List Items
- Check List Items completed
- Release Complete
- Removal of Code Freeze and release announced.

Release Dates will be set mid-week, and no one should feel an expectation to work unsocial hours to meet a release date. Communication and expectation setting is important, and can be used to involve more people from the community to address any Issues blocking release. From the point of code freeze, the release is being built so the release date is an estimate. Releasing early or late along with ideas for improvements/changes for future releases will be reflected on after release.


## Requirements to help with Release Process
- Availability during the release period to complete Tasks 
- Be added to the organization-wide team called release-champions. This team has elevated privileges on all repos that are involved in a release
- GitHub permissions to push tags and create releases in CoCo repositories

## Expectations on Release Owners
The release owner is not expected to complete the Release Check List alone and the majority of tasks on the check list can be delegated. Delegation will help others become confident in assisting with the release and share the burden, but does rely on community members volunteering.

The key responsibility which can not be delegated is communication and oversight
- communicate and ensure code freeze with repository maintainers (currently threads in the CNCF and Kata workspaces are used for communication)
- ensure the checklist is completed
- ensure the checklist is updated to reflect any new checklist items
- report status to the community
- announce the new release and end of code freeze.
- remove those not currently helping with the release from the release-champions team 
- ensure those helping with the release are part of the release-champions team

## Code Freeze - Expectations from the Community
- During the Code Freeze period no code should be merged without release owner approval. Exceptions can include
  - Documentation updates
  - Release Notes
  - Bug fixes

- The Pipeline (all Github Actions, Jenkins jobs, Jenkins Job Builder definitions, etc.) is considered code and should also be frozen from changes
- If the release process identifes an issue then community is expected to help resolve the issue and deliver a fix
- The release owner would be involved in reviewing the fix and approving a merge (in addition to repository maintainers)

## Useful Links
- [Template for Release checklist](https://github.com/confidential-containers/community/issues/new?assignees=&labels=&template=release-check-list.md&title=%5BRelease%5D+Check+list+for+v%3CTARGET_RELEASE%3E)
- [Release Owners](https://github.com/confidential-containers/community/wiki/Release-Team-Rota)
- [CCv0 daily baseline view](http://jenkins.katacontainers.io/view/Daily%20CCv0%20baseline/)
- [CCv0 PR jobs](http://jenkins.katacontainers.io/view/CCv0/)
- [Project Board](https://github.com/orgs/confidential-containers/projects/6)

