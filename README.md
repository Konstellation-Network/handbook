# handbook — internal org-wide files for Konstellation-Network

Private. This repo was called `.github` until 2026-09-30; it was renamed so a
**public** `.github` repo could carry the org profile README
(`github.com/Konstellation-Network`) without exposing anything here. If your
clone still points at `.github.git`, run
`git remote set-url origin https://github.com/Konstellation-Network/handbook.git`
and rename the folder to `handbook` (then re-run `bootstrap.sh` for the symlinks).

Canonical home of the documents every repo (and every coding agent) depends on:

| File | Purpose |
|---|---|
| `ENGINEERING.md` | what we are building, hard constraints, version matrix, decisions, security record |
| `STATUS.md` | where the work stands, deliberate deviations, open decisions, next steps |
| `CLAUDE.md` | instructions auto-loaded by Claude Code from any repo under the org directory |
| `ORG-README.md` | the org directory's README (layout + `wt` workflow) |
| `wt` | org helper: create/clone repos, per-repo worktrees, org-wide status |
| `bootstrap.sh` | recreate the org directory on a new machine (clones + symlinks) |
| `CODEOWNERS.template` | template for each repo's own `CODEOWNERS` (GitHub has no org-wide default for this file, see below) |

On a developer machine these are symlinked into the org root so that
`Konstellation-Network/ENGINEERING.md` etc. resolve here. Edit them **here**, commit,
push. `bootstrap.sh` sets the symlinks up.

Shared reusable workflows will also live here (reusable workflows need not be in `.github`) (ENGINEERING.md §5). `CODEOWNERS` is
**not** on that list: GitHub does not support an org-wide default `CODEOWNERS` (unlike
`CONTRIBUTING`/`SECURITY`/`SUPPORT`/issue templates, it must live in each individual
repo to take effect there). A template `CODEOWNERS` can still live here for repos to
copy from, but each repo needs its own committed copy.
