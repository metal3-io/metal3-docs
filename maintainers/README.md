<!--
This document was originally based on the process used by Open vSwitch (OVS).
You can find information about the OVS committers and the related processes
used by OVS here: http://docs.openvswitch.org/en/latest/internals/maintainers/
-->

# Maintainers

A Metal3 maintainer is a participant in the project with the ability to approve
changes proposed to a given repository. Approval access grants a broad ability
to affect the progress of the project as presented by its most important
artifact, the code and related resources. As such it represents a significant
level of trust in an individual's commitment to working with other maintainers
and the community at large for the benefit of the project. It can not be
granted lightly and, in the worst case, must be revocable if the trust placed
in an individual was inappropriate.

This document governs how maintainers are added or removed from each
of the Metal3 project repositories.  The current list of maintainers of a given
repo can be found in the `OWNERS` file of each repository.

This document suggests guidelines for granting and revoking approval access. It
is intended to provide a framework for evaluation of such decisions without
specifying deterministic rules that wouldn't be sensitive to the nuance of
specific situations. In the end the decision to grant or revoke maintainer
privileges is a judgment call made by the existing set of maintainers.

## Granting Approval Access

Granting approval access should be considered when a candidate has demonstrated
the following in their interaction with the project:

- Contribution of significant new features through the patch submission
  process where:

  - Submissions are free of obvious critical defects
  - Submissions do not typically require many iterations of improvement
    to be accepted

- Consistent participation in code review of other's patches, including
  existing maintainers, with comments consistent with the overall project
  standards

- Assistance to those in the community who are less knowledgeable through
  active participation in project forums such as github, slack, or the
  metal3-dev mailing list.

- Plans for sustained contribution to the project compatible with the project's
  direction as viewed by current maintainers

The process to grant approval access to a candidate is as follows:

- An existing maintainer nominates the candidate by sending a private email to
  all existing maintainers with information substantiating the contributions of
  the candidate in the areas described above.

- A single private email thread may be used to discuss adding a new maintainer
  to multiple repositories.

- All existing maintainers discuss the pros and cons of granting approval
  access to the candidate in the private email thread.

- When the discussion has converged or a reasonable time has elapsed without
  discussion developing (e.g. a few business days) the nominator calls for a
  final decision on the candidate with a followup email to the thread.

- Each maintainer may vote yes, no, or abstain by replying to the private email
  thread. A failure to reply is an implicit abstention.

- After votes from all existing maintainers have been collected or a reasonable
  time has elapsed for them to be provided (e.g. a couple of business days) the
  votes are evaluated. To be granted approval access the candidate must receive
  yes votes from a majority of the existing maintainers and zero no votes. Since
  a no vote is effectively a veto of the candidate it should be accompanied by
  a reason for the vote.

- The nominator summarizes the result of the vote in a private email to all
  existing maintainers

- If the vote to grant approval access passed, the candidate is contacted with an
  invitation to become a maintainer to the project which asks them to agree to
  the maintainer expectations documented here.

- If the candidate agrees access is granted by adding the new maintainer to the
  appropriate `OWNERS` file(s).

## Removing Approval Access Due to Inactivity

The process for adding maintainers discusses a set of criteria which includes
contributing to the project through code, reviews, and discussions.  It is
normal that plans and assignments change over time and a maintainer may no
longer have the capacity to continue contributing.  In that case, it is desired
that the maintainer remove themselves from the appropriate `OWNERS` file(s).
If participation picks up in the future, it should be easy to get re-added.

Existing maintainers may also reach out to other maintainers to check on their
availability for ongoing participation, prompting a discussion about whether it
would be appropriate to drop out of the maintainers list.  If no response is
received, an existing maintainer may propose removing a maintainer due to
inactivity.  Again, it should be easy to re-add if participation picks up again
in the future.

## Revoking Approval Access

When a maintainer behaves in a manner that other maintainers view as detrimental
to the future of the project, it raises a delicate situation with the potential
for the creation of division within the greater community.  These situations
should be handled with care.  The process in this case is:

- Discuss the behavior of concern with the individual privately and explain why
  you believe it is detrimental to the project. Stick to the facts and keep the
  email professional. Avoid personal attacks and the temptation to hypothesize
  about unknowable information such as the other's motivations. Make it clear
  that you would prefer not to discuss the behavior more widely but will have
  to raise it with other contributors if it does not change. Ideally the
  behavior is eliminated and no further action is required. If not,

- Start a private email thread with all maintainers, including the source of
  the behavior, describing the behavior and the reason it is detrimental to the
  project. The message should have the same tone as the private discussion and
  should generally repeat the same points covered in that discussion. The
  person whose behavior is being questioned should not be surprised by anything
  presented in this discussion. Ideally the wider discussion provides more
  perspective to all participants and the issue is resolved. If not,

- Start a private email thread with all maintainers except the source of the
  detrimental behavior requesting a vote on revocation of approval rights. Cite
  the discussion among all maintainers and describe all the reasons why it was
  not resolved satisfactorily. This email should be carefully written with the
  knowledge that the reasoning it contains may be published to the larger
  community to justify the decision.

- Each maintainer may vote yes, no, or abstain by replying to the private email
  thread. A failure to reply is an implicit abstention.

- After all votes have been collected or a reasonable time has elapsed
  for them to be provided (e.g. a couple of business days) the votes
  are evaluated. For the request to revoke approval access for the
  candidate to pass it must receive yes votes from two thirds of the
  existing maintainers

- anyone that votes no must provide their reasoning, and

- if the proposal passes then counter-arguments for the reasoning in no
  votes should also be documented along with the initial reasons the
  revocation was proposed. Ideally there should be no new
  counter-arguments supplied in a no vote as all concerns should have
  surfaced in the discussion before the vote.

- The original person to propose revocation summarizes the result of the vote
  in a private email to all existing maintainers excepting the candidate for
  removal.

- If the vote to revoke maintainer access passes, access is removed and the
  candidate for revocation is informed of that fact and the reasons for
  it as documented in the email requesting the revocation vote.

- Ideally the revoked maintainer peacefully leaves the community and no
  further action is required. However, there is a distinct possibility
  that he/she will try to generate support for his/her point of view
  within the larger community. In this case the reasoning for removing
  approval access as described in the request for a vote will be
  published to the community.

## Changing the Policy

The process for changing the policy is:

- Propose the change to the appropriate documents in the metal3-docs
  repository.

- After an appropriate period of discussion (at least a few days) update the
  proposal based on feedback if required.

- After all votes have been collected or a reasonable time has elapsed for them
  to be provided (e.g. a couple of business days) the votes are evaluated. For
  the request to modify the policy to pass it must receive yes votes from two
  thirds of the existing maintainers.  Votes are collected by reviews on the
  pull request.
