# Metal3-io security policy

This document explains the general security policy for the whole
[project](https://github.com/metal3-io) thus it is applicable for all of its
active repositories and this file has to be referenced in each repository in
each repository's `SECURITY_CONTACTS` file.

## Way to report a security issue

The Metal3 Community asks that all suspected vulnerabilities be disclosed by
reporting them to `metal3-security@googlegroups.com` mailing list which will
forward the vulnerability report to the Metal3 security committee.

## Security issue handling, severity categorization, fix process organization

**The actions listed below should be completed within 7 days of the
security issue's disclosure on the `metal3-security@googlegroups.com`.**

Security Lead (SL) of the Metal3 Security Committee (M3SC) is tasked to review
the security issue disclosure and give the initial feedback to the reporter as
soon as possible. Any disclosed security issue will be visible to all M3SC
members.

For each reported vulnerability the SL will work quickly to identify committee
members that are able work on a fix and CC those developers into the disclosure
thread. These selected developers are the Fix Team. The Fix Team is also
allowed to invite additional developers into the disclosure thread based on the
repo's OWNERS file. They will then also become members of the Fix Team but not
the M3SC.

M3SC members are encouraged to volunteer to the Fix Teams even before the SL
would contact them if they think they are ready to work on the issue. M3SC
members are also encouraged to correct both the SL and each other on the
disclosure threads even if they have not been selected to the Fix Team but after
reading the disclosure thread they were able to find mistakes.

The Fix team will start working on the fix either on a private fork of the
affected repo or in the public repo depending on the severity of the issue and
the decision of the SL. The SL makes the final call about whether the issue can
be fixed publicly or it should stay on a private fork until the fix is disclosed
based on the issues' severity level (discussed later in this document).

The SL and the Fix Team will create a CVSS score using the
[CVSS Calculator](https://www.first.org/cvss/calculator/3.0). The SL makes the
final call on the calculated risk.

If the CVSS score is under ~4.0 (a low severity score) or the assessed risk is
low the Fix Team can decide to slow the release process down in the face of
holidays, developer bandwidth, etc. These decisions must be discussed on the
`metal3-security@googlegroups.com`.

If the CVSS score is under ~7.0 (a medium severity score), the SL may choose to
carry out the fix semi-publicly. Semi-publicly means that PRs are made directly
in the public Metal3-io repositories, while restricting discussion of the
security aspects to private channels. The SL will make the determination whether
there would be user harm in handling the fix publicly that outweighs the
benefits of open engagement with the community.

If the CVSS score is over ~7.0 (high severity score), fixes will typically
receive an out-of-band release.

More information can be found about severity scores
[here](https://www.first.org/cvss/specification-document#i5).

Note: CVSS is convenient but imperfect. Ultimately, the SL has discretion
on classifying the severity of a vulnerability.

No matter the CVSS score, if the vulnerability requires User Interaction, or
otherwise has a straightforward, non-disruptive mitigation, the SL may choose to
disclose the vulnerability before a fix is developed if they determine that
users would be better off being warned against a specific interaction.

## Fix Disclosure Process

With the Fix Development underway the SL needs to come up with an overall
communication plan for the wider community. This Disclosure process should begin
after the Fix Team has developed a Fix or mitigation so that a realistic
timeline can be communicated to users. Emergency releases for critical and high
severity issues or fixes for issues already made public may affect the below
timelines for how quickly or far in advance notifications will occur.

The SL will lead the process of creating a GitHub security advisory for the
repository that is affected by the issue. In case the SL has no administrator
privileges the advisory will be created in cooperation with a repository admin.
SL will have to request a CVE number for the security advisory.
As GitHub is a CVE Numbering authority (CNA) there is an option to either use an
existing CVE number or request a new one from GitHub. More about the GitHub
security advisory and the CVE numbering process can be found
[here](https://docs.github.com/en/code-security/security-advisories/repository-security-advisories/about-repository-security-advisories).

The original reporter(s) of the security issue has to be notified about the
release date of the fix and the advisory and about both the content of the fix
and the advisory as soon as the SL has decided a date for the fix disclosure.

If a repository that has a release process requires a high severity fix then the
fix has to be released as a patch release for all supported release branches
where the fix is relevant as soon as possible.

In case the repository does not have a release process, but it needs a critical
fix then the fix has to be merged to the main branch as soon as possible.

In repositories that have a release process Medium and Low severity
vulnerability fixes will be released as part of the next upcoming minor or major
release whichever happens sooner. Simultaneously with the upcoming release the
fix also has to be released to all supported release branches as a patch release
if the fix is relevant for given release.

In case the fix was developed on a private repository either the SL or someone
designated by the SL has to cherry-pick the fix and push it to the public
repository. The SL and the Fix Team has to be able to push the PR through the
public repo's review process as soon as possible and merge it.

## Metal3 security committee members

| Name              | GitHub ID           | Affiliation                    |
|-------------------|---------------------|--------------------------------|
| Dmitry Tantsur    | dtantsur            | Red Hat                        |
| Riccardo Pittau   | elfosardo           | Red Hat                        |
| Zane Bitter       | zaneb               | Red Hat                        |
| Furkat Gofurov    | furkatgofurov7      | SUSE                           |
| Kashif Khan       | kashifest           | Ericsson Software Technology   |
| Lennart Jern      | lentzi90            | Ericsson Software Technology   |
| Tuomo Tanskanen   | tuminoid            | Ericsson Software Technology   |
| Adam Rozman       | Rozzii              | Ericsson Software Technology   |

**Please don't report any security vulnerability to the committee members directly.**
