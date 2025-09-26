# Contributor Guide

So you want to contribute to Confidential Containers?
This guide will get you up to speed on the mechanics of the project
and offer tips about how to work with the community and make great
contributions.

First off, Confidential Containers (CoCo) is an open source project.
You probably already knew that, but it's good to be clear
that we welcome contributions, involvement, and insight from everyone.
Just make sure to follow the [code of conduct](CODE_OF_CONDUCT.md).

CoCo is licensed with [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

This guide won't cover the architecture of the project, but you'll notice
that there are many different repositories under the [CoCo
organization](https://github.com/confidential-containers).
A CoCo deployment integrates many different components.
Fortunately the process for contributing to each of these subprojects
is largely the same.
There is one major exception. Most CoCo deployments leverage [Kata Containers](https://github.com/kata-containers),
which is an existing open source project. Kata has its own [Contributor Guide](https://github.com/kata-containers/community/blob/main/CONTRIBUTING.md)
that you should take a look at.
You can contribute to CoCo by contributing to Kata, but this guide is focused on
contributions made to repositories in the CoCo organization.

## Connecting with the Community

You might already know exactly what you want to contribute and how.
If not, if would be useful to interact with existing developers.
There are several easy ways to do this.

### Slack Channel

The best place to interact with the CoCo community is the
`#confidential-containers` channel in the [CNCF Slack workspace](https://slack.cncf.io/).
This is a great place to ask any questions about the project
and to float ideas for future development.

### Community Meeting

CoCo also has a weekly community meeting on Thursdays.
See [the agenda](https://docs.google.com/document/d/1E3GLCzNgrcigUlgWAZYlgqNTdVwiMwCRTJ0QnJhLZGA/)
for more information.
The community meeting usually has a packed agenda, but there is always time
for a few basic questions.

### GitHub Issue

You can also open issues in GitHub.
Try to open your issue on the repository that is most closely related
to your question.
If you aren't sure which repository is most relevant, you can open an issue
on this repository.
If you're creating an issue that you plan to resolve, consider noting this in
a comment so other developers know that someone is working on the problem.

## Making Contributions

The mechanics of making a contribution are straightforward.
We follow a typical [GitHub contribution flow](https://guides.github.com/introduction/flow/).
All contributions should be made as GitHub pull requests.
Make sure your PR includes a Developer Certificate of Origin (DCO)
and follow any existing stylistic or organizational conventions.
These requirements are explained in more detail below.

Some contributions are simpler than others.
If you are new to the community it could be good to start with
a few simple contributions to get used to the process.
Larger contributions, especially ones that span multiple subprojects,
or have implications on the trust model or project architecture,
will usually require more discussion and review.
Nonetheless, CoCo has a track record of [responding to PRs quickly](https://confidentialcontainers.devstats.cncf.io/d/10/pr-time-to-engagement)
and [merging PRs quickly](https://confidentialcontainers.devstats.cncf.io/d/16/opened-to-merged).

If you are preparing a large contribution, it is wise to share your idea
with the community as early as possible. Consider making an `RFC` issue
that explains the changes. You might also try to break large contributions
into smaller steps.

Any new feature must be accompanied by new unit tests.

### Making a Pull Request

If you aren't familiar with Git or the GitHub PR workflow, take a look at [this section](https://github.com/kata-containers/community/blob/main/CONTRIBUTING.md#github-workflow)
of the Kata Containers contributor guide.
We have a few firm formatting requirements that you must follow,
but in general if you are thoughtful about your work and responsive to review,
you shouldn't have any issues getting your PRs merged.
The requirements that we do have are there to make everyone's life a little easier.
Don't worry if you forget to follow one of them at first.
You can always update your PR if necessary.
If you have any ideas for how we can improve our processes,
please suggest them to the community or make PR to this document.

#### Certificate of Origin

Every PR in every subproject is required to include a DCO.
This is strictly enforced by the CI.
Fortunately, it's easy to comply with this requirement.
At the end of the commit message for each of your commits add something like
```
Signed-off-by: Alex Ample <al@example.com>
```
You can add additional tags to credit other developers who worked on a commit
or helped with it.
See [here](https://ltsi.linuxfoundation.org/software/signed-off-process/)
for more information.


#### Coding Style

Please follow whatever stylistic and organizational conventions have been
established in the subproject that you are contributing to.

Most CoCo subprojects use Rust. When using Rust, it is a good idea to run `rustfmt` and `clippy`
before submitting a PR.
Most subprojects will automatically run these tools via a workflow,
but you can also run the tools locally.
In most cases your code will not be accepted if it does not pass these tests.
Projects might have additional conventions that are not captured by these tools.

* Use `rustfmt` to fix any mechanical style issues. Rustfmt uses a style which conforms to the
[Rust Style Guide](https://doc.rust-lang.org/nightly/style-guide/).
* Use `clippy` to catch common mistakes and improve your Rust code.

You can install the above tools as follows.

```sh
$ rustup component add rustfmt clippy
```


#### Commit Format

Along with code your contribution will include commit messages.

As mentioned, commit messages are required to have a `Signed-off-by` footer.
Commit messages should not be empty.
Even if the commit is self-explanatory to you, include a short description of
what it does.
This helps reviewers and future developers.

The title of the commit should start with a subsystem. For example,
```
docs: update contributor guide
```
The "subsystem" describes the area of the code that the change applies to.
It does not have to match a particular directory name in the source tree
because it is a "hint" to the reader. The subsystem is generally a single
word.

If the commit touches many different subsystems, you might want to
split it into multiple commits.
In general more smaller commits are preferred to fewer larger ones.

If a commit fixes an existing GitHub issue, include `Fixes: #xxx` in the commit message.
This will help GitHub link the commit to the issue, which shows other developers that
work is in progress.

#### Pull Request Format

The pull request itself must also have a name and a description.
Like a commit, the pull request name should start with a subsystem.
Unlike a commit, the pull request description does not become part of
the Git log.
The PR description can be more verbose. You might include a checklist of development steps
or questions that you would like reviewers to consider.
You can tag particular users or link a PR to an issue or another PR.
If your PR depends on other PRs, you should specify this in the description.
In general, the more context you provide in the description, the easier it will be for reviewers.


### Reviews

In most subprojects your PR must be approved by two maintainers before it is merged.
Reviews are also welcome from non-maintainers.
For information about community structure, including how to become a maintainer,
please see the [governance document](https://github.com/confidential-containers/confidential-containers/blob/main/governance.md).

It may take a few iterations to address concerns raised by maintainers and other reviewers.
Keep an eye on GitHub to see if you need to rebase your PR during this process.
The web UI will report whether a PR can be automatically merged or if it conflicts
with the base branch.

While CoCo reviewers tend to be responsive, many have a lot on their plate.
If your PR is awaiting review, you can tag a reviewer to remind them to take a look.
You can also ask for review in the CoCo Slack channel.

### Continuous Integration

All subprojects have some form of CI and require some checks to
pass before a PR can be merged.
Some of the checks are:

- Static analysis checks.
- Unit tests.
- Functional tests.
- Integration tests.

If your PR does not pass a check, try to find the cause of the failure.
If the cause is not related to your changes, you can ask a reviewer to re-run
the tests or help troubleshoot.


With this guide, you're well-prepared to contribute effectively to Confidential Containers. We appreciate your involvement in our open-source community!
