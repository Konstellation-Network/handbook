# Konstellation — Status & Handoff

**Updated:** 2026-09-14 (PR #2 merged + live smoke test; `infra` testnet-1 scaffold added;
`contracts` Foundry project scaffolded — WKONS + preinstalls).
Read after `ENGINEERING.md`. This
file is *state*: where we are, why things look the way they do, and what is next.
`ENGINEERING.md` is *policy*. When they disagree, `ENGINEERING.md` wins and this file is stale
— fix it.

---

## 1. Where we are

Launch sequence (`ENGINEERING.md §15`):

| Phase | Status |
|---|---|
| 0 — scaffold `konstellation`, pin cosmos/evm, zero local replaces | **done** — PR #1, merged 2026-09-14 |
| 1 — govulncheck clean, CI green, dependency graph verified | **done** — PR #1, seven review passes, 29 findings fixed, last pass zero medium+ |
| 2 — customise: genesis params, preinstalls, custom modules | **next** |
| 3 — safety rails (§13) | not started |
| 4+ | not started |

`konstellation` PR #1 (https://github.com/Konstellation-Network/konstellation/pull/1)
**merged** into `main` as `90095a6` on 2026-09-14. Its description is the accurate
summary of the chain as scaffolded, including every genesis parameter and which
are still SDK defaults.

`konstellation` PR #2 (https://github.com/Konstellation-Network/konstellation/pull/2)
— upstream release watch + vuln-failure issues. **Merged** into `main` as `5130fb5` on
2026-09-14. First live run (`gh workflow run upstream-watch.yml`, manual `workflow_dispatch`)
confirmed the compare step working end-to-end on the real Actions runner: reported
"up to date: pinned v0.7.3, latest v0.7.3" and correctly skipped both issue-creation steps.
The issue-creation path itself (a real new release, or a deliberately broken run) is still
unexercised live — first genuine trigger will be the next actual cosmos/evm tag, or the
6-hourly cron. See §7 for how it was reviewed.

`infra` has a testnet-1 scaffold (terraform modules for validator/sentry/rpc/archive,
ansible roles for node/cosmovisor/horcrux/monitoring/firewall, prometheus alert
rules) — not yet committed there, not yet applied against real infrastructure.
See `infra/README.md` "Known gaps" for what's still missing before a real
`terraform apply` (bastion host, monitoring host, dedicated horcrux cosigners,
version pins, state backend).

`contracts` has a Foundry project scaffolded and pushed to `main` (`018e3a5`,
2026-09-14): `src/WKONS.sol` (wrapped native token, KASH/`esp`, 18 decimals),
`preinstalls/{Multicall3,Permit2,EntryPointV07,EntryPointV08,Create2Deployer}.json`
(deployed bytecode pinned from live mainnet `eth_getCode`, each with a `codeHash`
guard), `test/GenesisBytecode.t.sol` (offline self-consistency check) and
`script/VerifyPreinstalls.s.sol` (live check against a real RPC fork — run and
passing against mainnet at pin time), plus a CI workflow running
`forge fmt`/`build`/`test`. Multicall3 and Permit2 are already in cosmos/evm's
`DefaultPreinstalls` at identical addresses/bytecode (verified byte-for-byte);
EntryPointV07, EntryPointV08 and Create2Deployer are **not** and still need
explicit genesis wiring in `konstellation` (see Phase 2, §5 step 4).
`src/vesting/` is intentionally not built — blocked on D12 sign-off.

All other repos (`networks`, `explorer`, `docs`, `whitepaper`, `chain-config`,
`faucet`, `.github`) exist on GitHub, private, with an `init` commit only.

## 2. Decisions made on 2026-09-13 (all recorded in ENGINEERING.md)

