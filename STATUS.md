# Konstellation — Status & Handoff

**Updated:** 2026-09-13. Read after `ENGINEERING.md`. This file is *state*: where we
are, why things look the way they do, and what is next. `ENGINEERING.md` is *policy*.
When they disagree, `ENGINEERING.md` wins and this file is stale — fix it.

---

## 1. Where we are

Launch sequence (`ENGINEERING.md §15`):

| Phase | Status |
|---|---|
| 0 — scaffold `konstellation`, pin cosmos/evm, zero local replaces | **done** — PR #1 |
| 1 — govulncheck clean, CI green, dependency graph verified | **done** — PR #1, six review passes, 23 findings fixed |
| 2 — customise: genesis params, preinstalls, custom modules | **next** |
| 3 — safety rails (§13) | not started |
| 4+ | not started |

`konstellation` PR #1: https://github.com/Konstellation-Network/konstellation/pull/1
— branch `scaffold`, green on `build-test` / `lint` / `binary` (govulncheck). Merge
it (squash recommended) before doing anything else in that repo.

All other repos (`networks`, `contracts`, `infra`, `explorer`, `docs`, `whitepaper`,
`chain-config`, `faucet`, `.github`) exist on GitHub, private, with an `init`
commit only.

## 2. Decisions made on 2026-09-13 (all recorded in ENGINEERING.md)

| | Value | Where |
|---|---|---|
| D1 EIP-155 ids | mainnet **5667**, testnet-1 **56671**, local/unknown **56670** | §1, §11 |
| D2 token | **KASH**, base denom `esp`, 18 decimals, no precisebank | §1, §11 |
| D3 bech32 | `kons` | §1, §11 |
| D11 (partial) | gov min deposit **10 KASH**, expedited **50 KASH** | §11 |
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
| D10 | staking params | §11 has sensible numbers; also decide `min_gas_multiplier` |
| D11 | gov voting period / quorum / threshold | 3–5 days at launch; deposits already set |
| D12 | vesting | Solidity contracts, not `x/auth` vesting — confirm and build in `contracts` |
| **D13 (new)** | **Krakatoa app-side EVM mempool** | Currently ON (upstream default). Independent of BlockSTM. Per-node `app.toml` setting but all validators must agree. Not discussed in §7.3 beyond mechanics — needs an explicit decision. |
| §17 | owners for patch-watch etc. | still all **unassigned**; v0.7.3 shipped ten days before anyone noticed |

## 5. Next steps, in order

1. Merge PR #1.
2. Phase 2 in `konstellation`: set D10/D11 params in `app/genesis.go` (use the
   `kash(n)` helper in `app/config/chain.go` for 18-decimal amounts); decide D13.
3. Phase 3: `x/circuit` wired with multisig authority, IBC rate-limit middleware
   (§13). Both are `app.go` wiring, no fork.
4. `tests/e2e` (interchaintest): first test should be the one upstream lacks —
   an EVM transfer *to a module account* must be rejected (§4.1.1 coverage gap).
5. `networks/testnet-1/`: genesis comes straight from `konstellationd init
   --chain-id testnet-1`; record its sha256 (§6.2).
6. `.github` repo: org-wide CODEOWNERS; consider moving `ENGINEERING.md`,
   `CLAUDE.md`, `STATUS.md` there (they are currently only on this machine —
   the org root is not a git repo).

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

Six automated review passes (`/code-review pr#1`), each reproducing findings
against the live branch. Trend: 6 → 6 → 3 → 4 → 1 → 3 findings. Every finding was
reproduced before fixing and re-verified after. The reviewer repeatedly found
the *next* crack in the chain-id story, which is why §1 now states the
invariant explicitly. Expect the same reviewer to run on future PRs; write
commits that a reviewer can verify without the chat.
