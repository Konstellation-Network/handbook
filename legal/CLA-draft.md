# Konstellation Contributor License Agreement — DRAFT

> **Status: draft for legal review, not in force.** The grantee ("the
> Project Entity") is not yet formed. Do not ask anyone to sign this until
> counsel has reviewed it and the entity's legal name replaces
> `[PROJECT ENTITY]`. Decided 2026-09-30 (ENGINEERING D19); enforcement plan
> at the end.

This agreement is between you ("You") and `[PROJECT ENTITY]` ("the Project
Entity"). It covers every Contribution You submit to any repository in the
`Konstellation-Network` GitHub organisation. You keep the copyright in Your
Contributions. This agreement gives the Project Entity the rights it needs to
use them, and to change the license the project is offered under.

## 1. Definitions

- **"Contribution"**: any original work of authorship, including changes to
  existing work, that You intentionally submit to the Project Entity for
  inclusion in any of its projects: for example a pull request, a patch, or a
  suggested change in an issue or review.
- **"Submit"**: any form of electronic, verbal or written communication sent
  to the Project Entity or its representatives, including through GitHub.

## 2. Copyright license

You grant the Project Entity, and recipients of software it distributes, a
perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable
copyright license to reproduce, prepare derivative works of, publicly display,
publicly perform, sublicense and distribute Your Contributions and derivative
works of them.

**This includes the right to license Your Contributions under any terms,
including licenses other than the one the project uses when You contribute,
and including proprietary licenses.**

## 3. Patent license

You grant the Project Entity, and recipients of software it distributes, a
perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable
(except as stated in this section) patent license. It lets them make, have
made, use, offer to sell, sell, import and otherwise transfer the work, and
covers only the patent claims You can license that are necessarily infringed
by Your Contribution alone, or by Your Contribution combined with the work it
was submitted to. If anyone starts patent litigation claiming that Your
Contribution, or the work it was submitted to, infringes a patent, any patent
licenses granted to them under this agreement for that work end on the date
the litigation is filed.

## 4. Your representations

You represent that:

1. You are legally entitled to grant these licenses.
2. If Your employer has rights to intellectual property You create, You have
   permission to make Contributions on its behalf, or it has waived those
   rights for Your Contributions.
3. Each Contribution is Your original creation. If it includes work by
   others, You identify that work, and its license, in the submission.
4. You will tell the Project Entity if any of these facts change.

## 5. No other obligations

You are not expected to provide support for Your Contributions. Unless You
choose to, or it is required by law, You provide them "AS IS", without
warranties or conditions of any kind. The Project Entity is not obliged to use
any Contribution.

## 6. Trademarks

This agreement grants no rights to any name, trademark or logo of either
party.

---

## Enforcement plan (internal, not part of the agreement)

- Mechanism: the `contributor-assistant/github-action` ("CLA Assistant
  Lite") workflow, from a reusable workflow in the public `.github` repo, on
  every public repo. Contributors sign by commenting on their first PR.
  Signatures go to a private `cla-signatures` repo through a fine-grained token
  with contents:write on that repo only.
- Org members are allowlisted, because their work is covered by their
  employment or contractor agreements. Counsel should confirm those
  agreements assign or license IP to the Project Entity.
- Switch it on only after (1) the entity is formed, (2) counsel has approved
  this text, and (3) the entity name is filled in. Until then, external PRs
  are merged only with the maintainers' explicit agreement.