| | Value | Where |
|---|---|---|
| D1 EIP-155 ids | mainnet **5667**, testnet-1 **56671**, local/unknown **56670** | §1, §11 |
| D2 token | **KASH**, base denom `esp`, 18 decimals, no precisebank | §1, §11 |
| D3 bech32 | `kons` | §1, §11 |
| D10 (2026-09-14) | staking: DPoS, unbonding 21d, `min_commission_rate` 5%, **`max_validators` 30**, downtime slash 0.01%, double-sign slash 5% | §11; `app/config/chain.go` + `app/app.go` |
| D11 | gov: min deposit **10 KASH** / expedited **50 KASH** (2026-09-13); voting period **3d**, quorum **33.4%**, threshold **50%** (2026-09-14) | §11; `app/config/chain.go` + `app/app.go` |
| cosmos/evm pin | **v0.7.3** (v0.7.2 has GHSA-367m-g444-9mg3) | §2.4, §3, §4.1 |
| Go | `go 1.26.0` min, `toolchain go1.26.8` (1.25 is out of support) | §3 |
| BlockSTM | OFF; **virtual fee collection also OFF** (same bundle) | §2.5, §7.3 |
| EIP-1559 base fee | ON (upstream evmd disables it; we do not) | app/genesis.go |
| Chain-id invariant | **genesis.json decides the network; every per-node file is checked against it, in both directions** (a real network's EVM id is used only by that network) | §1 |

## 3. Things that are deliberate and easy to mistake for bugs

Upstream `evmd` is a test harness. Several ways a real node is broken out of the
box were hidden by `local_node.sh` patching files with `jq`/`sed`. All of that
patching is **gone**; `konstellationd init` + `start` is the only supported path
and produces a correct node. Specifically, in `konstellation`:

- `cmd/konstellationd/cmd/init.go` hands the SDK's `init` a BasicManager whose
  modules answer with `app.DefaultGenesis()` (so every denom is `esp`, not
  `stake`), then rewrites `app.toml`'s `evm-chain-id` from the chain-id in the
  genesis it just wrote. `--default-denom` is rejected unless it is `esp`.
- `root.go initCometConfig` sets `mempool.type = "app"` (Krakatoa app-side EVM
  mempool is on by upstream default; CometBFT refuses to start otherwise).
- `root.go getChainIDFromOpts` reads the chain-id from **genesis first**
  (honouring `genesis_file` in config.toml); `--chain-id` or `client.toml`
  disagreeing with genesis is an error naming both files.
- `app.New` panics if a known network's `evm-chain-id` is wrong
  (`app/config.ValidateEVMChainID`).
- The in-process `testnet` subcommand was dropped: it imports the untagged
  `evmd` nested module, which would need the forbidden local `replace`.
- `app/upgrades.go` is gone: a registered handler for a name that never ships
  lets a gov upgrade "succeed" on the old binary.
- `Makefile verify-deps` diffs the full `replace` set against the pinned
  cosmos/evm `go.mod` and rejects any replace of the four protected modules,
  case-insensitively, before touching the network. Tested against three bypasses.
- `scripts/vulncheck.sh` wraps govulncheck (source nightly, binary on PRs) and
  fails on any reachable finding not justified in `.govulncheck-allowlist`.
  Four entries are allow-listed; every one is explained in §4.1.1.
- feemarket `min_gas_multiplier = 0.5` (upstream default): a tx is charged at
  least half its gas limit. Genesis param; decide with D10/D11.

## 4. Open decisions, with recommendations

| | Question | Recommendation |
|---|---|---|
| D4 | emission model | not mine to make; blocks `x/mint` custom work and whitepaper |
| D5 | base fee burn vs distribute | default (distribute) is wired; changing later is a visible economic change |
| D6 | compliance scope | decide before audit scoping (§10) |
| D7 | validator set model | 5–10 self-run = permissioned; say so honestly |
| D8 | launch value ceiling | no bridge day one, or hard caps + IBC rate limit |
| D12 | vesting | Solidity contracts, not `x/auth` vesting — confirm and build in `contracts` |
| §17 | ownership | decided: shared, any engineer, issue-driven with 1-working-day self-assign; on-call rota still to create in `infra` |

## 5. Next steps, in order

1. ~~Merge PR #1~~ merged 2026-09-14 (`90095a6`).
2. ~~Merge PR #2~~ merged 2026-09-14 (`5130fb5`); ~~then `gh workflow run upstream-watch.yml`
   once and confirm "up to date: pinned v0.7.3"~~ done — confirmed on the live runner. The
   issue-creation path (a real new release, or a deliberately-broken run) is still
   unexercised; nothing to do here but wait for the first real trigger.
3. ~~Put names in `ENGINEERING.md §17`~~ decided 2026-09-14: shared ownership,
   any engineer, with triggers and deadlines per row (see §17). Only the on-call
   row still needs a rota, when validators exist.
4. Phase 2 in `konstellation`: ~~set D10~~ ~~set D11~~ both done 2026-09-14
   (staking + slashing + gov params in `app/config/chain.go` / `app/app.go`;
   build + `make test-unit` green). ~~decide D13~~ decided 2026-09-14: keep
   the app-side mempool ON — already the code's behavior (`init` already
   writes `mempool.type = "app"`), so no change needed, just recorded. Still
   open: feemarket `min_gas_multiplier` (currently upstream default 0.5, tied
   to D10/D11 per §3 but not itself part of either — needs its own call).
   Still to do for the "preinstalls" part of Phase 2: `contracts` now has
   pinned bytecode ready (2026-09-14, see §1) for `EntryPointV07`,
   `EntryPointV08` and `Create2Deployer` — wire these into `app/genesis.go`'s
   preinstall list (`Multicall3`/`Permit2` need no action, already covered by
   cosmos/evm's `DefaultPreinstalls`). Also undecided: whether `WKONS` ships
   as a genesis preinstall at a fixed address or an ordinary post-genesis
   deploy — nobody has made this call yet.
5. Phase 3: `x/circuit` wired with multisig authority, IBC rate-limit middleware
   (§13). Both are `app.go` wiring, no fork.
6. `tests/e2e` (interchaintest): first test should be the one upstream lacks —
   an EVM transfer *to a module account* must be rejected (§4.1.1 coverage gap).
7. `networks/testnet-1/`: genesis comes straight from `konstellationd init
   --chain-id testnet-1`; record its sha256 (§6.2).
8. `.github` repo: org-wide CODEOWNERS. (`ENGINEERING.md`, `CLAUDE.md`,
   `STATUS.md`, `wt` already live there; `bootstrap.sh` recreates the org dir.)
9. `infra`: testnet-1 scaffold exists (terraform + ansible), not yet a real
   deployment — see `infra/README.md` "Known gaps". Not blocking anything
   above; runs in parallel given terraform/ansible lead time. Before a real
   `terraform apply`: pick the state backend, stand up a bastion + monitoring
   host (neither has a terraform module yet), and fill in the empty
   `konstellationd_version`/`*_sha256` vars once `konstellation` cuts a
   release (waits on step 4-6 above).

## 6. Tooling and locations

- `./wt` at org root: `init`, `create` (GitHub, private), `clone`, `new`/`rm`
  worktrees, `status`, `each`. Refuses `evm`/`cosmos-sdk`/`cometbft`/`ibc-go`.
- `~/src/evm-reference`: local clone of cosmos/evm at **v0.7.3**. Never pushed.
  Use it to diff upstream releases (`ENGINEERING.md §16`).
- `konstellation`: `make build` (sha256 printed), `make verify-deps`,
  `make vulncheck` / `vulncheck-binary`, `make test-unit`, `golangci-lint run`,
  `./local_node.sh -y` (dev chain, JSON-RPC :8545, metrics :26660, chain id 56670).
- Dev mnemonics in `local_node.sh` are public; `dev0` = `0xC6Fe5D33615a1C52c08018c47E8Bc53646A0E101`.

## 7. How PR #1 was reviewed

Seven automated review passes (`/code-review pr#1`), each reproducing findings
against the live branch. Trend: 6 → 6 → 3 → 4 → 1 → 3 → 6 (all low). The
seventh pass ran a full bootstrap, bank send, EVM transfer and zero-height
export and found nothing above low; iterating further has diminishing returns. Every finding was
reproduced before fixing and re-verified after. The reviewer repeatedly found
the *next* crack in the chain-id story, which is why §1 now states the
invariant explicitly. Expect the same reviewer to run on future PRs; write
commits that a reviewer can verify without the chat.

## 8. How PR #2 was reviewed

Four automated review passes (`/code-review pr#2`), findings fixed and
re-verified locally (live against the real cosmos/evm repo, not mocked) before
each next pass. Two were genuinely load-bearing, not style nits:

- Round 1's own dedup fix (`gh issue list --jq --arg ...`) turned out to be
  invalid — `gh`'s `--jq` doesn't take extra `jq` arguments — and would have
  silently aborted the issue-upsert step on every run under Actions'
  `set -e` shell. Caught by testing the exact command locally before round 2
  shipped, not by the reviewer.
- Round 4 found a real, still-dormant bug: the up-to-date check compared
  `PINNED`/latest with `sort -V`, which doesn't implement semver precedence.
  A pinned Go pseudo-version at the same release core as a just-tagged
  release would sort as "newer" and make the watcher report up to date for a
  release it never saw. go.mod pins a clean tag today so this hasn't fired,
  but the logic was verifiably wrong; fixed by comparing the release core
  first, only treating an exact suffix-free match as up to date.

Two low-severity items were deliberately left unfixed across rounds 2 and 4
(reasoning is in the PR #2 description, not repeated here): tag listing pages
through cosmos/evm's full tag history rather than one bounded call, and
`gh label create` runs unconditionally with errors swallowed. Both are
accepted trade-offs favoring correctness/clarity over a marginal efficiency
gain, not oversights.

`scripts/upstream-check.sh` no longer clones cosmos/evm — it went through a
git-clone → GitHub-API rewrite mid-review (round 3) once the local clone was
flagged as unnecessary CI cost; commit dates, commit log, and the hot-zone
diff stat now come from the GitHub commits/compare APIs, with an explicit
warning if the compare API's 300-file cap is ever hit.
