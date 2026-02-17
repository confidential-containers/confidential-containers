# Principles

The Confidential Containers is an open source organization and community that adheres to the following principles:

* Open - Confidential Containers is an open source project licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
  We welcome all contributions (see our [Contributing Guidelines](https://github.com/confidential-containers/confidential-containers/?tab=contributing-ov-file#readme))
* Respectful and welcoming - See our [Code of Conduct](https://github.com/confidential-containers/confidential-containers/blob/main/CODE_OF_CONDUCT.md)
* Transparent - All discussions leading to contributions to the project should be open to all and done in public.
  There maybe exceptions for preliminary effort (e.g. security related work) but the point of disclosure will still lead to a transparent discussion in public, either through our GitHub repositories or public meetings.

# Projects

The Confidential Containers organization is composed of multiple projects.

A project is the primary unit of collaboration, therefore each project has its own repository and maintainers team.
All projects follow the [Code of Conduct](https://github.com/confidential-containers/confidential-containers/blob/main/CODE_OF_CONDUCT.md).

# Community Members and Roles

Everyone is welcome to participate to the Confidential Containers projects in any of the following roles. 

## Contributor

Anyone that contributed to one of the Confidential Containers projects within the last 12 months is a *Contributor*.
Any merged Pull Request is considered a valid contribution.

Contributions are not limited to code alone.
Adding or enhancing documentation, tests, tools, project artifacts are all valuable ways to contribute to a Confidential Containers project.

Project contributions will be reviewed by the project maintainers and should pass all applicable tests.

## Member

Confidential Containers does not officially recognize a project member role.
That said, occasionally it is useful for contributors to be a member of the Confidential Containers
GitHub organization (i.e. to have an issue assigned to them).
In this case, contributors can be added by organization owners.
Inactive organization members can be removed by organization owners.

Anyone in the Confidential Containers GitHub organization must have two-factor authentication enabled.

## Maintainer

Each project has one or more *Maintainer*.
Project maintainers are first and foremost active *Contributors* to the project and are responsible for:

* Setting technical directions for the project.
* Facilitating, reviewing and merging contributions.
  They have write access to the project repository.
* Creating and assigning project issues.
* Enforcing the [Code of Conduct](https://github.com/confidential-containers/confidential-containers/blob/main/CODE_OF_CONDUCT.md).

Project maintainers are managed via GitHub teams. The maintainer team for a project is referenced in the `CODEOWNERS` file
at the top level of each project repository.

Project maintainers must have two-factor authentication enabled.

### Becoming a project maintainer

Existing maintainers may decide to elevate a *Contributor* to the *Maintainer* role based on the contributor established trust and contributions relevance.
This decision process is not formally defined and is based on lazy consensus from the existing maintainers.

A contributor can propose themself or someone else as a maintainer by opening an issue in the repository for the project in question.

### Removing project maintainers

Inactive maintainers can be removed by the Steering Committee.
Maintainers are considered inactive if they have made no GitHub contributions relating to the project they maintain
for more than six months.
Before removing a maintainer, the Steering Commitee should notify the maintainer of their status.

Not all inactive maintainers must be removed.
This process should mainly be used to remove maintainers that have permanently moved on from the project.

## Security Manager

Security managers have access to security advisories across the project and are expected
to engage with them.
Specifically, they have the GitHub security manager role across the entire organization.

Individual repository maintainers as well as the steering committee also have the
security manager GitHub role.
This section captures individuals outside of those groups who might participate in
security reviews.
Security managers might include key users and ecosystem consumers,
such as developers of other OSS projects or commercial distributions/services.

Security managers can be added at the discretion of the steering committee.
To become a security manager, create an issue in this repository
describing why you have a compelling security interest in the project.
Or, if you do not wish to share this information publicly, contact
a member of the Steering Committee directly.
In either case, the Steering Committee will assess the applicant via lazy consensus.
The Steering Committee can remove inactive security managers, but should first try
to contact the individual to confirm that they are inactive.

Other individuals may also be added to individual advisory issues at the discretion of the
security managers or the author of the issue.
Security managers may also coordinate with external parties affected by pending advisories
and share otherwise embargoed information with them on a need-to-know basis.

Security managers must have two-factor authentication enabled.

## Steering Committee Member

The Steering Committee (SC) is the overall Confidential Containers organization governing body.

The SC provides decision-making and strategic oversight for the project.
It also defines and enforces the project values and structure.

The steering committee also has the security manager GitHub role.

Steering committee members must have two-factor authentication enabled.

### Scope and Responsibilities

The scope and responsibilites of the SC is subject to changes, and SC members must adapt it to meet the project needs.
Moreover, any technical responsibilities should be delegated to project Maintainers, although the SC can be consulted to help the with making technical decisions.

Based on that, the SC is responsible for:

* Defining the project high-level strategy and roadmap
* Managing and administrating the project, like e.g. preparing the weekly community meeting
* Building and growing a transparent and inclusive Confidential Containers community
* Onboarding and guiding Confidential Containers end-users

Further, as leaders in the community, the SC members will make themselves familiar with the material in the Linux Foundation's [Open Source Community Orientation](https://training.linuxfoundation.org/training/inclusive-open-source-community-orientation-lfc102/) in order to help grow a healthy community.

### Members

The current members of the SC are:

* Jiang Liu (@jiangliu) and Jia Zhang (@jiazhang0) - Alibaba
* James Magowan (@magowan) and Nina Goradia (@ngoradia) - IBM
* Mikko Ylinen (@mythi) and Bartlomiej Sulich (@bsulich2) - Intel
* Harshitha Gowda (@hgowda-amd) - AMD
* Pradipta Banerjee (@bpradipt)  and Ariel Adam (@ariel-adam) - Red Hat
* Samuel Ortiz (@sameo) - Rivos
* Zvonko Kaiser (@zvonkok) and Tobin Feldman-Fitzthum (@fitzthum) - NVIDIA
* Magnus Kulke (@mkulke) and Dan Mihai (@danmihai1) - Microsoft

### Emeritus Members

* Dan Middleton [dcmiddle](https://github.com/dcmiddle) (he/him)
* Larry Dewey (@larrydewey) - AMD
* Ryan Savino [ryansavino](https://github.com/ryansavino) - AMD

#### Selection

The convention of the SC is for each organization that is significantly engaged
in the project to be represented by one or two members.
In addition to a company, an organization could also refer to a
non-corporate institution such as school.
Selection of the representatives of each organization is not within scope
of the SC.
The organization itself should select the individual(s) to represent it.
Membership changes can fall into one of four categories,
as described in the following sections.
Each of these processes should be initiated by opening a PR against
this document, explaining the motivations of the change and introducing
any potential new members.
Membership changes can be approved via GitHub and do not require an SC meeting.

##### Expansion

The SC can be expanded if a new organization begins making significant contributions
to the project.
When evaluating requests for expansion, the SC will mainly consider whether
the organization in question is making significant contributions to the community.
There is no standard definition for significant contributions.
The SC should prioritize including relevant stakeholders.
The candidates from a organization are understood to represent
that organization. The SC may do some basic checks to ensure that
candidates are familiar with the project and represent relevant contributors.
Expansion should be approved by at least 2/3rds of current SC members.

If an SC member moves from one company to another, their membership does not travel
with them. Instead, they should initiate a replacement (described below) so that
their former employer's representation is up-to-date.
If the new employer has zero or one members on the steering committe, the member
can initiate an expansion to remain on the steering commitee.

If a company reduces their number of representatives, an expansion is required
to increase their footprint on the SC again.

##### Replacement

An SC member can replace themselves with another member from the same organization at will.
This is understood to represent a decision by that organization.
If the SC contains another member from the same organization, they must approve the replacement.
Otherwise, unless there are significant concerns that the change does not represent the
organization in question, a vote is not required to approve a replacement.

If an SC member leaves their company and is no longer engaged with the project, replacement
can be initiated by the other SC member from that company.
In this case a vote is not required to approve the replacement as long as it is clear
that the member being replaced is no longer with the company.
If the company does not have a suitable replacement for the outgoing member,
the same procedure can be used to reduce their representation on the SC
from two seats to one.

##### Recusal

An individual can remove themselves from the SC at any time. A vote is not required for recusal.

##### Removal

A member can be removed from the SC in the case of gross violation of the Code of Conduct.
This should be done only in exceptional circumstances and requires a unanimous vote of remaining SC members.

A member can also be removed for longterm inactivity. This also requires unanimous approval and the steering
committee must attempt to contact the member in multiple ways first.
If possible, a replacement should occur instead.
There is no standard definition of longterm inactivity, but this procedure should only be used in extreme circumstances
where inactivity is expected to be permanent (e.g. retirement), and where the member is inactive
not just in the SC but in the community as a whole, and is not involved in any related internal work.

### Decision-making

The SC routinely makes decisions, technical or not, sometimes as a consulting request from project Maintainers or Contributors.

The SC decision-making process is [driven by consensus](https://en.wikipedia.org/wiki/Consensus_decision-making), i.e. the SC will try to reach consensus through discussions and potentially many revisions for any given proposal.
The main goal is not to get full agreement from all SC members on a final decision, but rather for most people to only be left with minor objections.

Voting on a decision proposal should be used as a last resort solution, as it can potentially leave several SC members major concerns unaddressed.

Some procedural decisions, such as expansion, can be approved without an SC meeting. This is done via GitHub and requires approval by
2/3rds of SC members. If an SC member feels that further discussion is required a meeting can be called, even if the PR has otherwise been approved.
If a meeting is called, the above procedure should be followed.

Changes to this document should also be approved by 2/3rds of SC members, usually following a discussion in an SC meeting.
When a quorum of SC members is required to approve a pull request, if the author of the pull request
is a member of the steering committee, they can be counted towards the quorum.

Community members who are not on the SC are also welcome to submit non-binding feedback regarding any SC process.

### Meeting

The SC will determine an appropriate cadence for meeting and may schedule additional meetings when needed.
Meeting time may change depending on the composition of the SC, in order to adapt to SC members local time zones.
The meeting is public and recorded, and follows a [publicly available agenda](https://docs.google.com/document/d/1YNbkUlcosjN1MFKvs3bJ0CAIZJEp-UEFALW8lDgilLU).

The SC meeting scope is different from the weekly [Confidential Containers community meeting](https://docs.google.com/document/d/1E3GLCzNgrcigUlgWAZYlgqNTdVwiMwCRTJ0QnJhLZGA/edit?usp=sharing), the latter being mostly focused on specific and technical details of one or more Confidential Containers project.

Each SC member is expected to attend the SC meetings, and the following guidelines are used to determine if quorum is reached:

* Quorum to meet is 1/2
* Quorum to vote is 2/3
