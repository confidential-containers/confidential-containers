* [High level considerations](#high-level-considerations)
    * [Security](#security)
    * [Reliability](#reliability)
    * [Performance](#performance)
    * [Maintenance](#maintenance)
    * [Usability](#usability)
* [Specifics to consider](#specifics-to-consider)
    * [Basics](#basics)
    * [Layout and formatting](#layout-and-formatting)
    * [Design](#design)
    * [Code comments](#code-comments)
    * [Documentation](#documentation)
    * [Logging and debugging](#logging-and-debugging)
    * [Testing](#testing)
    * [Environments](#environments)
    * [Upgrades](#upgrades)
* [Mandatory checks](#mandatory-checks)

---

This document attempts to capture some of the points to consider when
reviewing a [new code contribution](CONTRIBUTING.md) (a Pull Request (PR)) to
ensure overall quality is high.

## High level considerations

### Security

- Does the change introduce a potential security risk?
  - What additional checks resolve the potential security risk?

### Reliability

- What happens on failure? Consider **every** possible failure. For example:
  - Are temporary files left on the disk?
  - Are any resources (e.g. memory and open files) leaked?

- If the code crashes, what is the overall system impact?
  - Can the system be restarted and recovered?
  - Is [security](#security) compromised?

### Performance

- Does this change negatively impact performance?
- Can any calls block? If yes, there must be a log call before the blocking call explaining what is about to be done.

### Maintenance

- How easy is this code to maintain:
  - By an experienced developer on the project?
  - By a developer with none or almost no experience of the code base or the project?

### Usability

- Does the change improve usability or make it worse?
- Can usability be improved further?

## Specifics to consider

### Basics

- Consider *all* inputs and outputs.
- What resources are being used (e.g. memory, disk, etc.)? Are the resources released?
- Are all return values and arguments checked?
- Are there any magic numbers?

### Layout and formatting

- Is formatting and naming consistent?
- Are there any spelling mistakes ("typos")?
- Do all new files contain the required licence header?

### Design

- Can the code be simplified or refactored?
  - Is the code "too clever"? Overly clever code can be fragile. Reject it unless there is a **very** good documented reason.
- Is there a better (simpler) solution to the problem?
- Is there any duplication?
- Does the code "reinvent the wheel?" Is there a standard package you can use instead?
- What assumptions does the code make? Are the assumptions valid and documented?
- Does the code make sense?
  - Someone with minimal exposure to the codebase should be able to guess what the code is doing.

### Code comments

- Is the code well commented?
- Are all functions and function parameters documented. For `golang` programs, is their purpose obvious?
- Does this change require an update to the README(s) or architecture docs, installation docs, or limitations docs?
- Are any lines commented out? If yes, remove them.
- Are there any `FIXME` or `TODO`'s? If yes, replace them with a full URL to an issue number tracking the work to be done.

### Documentation

- Should the document update be applied to any *other* documents?
  For example, when a PR updates an installation guide, determine whether those changes apply to one or more of the other installation guides.
- Does the PR make any of the following changes? If yes, determine if a documentation change is necessary:
  - New programs or scripts are added or removed.
  - New program or script options are added or removed.
  - New config options are added or removed.
  - New features are added or removed.
  - Existing bug(s) are fixed.

### Logging and debugging

- Can someone debug this code from a logfile if it fails?
- Are all fatal scenarios logged?
- Are error messages and log calls useful and comprehensive? Ensure sensitive information is **not** displayed.

### Testing

- Is the code easy to test?
- Are there new unit tests? If not, why not?
- What other classes of testing (e.g. integration, system, stress, fuzz) can someone write to check the code?

### Environments

- Does the code work on all distributions?
- Does the code work on all architectures?
- What environments does your code run in?
- Which user does the code run as? If it runs as the superuser, have clear documentation to explain why this is necessary.

### Upgrades

- If the code logs internal state to a file or shared memory, how are upgrades handled?
For example, if a new version introduces a new state file format, does the new version consume the old state file format files?
- If upgrades cannot be handled, document this.

## Mandatory checks

- Provide constructive comments on the code.
  - If you particularly like some aspect of the code, say so.
  - If you do not like something about the code, respectfully state what you do not like.
  - If you do not understand the code, say so because code should **always** be clear.

- Ensure all automated checks pass.
- Ensure the PR contains at least one `Fixes #XXX` commit message referencing an issue that this PR fixes.
