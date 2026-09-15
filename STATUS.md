# Konstellation — Status & Handoff

**Updated:** 2026-09-15 (`konstellation` PR #4 merged — genesis preinstalls wired,
including the two `SenderCreator`s a review pass found missing, pinned via `contracts`
PR #1; Phase 2 genesis/preinstall work is now complete, D4/D5/D6 module builds remain.
Earlier the same day: PR #3 merged, D4–D9 and D12 decided, `WKONS`→`WKASH` rename
committed).
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
| 2 — customise: genesis params, preinstalls, custom modules | **in progress** — genesis params (PR #3) and preinstalls (PR #4) merged; `x/mint` (D4), fee-burn (D5) and compliance precompile (D6) still to build |
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

`konstellation` PR #3 (https://github.com/Konstellation-Network/konstellation/pull/3)
— D10 staking/slashing params, remaining D11 gov params, and feemarket
`min_gas_multiplier` set explicitly (0.5, the upstream default, now a recorded decision
rather than an incidental one). **Merged** into `main` as `21da290` on 2026-09-14; CI
(`build-test`, `lint`, `vuln/binary`) green before merge.

`konstellation` PR #4 (https://github.com/Konstellation-Network/konstellation/pull/4)
— genesis preinstalls. New `app/preinstalls` package `go:embed`s verbatim copies of
`contracts/preinstalls/*.json` and, on load, re-checks `keccak256(code) == codeHash`,
runs x/vm's `Preinstall.Validate`, refuses address collisions with cosmos/evm's
`DefaultPreinstalls`, and enforces an EntryPoint↔SenderCreator dependency map (the
dependency's address must literally occur in the dependant's bytecode) — so a bad or
half re-pin fails at `konstellationd init`, not `InitChain`. Genesis now carries **10
preinstalls**: cosmos/evm's 5 + `EntryPointV07`, `SenderCreatorV07`, `EntryPointV08`,
`SenderCreatorV08`, `Create2Deployer`. **Merged** into `main` as `dc1a4db` on 2026-09-15;
CI green. A `/code-review` pass found one HIGH before merge — the EntryPoints were
shipped without their `SenderCreator`s, which made `getSenderAddress()` and any UserOp
with `initCode` revert with empty data (reproduced on a local node) — fixed in `65fa2de`
after pinning the two contracts in `contracts` PR #1. Verified on a fresh node:
`eth_getCode` byte-matches every pin, and `getSenderAddress` reverts with
`SenderAddressResult` (`0x6ca7b806`) on both v0.7 and v0.8.

`infra` has a testnet-1 scaffold, split across two clouds at the user's
request: 3 validators/sentries + 1 archive on Hetzner, 2 validators/sentries +
1 archive + 1 RPC on GCP (terraform modules per provider, ansible roles for
node/cosmovisor/horcrux/monitoring/firewall, prometheus alert rules) —
**committed locally as `0b011f4`, not yet pushed to origin**, and not yet
applied against real infrastructure. This matches `ENGINEERING.md §1`'s own
"5-10 nodes across multiple cloud providers" target and §9.3's "nodes find
each other over the public internet regardless of provider" — multi-cloud
here isn't a deviation, it's the documented baseline. The GCP
validators use Local SSD, which is ephemeral across host maintenance events;
this was a deliberate testnet-1-only call (documented at length in
`terraform/modules/gcp/validator`'s `local_ssd_count` variable and
`infra/README.md`) that MUST be revisited before any mainnet validator runs on
GCP, given the double-sign risk in `ENGINEERING.md §2.7`. See
`infra/README.md` "Known gaps" for the rest of what's missing before a real
`terraform apply` (bastion host, monitoring host, dedicated horcrux cosigners,
version pins, state backend).

`contracts` has a Foundry project on `main` (scaffolded `018e3a5`, 2026-09-14): a
wrapped native token (KASH/`esp`, 18 decimals), `preinstalls/*.json` (deployed
bytecode pinned from live mainnet `eth_getCode`, each with a `codeHash` guard),
`test/GenesisBytecode.t.sol` (offline self-consistency check) and
`script/VerifyPreinstalls.s.sol` (live check against a real RPC fork), plus a CI
workflow running `forge fmt`/`build`/`test`. Seven pins as of 2026-09-15:
`Multicall3`, `Permit2` (both already in cosmos/evm's `DefaultPreinstalls`,
byte-identical — no wiring needed), `EntryPointV07`, `SenderCreatorV07`,
`EntryPointV08`, `SenderCreatorV08`, `Create2Deployer`. The two `SenderCreator`s
were added in `contracts` PR #1 (`b004681`, merged `bb09088` 2026-09-15, two
independent RPCs agreeing; live `VerifyPreinstalls.s.sol` → all 7 OK) after the
`konstellation` PR #4 review found the EntryPoints unusable without them. All five
non-default pins are wired into genesis by `konstellation` PR #4 — **`contracts` is the
source of truth; `konstellation/app/preinstalls/*.json` must stay byte-identical.**

