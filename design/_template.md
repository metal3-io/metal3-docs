<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

Example Design Document
=======================

Introduction paragraph -- why are we doing anything? A single
paragraph of prose that users can understand. The title and this first
paragraph should be used as the subject line and body of the commit
message respectively.

Some notes about the design process:

* Not all changes need a design document. Anything that is likely to
  result in significant review discussion, or changes to user-facing
  documentation, does.

* The aim of this document is first to define the problem we need to
  solve, and second agree the overall approach to solve that problem.

* This document is not intended to be extensive user-facing
  documentation for a new feature. It should provide enough detail for
  contributors to the project to understand the impact and help refine
  the design.

Some notes about using this template:

* Your spec should be in [Markdown
  syntax](https://daringfireball.net/projects/markdown/syntax), like
  this template.

* Please wrap text at 79 columns.

* Please do not delete any of the sections in this template.  If you have
  nothing to say for a whole section, just write: None


# Problem description #

A detailed description of the problem. What problem is this blueprint
addressing?

## Use Cases ##

What use cases does this address? What impact on actors does this
change have?  Ensure you are clear about the actors in each use case:
Developer, End User, Deployer etc.

# Proposed change #

Here is where you cover the change you propose to make in detail. How
do you propose to solve this problem?

If this is one part of a larger effort make it clear where this piece
ends. In other words, what's the scope of this effort?

## Alternatives ##

What other ways could we solve the problem? Why should we not use
those approaches? This doesn't have to be a full literature review,
but it should demonstrate that thought has been put into why the
proposed solution is an appropriate one.

## CRD impact ##

* What new objects is this going to require?
* What new fields are needed, for either the Spec or Status section?
* What other changes (labels, annotations, etc.) are needed?

## Security impact ##

Describe any potential security impact on the system.

* Does this change touch sensitive data such as credentials or other
  secret values?

* Does this change involve cryptography or hashing?

* Does this change require the use of any elevated privileges?

## Other end user impact ##

Aside from the API, are there other ways a user will interact with this
feature?

## Performance Impact ##

Describe any potential performance impact on the system, for example
how often will new code be called, and is there a major change to the calling
pattern of existing code.

# Implementation #

## Assignee(s) ##

Who is leading the writing of the code?

## Work Items ##

Work items or tasks -- break the feature up into the things that need to be
done to implement it.

## Dependencies ##

* Include specific references to work here or in other projects that
  this design either depends on or is related to.

* Does this feature require any new library dependencies or code
  otherwise not included in the code? Or does it depend on a specific
  version of library?


# Testing #

Please discuss the important scenarios needed to test here, as well as
specific edge cases we should be ensuring work correctly. For each
scenario please specify if this requires specialized hardware, a full
baremetal environment, or can be simulated with virtual machines.


# Documentation Impact #

Which audiences are affected most by this change, and which
documentation should be updated because of this change? Don't repeat
details discussed above, but reference them here in the context of
documentation for multiple audiences.

# References #

Please add any useful references here. You are not required to have any
reference. Moreover, this specification should still make sense when your
references are unavailable. Examples of what you could include are:

* Links to mailing list or IRC discussions

* Links to notes from a summit session

* Links to relevant research, if appropriate

* Related specifications as appropriate (e.g.  if it's an EC2 thing, link the
  EC2 docs)

* Anything else you feel it is worthwhile to refer to
