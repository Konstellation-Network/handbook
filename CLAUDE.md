# Konstellation-Network — agent instructions

This directory is the local checkout of the `konstellation-network` GitHub org.
**Every top-level folder is a separate git repo** with its own history, branches and
remote. The org directory itself is not a git repo. Extra worktrees live under
`.worktrees/<repo>/<branch>/` and are managed by `./wt` (see `README.md`).

## Before doing anything

1. Read `ENGINEERING.md` in full. It is the single source of truth for what we are
   building, the version matrix, and the **hard constraints in §2** — those must not
   be violated without an explicit human decision recorded in that file.
   Then read `STATUS.md`: where the work stands, decisions already made, things
   that look like bugs but are deliberate, and the next steps in order.
   `TOKENOMICS.md` holds every economic number (issuance, burn, staking, gov
   params) and their interactions — read it before touching any of them, and
   update it in the same change when one moves.
2. Identify which repo you are in (`git rev-parse --show-toplevel`) and read its
   section under `ENGINEERING.md §5` (org map) and `§6` (repo structures) before
   editing.
3. Path note: `ENGINEERING.md` uses `~/src/<repo>` in command examples. On this
   machine the repos live at `~/Desktop/Konstellation-Network/<repo>`.

## Rules that apply in every repo

- Never create or clone a repo named `evm`, `cosmos-sdk`, `cometbft` or `ibc-go`
  here (§2.1). `./wt` refuses these names; do not work around it.
- Never commit to a repo other than the one the task is about. Cross-repo changes
  are separate commits in separate repos.
- `konstellation` is the only repo that produces a binary. Do not add build
  targets that produce executables elsewhere.
- Open decisions (`ENGINEERING.md §11`) are not yours to make. If a task depends on
  one, stop and ask.
- Testnet-only or mainnet-only? Say so, and add the row to `ENGINEERING.md §18` in
  the same change. One binary serves every network (devnet-1, testnet-1, konstellation-1); differences live only in
  `networks/<net>/genesis.json` and `infra/`.

## Where things live

Keep `STATUS.md` current: update it when you finish a phase, make a decision, or
find something the next agent must know. Convert relative dates to absolute.

| Repo | Purpose |
|---|---|
| `konstellation` | the chain; produces `konstellationd` |
| `networks` | genesis, peers, upgrade instructions |
| `contracts` | preinstall Solidity + verification (Foundry) |
| `infra` | terraform, ansible, runbooks — private |
| `explorer` | Blockscout deployment config |
| `docs` | developer documentation site (Docusaurus) |
| `whitepaper` | versioned PDF releases |
| `chain-config` | npm package for dapp developers |
| `faucet` | testnet token faucet |
| `Scriipture` | TypeScript DSL that compiles to Solidity (npm `scriipture`, CLI + 9-gate verify pipeline) |
| `.github` | org-wide CODEOWNERS and shared workflows |