The wrapped-token contract was renamed `WKONS` → `WKASH` (`57cb107`, 2026-09-15)
to match the D2 token symbol. It ships as a **post-genesis deploy, not a genesis
preinstall** (decided 2026-09-14, recorded in `ENGINEERING.md §6.3`) — predictable
address available via `Create2Deployer` + a fixed salt without the permanence cost
of baking bespoke, not-yet-audited bytecode into `genesis.json`. `src/vesting/` is
still not built; D12 is decided (Solidity vesting contracts), so this is unblocked,
just not started.

`docs` has a Docusaurus site scaffolded and pushed to `main` (`2f2e598`, 2026-09-14):
stub docs pages, no real content written yet.

All other repos (`networks`, `explorer`, `whitepaper`, `chain-config`,
`faucet`, `.github`) exist on GitHub, private, with an `init` commit only.

## 2. Decisions made (all recorded in ENGINEERING.md; every numbered decision D1–D13 is now resolved)

| | Value | Where |
|---|---|---|
| D1 EIP-155 ids (2026-09-13) | mainnet **5667**, testnet-1 **56671**, local/unknown **56670** | §1, §11 |
| D2 token (2026-09-13) | **KASH**, base denom `esp`, 18 decimals, no precisebank | §1, §11 |
| D3 bech32 (2026-09-13) | `kons` | §1, §11 |
| D4 emission (2026-09-15) | **stake-based issuance modelled on Ethereum post-merge** (`∝ √(total bonded)`), no bonded-ratio targeting loop. Pairs with D5's burn. Requires a custom `x/mint`-style module — **not yet built**. | §11 |
| D5 base fee (2026-09-15) | **burn** the EIP-1559 base fee, replacing the `x/distribution` default. Requires custom fee-collector wiring in `app.go` — **not yet built**. | §11 |
| D6 compliance (2026-09-15) | **compliance precompile at a fixed address** (`isVerified(address)`), not a chain-wide ante decorator. Custom precompile, no fork — **not yet built**. | §10, §11 |
| D7 validator set (2026-09-15) | state it honestly: 5–10 self-run = **permissioned at launch**, validators added over time as the network decentralises (roadmap to be published in whitepaper) | §11 |
| D8 launch value ceiling (2026-09-15) | **no bridge on day one**; post-launch sequence (soak → build+audit bridge & IBC rate-limit middleware in parallel → calibrate caps → open with caps enforced in-contract) recorded in §11 | §11, §13 |
| D9 audit (2026-09-15) | **Informal Systems** | §11, §12 |
| D10 (2026-09-14) | staking: DPoS, unbonding 21d, `min_commission_rate` 5%, **`max_validators` 30**, downtime slash 0.01%, double-sign slash 5% — **merged, PR #3 (`21da290`)** | §11; `app/config/chain.go` + `app/app.go` |
| D11 | gov: min deposit **10 KASH** / expedited **50 KASH** (2026-09-13); voting period **3d**, quorum **33.4%**, threshold **50%** (2026-09-14) — **merged, PR #3 (`21da290`)** | §11; `app/config/chain.go` + `app/app.go` |
| D12 vesting (confirmed 2026-09-15) | Solidity vesting contracts, not `x/auth` vesting accounts. `contracts/src/vesting/` — **not yet built** | §11 |
| D13 Krakatoa mempool (2026-09-14) | keep app-side EVM mempool **ON** — no code change, already the default behaviour | §11 |
| cosmos/evm pin | **v0.7.3** (v0.7.2 has GHSA-367m-g444-9mg3) | §2.4, §3, §4.1 |
| Go | `go 1.26.0` min, `toolchain go1.26.8` (1.25 is out of support) | §3 |
| BlockSTM | OFF; **virtual fee collection also OFF** (same bundle) | §2.5, §7.3 |
| feemarket `min_gas_multiplier` | **0.5**, explicit (PR #3, `21da290`) — upstream default, now a recorded decision | §3; `app/config/chain.go` |
| Chain-id invariant | **genesis.json decides the network; every per-node file is checked against it, in both directions** (a real network's EVM id is used only by that network) | §1 |
| WKASH (was WKONS) | renamed 2026-09-15 to match the D2 token symbol; ships as a **post-genesis deploy**, not a genesis preinstall — see §1 | §6.3, §11 |
| Genesis preinstalls (2026-09-15) | cosmos/evm's 5 defaults + `EntryPointV07`/`V08`, each with its `SenderCreator`, + `Create2Deployer` at canonical mainnet addresses — **merged, PR #4 (`dc1a4db`)**. Bytecode source of truth is `contracts/preinstalls/`; a preinstall never runs its constructor, so constructor-deployed companions must be preinstalled too | §6.1, §6.3; `app/preinstalls/` |

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
- feemarket `min_gas_multiplier = 0.5` is **not** a per-tx charge. It is a
  block-level floor on the `gasWanted` the feemarket module records for the
  EIP-1559 base-fee update (`gasWanted = max(gasWanted × 0.5, gasUsed)`), so a
  proposer can't push the base fee down by reporting high `gasWanted` with low
  `gasUsed`. Set explicitly in PR #3 (`21da290`) — now a recorded decision, not
  an incidental default.
- `app/preinstalls/*.json` are verbatim copies of `contracts/preinstalls/*.json`,
  not a second source. They are duplicated because `konstellation` cannot import
  a Foundry repo; `Load()` re-verifies each `codeHash` and the
  EntryPoint↔SenderCreator pairing at `init`, so an out-of-step copy fails fast.
  When re-pinning, change `contracts` first, then copy.
- `SenderCreatorV07`/`V08` look redundant next to the EntryPoints but are not:
  each EntryPoint's bytecode hard-references its SenderCreator as an immutable
  and a preinstall never runs the constructor that would have deployed it.
  Dropping either makes `getSenderAddress()` and every UserOp with `initCode`
  revert with empty data (`konstellation` PR #4 review; tests cover it).

## 4. Open decisions

**None remaining.** Every numbered decision (D1–D13) is resolved as of 2026-09-15 —
see §2 above and `ENGINEERING.md §11` for the full record. What's left is *building*
what D4/D5/D6/D9/D12 call for (§5), not deciding anything further.

One non-numbered item still open: the on-call rota (§17) — the model (shared,
any engineer, issue-driven, 1-working-day self-assign) is decided, but the rota
itself waits until validators exist, per §17's own text.

## 5. Next steps, in order

1. ~~Merge PR #1~~ merged 2026-09-14 (`90095a6`).
2. ~~Merge PR #2~~ merged 2026-09-14 (`5130fb5`); ~~then `gh workflow run upstream-watch.yml`
   once and confirm "up to date: pinned v0.7.3"~~ done — confirmed on the live runner. The
   issue-creation path (a real new release, or a deliberately-broken run) is still
   unexercised; nothing to do here but wait for the first real trigger.
3. ~~Put names in `ENGINEERING.md §17`~~ decided 2026-09-14: shared ownership,
   any engineer, with triggers and deadlines per row (see §17). Only the on-call
   row still needs a rota, when validators exist.
4. ~~Phase 2 genesis params and preinstalls in `konstellation`~~ done: D10, D11,
   D13 and feemarket `min_gas_multiplier` via **PR #3 (`21da290`, 2026-09-14)**;
   `EntryPointV07`/`V08` + `SenderCreatorV07`/`V08` + `Create2Deployer` preinstalls
   via **PR #4 (`dc1a4db`, 2026-09-15)**, bytecode from `contracts` PR #1. `WKASH`
   is deliberately not a preinstall (post-genesis deploy, see §1, §2). What is
   left of Phase 2 is step 5's module work.
5. Build what D4/D5/D6/D9/D12 decided (all `konstellation`/`contracts` unless noted):
   - **D4 (emission):** custom `x/mint`-equivalent module implementing
     stake-based issuance (`∝ √(total bonded)`), wired alongside D5's burn.
     Not started.
   - **D5 (base fee):** custom fee-collector wiring in `app.go` to burn the
     EIP-1559 base fee instead of routing it through `x/distribution`. Not
     started — natural to build alongside D4 since they interact.
   - **D6 (compliance):** a compliance precompile at a fixed address exposing
     `isVerified(address)` to Solidity, plus whatever freeze-list authority/
     governance design backs it (§10 risks apply: freeze-authority key
     management, potential legal-obligation-to-freeze exposure — flag for
     legal review before shipping, not just engineering). Not started.
   - **D12 (vesting):** `contracts/src/vesting/` — Solidity vesting
     contracts. Fully unblocked now; not started.
   - **D9 (audit):** start scoping calls with Informal Systems now (lead
     times run weeks to months) — but per §12, actually schedule the audit
     once Phase 3 + D6 are stable, not before.
   - **D7/D8 (whitepaper):** the validator-decentralisation roadmap (D7) and
     the bridge/value-ceiling sequencing (D8, recorded in `ENGINEERING.md §11`)
     both need writing into `whitepaper`, which is currently `init`-only.
6. Phase 3: `x/circuit` wired with multisig authority, IBC rate-limit middleware
   (§13). Both are `app.go` wiring, no fork. IBC rate limiting is also a
   prerequisite for D8's post-launch bridge sequencing.
7. `tests/e2e` (interchaintest): first test should be the one upstream lacks —
   an EVM transfer *to a module account* must be rejected (§4.1.1 coverage gap).
8. `networks/testnet-1/`: genesis comes straight from `konstellationd init
   --chain-id testnet-1`; record its sha256 (§6.2).
9. `.github` repo: org-wide CODEOWNERS. (`ENGINEERING.md`, `CLAUDE.md`,
   `STATUS.md`, `wt` already live there; `bootstrap.sh` recreates the org dir.)
10. `infra`: testnet-1 scaffold committed locally (`0b011f4`), not pushed, not
    yet a real deployment — see `infra/README.md` "Known gaps". Not blocking
    anything above; runs in parallel given terraform/ansible lead time. Before
    a real `terraform apply`: pick the state backend, stand up a bastion +
    monitoring host (neither has a terraform module yet), and fill in the
    empty `konstellationd_version`/`*_sha256` vars once `konstellation` cuts a
    release (waits on step 4-7 above).

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
