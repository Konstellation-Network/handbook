# Konstellation Network — Engineering Context

**Audience:** coding agents and engineers working on any Konstellation repo.
**Status:** pre-testnet. Nothing here is deployed yet.
**Last updated:** 2026-09-29 (D7 re-decided: **three networks, Solana-style** — `devnet-1` (1 validator, EIP-155 56672, dapp developers), `testnet-1` (4 validators, ops rehearsal), `konstellation-1` (4 validators); new D18; §1, §9.4, §11, §15, §18 updated. 2026-09-21: D17: EVM fork = Prague, Osaka not enabled; contracts move to solc 0.8.37/prague. 2026-09-20: D7 re-decided: 10 foundation-run validators, admission permissioned, both networks; D16 admission via x/circuit; D12 team 10 % liquid at TGE; §9.4/§15/§18 reconciled; D12 vesting built + WKASH address pinned in `contracts`; §5.2, §6.3–6.7, §12, §17, §18 updated for the seven non-chain repo branches — see `STATUS.md` §1/§5a; earlier: D6 x/compliance built, PR #10; D6 list semantics + authority decided; team vesting revocable; testnet gov profile built (PR #7); D6 re-decided to a chain-wide `x/compliance`; §18 testnet-vs-mainnet matrix added; D4 F = 1265 on a 1 B KASH supply; D4–D9, D12 decided — all numbered open decisions in §11 are now
resolved; WKASH renamed from WKONS)

Load this document as context before working in any `konstellation-network/*` repo.
Section 2 contains hard constraints that must not be violated without an explicit
human decision recorded in this file.

---

## 1. What we are building

Konstellation is a sovereign Layer 1 blockchain built on the Cosmos SDK with an
EVM execution layer. It is EVM-compatible: Solidity contracts, Ethereum JSON-RPC,
MetaMask/Rabby wallet support, Blockscout explorer.

The chain will launch with **real user funds from day one** and a validator set of
**4 foundation-run validators, admission permissioned** (D7, D16). Three networks
(D18): `devnet-1` for dapp developers, `testnet-1` for validator and upgrade
rehearsal, `konstellation-1` for users.
Security posture is therefore
conservative by default.

**Naming conventions used throughout:**

| Item | Value | Status |
|---|---|---|
| GitHub org | `konstellation-network` | decided |
| Node binary | `konstellationd` | decided |
| Chain (display) | Konstellation | decided |
| Devnet network id | `devnet-1` | decided 2026-09-29 (D18) |
| Testnet network id | `testnet-1` | decided |
| Mainnet network id | `konstellation-1` | decided |
| Token symbol | KASH | decided 2026-09-13 (D2) |
| Base denom | `esp` (18 decimals; 1 KASH = 10^18 esp) | decided 2026-09-13 (D2) |
| Bech32 prefix | `kons` | decided 2026-09-13 (D3) |
| EIP-155 chain ID, mainnet | **5667** | decided 2026-09-13 (D1) |
| EIP-155 chain ID, testnet | **56671** | decided 2026-09-13 (D1) |
| EIP-155 chain ID, devnet | **56672** | decided 2026-09-29 (D18); verified absent from `ethereum-lists/chains` the same day |
| EIP-155 chain ID, local dev | **56670** | decided 2026-09-13 (D1 follow-up): unlisted Cosmos chain-ids get this, never a real network's id |
| Where the EIP-155 id lives | `app.toml` → `[evm] evm-chain-id` | **Invariant: `genesis.json` decides the network; everything else is checked against it, in both directions.** (1) A known network (`konstellation-1`, `testnet-1`, `devnet-1`) runs only with its own EVM id. (2) A real network's EVM id (5667, 56671, 56672) is used only by that network — any other chain-id running with one refuses to start, because a tx signed there would replay on the real network. `init` writes/reconciles `app.toml` to satisfy this and prints any change; at startup a `--chain-id` or `client.toml` value disagreeing with genesis (honouring `genesis_file`) is an error naming both files; `app/config.ValidateEVMChainID` enforces (1) and (2). Six review passes converged on this; do not reintroduce any path that trusts a per-node file over genesis. |

---

## 2. Hard constraints

These are non-negotiable. If a task appears to require violating one, stop and
escalate to a human rather than working around it.

### 2.1 Never fork upstream Cosmos repositories

`cosmos/evm`, `cosmos/cosmos-sdk`, `cometbft/cometbft` and `cosmos/ibc-go` are
consumed **as Go module dependencies only**. There must never be a repo named
`evm`, `cosmos-sdk`, `cometbft` or `ibc-go` inside the `konstellation-network` org.

Rationale: in August 2026 a critical balance-underflow bug (GHSA-7g4w-cg88-2cq2)
drained six Cosmos EVM chains of roughly USD 5.72M. The fix had existed on
`cosmos/evm` `main` since 15 May but was not backported to release branches until
19 August. Every fork hop between upstream and a running chain adds latency to
security patches. MANTRA's own post-mortem stated that twenty hours was not a
realistic window to coordinate a state-breaking upgrade across 38 validators.

### 2.2 No local `replace` directives

`go.mod` must contain **zero** `replace` directives pointing at anything the
Konstellation org controls. The only permitted `replace` lines are the ones
copied verbatim from the upstream `cosmos/evm` `go.mod` (currently a go-ethereum
fork pin).

`tests/e2e/go.mod` is a separate module (added 2026-09-19) so interchaintest's
dependency tree stays out of the binary's. It carries interchaintest's own
third-party pins (`gogo/protobuf`, `go-schnorrkel`, `btcec`, `goleveldb`,
`go-subkey`), copied verbatim from its `go.mod`; none is org-controlled and none
touches the four protected modules. Nothing in it links into `konstellationd`;
`make verify-deps` covers the binary's `go.mod`, which is the one that matters.

Verification:

```bash
cd ~/src/konstellation
grep -n "^replace" go.mod          # must match upstream only
go mod why github.com/cosmos/evm   # must not resolve to a local path
```

### 2.3 Pin to tags and commit SHAs, never branches

A `replace` or `require` pointing at a branch name means an upstream force-push
silently changes what validators execute.

### 2.4 Minimum safe versions

`cosmos/evm` **must be v0.7.3 or later**. Versions below v0.6.2, and v0.7.0 –
v0.7.2, contain unpatched critical vulnerabilities. See §4.

### 2.5 BlockSTM is OFF at launch

Parallel execution ships disabled. See §7.3 for the rationale and the enablement
plan.

### 2.6 Never build binaries on a validator

All release binaries come from CI in the `konstellation` repo, reproducibly built,
with published SHA256 checksums.

### 2.7 Never run two nodes with the same `priv_validator_key.json`

Double-signing is unrecoverable and slashes 5% of stake. This applies during
migrations, failovers, and testing.

---

## 3. Version matrix

Current target stack (the Cosmos "2026.1" release family):

| Component | Version | Notes |
|---|---|---|
| Go toolchain | `go 1.26.0` (min; raised from cosmos/evm's 1.25.9 by the 2026-09-13 dependency bumps) + `toolchain go1.26.8` | Go 1.25 left the support window in 2026-08; CI on 1.25.9 flagged five stdlib advisories. The `toolchain` line pins the compiler everyone builds with — bump it to the latest supported patch as part of every release. |
| `github.com/cosmos/evm` | **v0.7.3** | latest release; cut 3 Sep 2026. Security fix, state-breaking. |
| `github.com/cosmos/cosmos-sdk` | v0.54.2+ | 2026.1 family |
| `github.com/cometbft/cometbft` | v0.39.3 | |
| `github.com/cosmos/ibc-go/v11` | v11.x | |
| go-ethereum | v1.17 via Cosmos fork | applied through `replace` |
| OpenTofu | **1.12.x** (1.12.6 used for every infra check to date) | `infra/terraform/**/versions.tf` still says `required_version >= 1.9.0`; tighten it to the pinned minor with the first apply (§9.1). |
| Release build / target OS | built in `golang:1.26-bookworm` (glibc 2.36), **pinned by digest** (`sha256:a688600c…`), asset smoke-run in `debian:12` before publish | CGO is on and nothing static-links, so the artifact carries its build image's glibc. `infra/terraform` provisions debian-12; building on the runner's own Ubuntu (glibc 2.39) yields a binary that starts nowhere on the fleet. Pinned as `BUILD_IMAGE`/`TARGET_IMAGE` in `konstellation/.github/workflows/release.yml`; the same base as that repo's `Dockerfile`. Move both if `infra` moves the fleet. The digest is bumped by hand, with the Go toolchain row or to take a Debian security rebuild — `docker buildx imagetools inspect golang:1.26-bookworm`. |

Prior generation, for reference only — do not target: cosmos/evm v0.6.x runs on
Go 1.23, SDK v0.53.x, CometBFT v0.38.x, ibc-go v10, geth v1.15.

**Hard requirement inherited from cosmos/evm:** only **18-decimal EVM gas tokens**
are supported. Non-18-decimal configurations are unsupported. If the Cosmos-side
base denom is 6-decimal, `x/precisebank` must be wired to extend it to 18 for the
EVM. This is not changeable after genesis.

---

## 4. Security context

### 4.1 Known advisories against `cosmos/evm`

| Advisory | Date | Component | Fixed in |
|---|---|---|---|
| GHSA-mjfq-3qr2-6g84 / GO-2025-3684 | May 2025 | partial precompile state writes | pre-0.6 |
| GHSA-8pfh-j44r-f654 / GO-2025-4041 | Oct 2025 | — | pre-0.6 |
| ISA-2025-004 | 2025 | — | pre-0.6 |
| GHSA-54gx-3cgr-7mfm (ASA-2026-002) | Mar 2026 | ICS20 precompile | **v0.6.0** |
| GHSA-7g4w-cg88-2cq2 | Aug 2026 | balance underflow (SubBalance) | **v0.6.2 / v0.7.2** |
| GHSA-367m-g444-9mg3 | Sep 2026 | non-atomic StateDB commit + AddBalance overflow | **v0.7.3** |

ASA-2026-002 is rated CVSS 9.3 Critical: incorrect state handling during nested
EVM execution let the same balance be spent more than once in a single
transaction. It cost the Saga EVM network approximately USD 7M in January 2026.

GHSA-7g4w-cg88-2cq2 affects `< 0.6.2` and `>= 0.7.0 < 0.7.2`. The fix is upstream
PR #1176, the SubBalance underflow guard.

GHSA-367m-g444-9mg3 (critical, published 3 Sep 2026, single "Merge commit from
fork" between v0.7.2 and v0.7.3): `StateDB.Commit()` wrote dirty state objects
directly to the live context one at a time, so a failure on a later object left
earlier ones — including credits — already persisted. v0.7.3 stages the commit
through a `CacheContext` and flushes only on success, and adds an `AddBalance`
overflow guard mirroring the v0.7.2 `SubBalance` fix. Reviewed 2026-09-13 by
diffing `x/vm/statedb/`; the release notes say only "important security fixes".

#### 4.1.1 Verification record — pinned tag v0.7.3 (2026-09-13)

Re-verified after reports that the GHSA-7g4w-cg88-2cq2 advisory omitted two of
the changes needed for a complete fix. Method: `git log`/`git diff` on the
reference clone, `git tag --contains` per commit, byte-for-byte comparison of
the module cache against the tag, and a manual trace of the transaction path.

| Fix | Upstream PR / commit | First tag | Files |
|---|---|---|---|
| Locked-balance snapshot on statedb account | #1187, backport #1189 (`ae2db4f1`, 2026-05-20) | v0.7.1 (present in v0.7.2, v0.7.3) | `x/vm/statedb/state_object.go`, `x/vm/keeper/statedb.go` |
| Module-account guard on balance writes | `fb82a3f8` "Merge commit from fork" (2026-07-27, no public PR) | v0.7.1 (present in v0.7.2, v0.7.3) | `x/vm/keeper/statedb.go` (+6/−2) |
| `SubBalance` underflow guard | #1176, backport #1254 (`0182da19`) | v0.7.2 | `x/vm/statedb/state_object.go`, `precompiles/common/utils.go` |
| Atomic `Commit()` + `AddBalance` overflow guard | `c3ae9067` "Merge commit from fork" (GHSA-367m-g444-9mg3) | v0.7.3 | `x/vm/statedb/statedb.go`, `x/vm/statedb/state_object.go` |

Note: the module-account guard is a type assertion, `acct.(sdk.ModuleAccountI)`,
not a helper named `IsModuleAccount` — a grep for the latter returns nothing and
must not be read as absence.

**Live path traced (v0.7.3), EVM tx → bank:**

```
StateDB.SubBalance                     x/vm/statedb/statedb.go:504
  └─ stateObject.SubBalance            state_object.go:157   underflow → panic
       └─ SetBalance (journal, dirty)  state_object.go:175
StateDB.Commit                         statedb.go:717        CacheContext, flush on success only
  └─ commitWithCtx                     statedb.go:756        for each dirty addr
       └─ keeper.SetAccount            x/vm/keeper/statedb.go:196
            └─ SetAccountBalance       :150   uses LockedBalanceSnapshot() captured at GetAccount (:42)
                 └─ SetBalanceWithLocked :169  isModule || isBlockedChange → ErrUnauthorized
                      └─ bankWrapper.SetBalance :192   ← the ONLY bank balance write in x/vm
```

`bankWrapper.SetBalance` has exactly one caller in `x/vm` and `precompiles/`
(non-test). The only unexported `setBalance` is the in-memory journal setter on
`stateObject`; it never reaches the bank. `DeleteAccount` (:336, write at :354) also goes
through `SetBalanceWithLocked`. No duplicated or unguarded path exists.

- `go list -m github.com/cosmos/evm` → `v0.7.3`, resolved to the module cache.
- `x/vm/statedb` and `x/vm/keeper` in the module cache are byte-identical to the
  v0.7.3 tag in the reference clone.
- Upstream `go test ./x/vm/statedb/` at v0.7.3: pass (incl. `TestCommitAtomicity`).
- **Coverage gap:** upstream has no direct unit test for the module-account guard
  in `SetBalanceWithLocked`. Covered since 2026-09-19 by
  `konstellation/tests/integration` (`TestEVMTransferToModuleAccountRejected`): a
  signed EVM transfer to each of four module accounts through the real app, asserting
  the guard's error and that nothing moved; and by the same-named test in
  `tests/e2e`, through `eth_sendRawTransaction` against a real node. The e2e test
  first showed what a user saw when the guard was the *only* check: the failed SDK tx
  is **not indexed as an Ethereum tx**, so `eth_getTransactionReceipt` said "not
  found", gas was charged, and the reason was only in CometBFT's `tx_search`
  (`eth_call`/`eth_estimateGas` never reach the stateDB commit, so they did not warn
  either). Fixed 2026-09-19 in `app/blocked_recipient.go`: the same condition
  (value > 0 to a module account or bank-blocked address) is checked in the ante
  handler and the mempool pre-check, so `eth_sendRawTransaction` refuses it with the
  reason and nothing is charged. The x/vm guard is untouched and remains the last
  line; value reaching a blocked address through an *internal* call still fails
  there, invisibly to `eth_*`.

**`govulncheck ./...` (2026-09-13): 11 findings reachable from our code.** Two
are Cosmos-specific and are **false positives** in the Go vulnerability DB:

| ID | Module | DB range | Reality |
|---|---|---|---|
| GO-2025-3684 (GHSA-mjfq-3qr2-6g84, ISA-2025-004) | cosmos/evm | `introduced: 0`, no `fixed` | fix `0fff8c14` (2025-05-13) is an ancestor of v0.7.3; in every tag since v0.2.0 |
| GO-2024-2584 (GHSA-86h5-xcpx-cfqc) | cosmos-sdk | `>= 0.50.0`, no `fixed` | fix `7dbed2fc` is an ancestor of v0.54.3; period-length and amount validation present in `x/auth/vesting/msg_server.go` |

The transitive third-party findings were resolved on 2026-09-13 by bumping
`require` lines (permitted by §2.2; the `replace` set is unchanged and
`verify-deps` confirms it): x/crypto 0.56.0, x/net 0.57.0, x/text 0.41.0,
grpc 1.82.1, otel 1.44.0, quic-go 0.60.0, webtransport-go 0.11.1,
pion/dtls/v3 3.1.4, pion/stun/v3 3.1.5, klauspost/compress 1.18.7. The Go
toolchain was pinned to 1.26.8 (Go 1.25 is out of support; §3).

Two third-party findings have no fixed version and are allow-listed with the
two DB false positives above:

| ID | Why accepted |
|---|---|
| GO-2026-5932 | Blanket "x/crypto/openpgp is unmaintained" notice. Only `openpgp/armor` is reachable, via `cosmos-sdk/crypto` (ASCII armor for `keys export`). No PGP cryptography. |
| GO-2026-4479 | `pion/dtls/v2` AES-GCM nonce; no fixed release exists. Reached only through `go-ethereum/p2p/nat` → `pion/stun/v2` (devp2p NAT traversal). konstellationd uses CometBFT p2p; the reachable symbol is `alert.Marshal`, not the ciphersuite. |

Mechanism: `scripts/vulncheck.sh` runs govulncheck (source mode nightly,
binary mode on PRs) and fails on any reachable finding not listed in
`.govulncheck-allowlist`. Every allow-list entry must point back to this
section. Re-review the list on every cosmos/evm or cosmos-sdk bump.

**Verdict: both fixes present in v0.7.3 and on the live path. govulncheck is
clean modulo the four justified entries above. Phase 1 gate met.**

### 4.2 The operational lesson

Cosmos Labs stated in its post-mortem that it had released patches for 37
vulnerabilities silently over the preceding 13 months without publicly describing
exploit paths. Both the v0.6.2 and v0.7.2 release notes said the release contained
important security fixes while omitting the actual backport from their changelogs —
the visible v0.7.2 changelog entry is a test refactor.

**Therefore:**

1. Treat every `cosmos/evm` patch tag as a security release until proven otherwise.
2. Diff every upstream release manually, focusing on `x/vm/`, `x/vm/statedb/` and
   `precompiles/`.
3. Target: build, test and be ready to ship within **24 hours** of any upstream tag.
4. Watch `github.com/cosmos/security` and the `cosmos/evm` releases feed.
5. A small validator set is a security advantage — a coordinated binary swap across
   5–10 nodes takes under an hour.

### 4.3 Continuous scanning

`govulncheck` runs on every PR and nightly in the `konstellation` repo. The nightly
run matters more: a new advisory can land against code nobody touched.

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...
```

---

## 5. Organisation map

```
konstellation-network/
│
├── konstellation          ← THE CHAIN. Produces konstellationd. Public.
├── networks               ← genesis, peers, upgrade instructions. Public.
├── contracts              ← preinstall Solidity + verification. Public.
├── infra                  ← terraform, ansible, runbooks. PRIVATE.
├── explorer               ← Blockscout deployment config. Public.
├── docs                   ← developer documentation site. Public.
├── whitepaper             ← versioned PDF releases. Public.
│
├── chain-config           ← npm package for dapp devs. Public. (pre-mainnet)
├── faucet                 ← testnet token faucet. Public. (pre-mainnet)
├── Scriipture             ← TypeScript DSL → Solidity compiler + CLI (npm `scriipture`). Public.
└── .github                ← shared workflows, CODEOWNERS template. (pre-mainnet)
                             (CODEOWNERS itself is per-repo — GitHub has no
                             org-wide default for it; see §17.)
```

**There is exactly one repo that produces an executable: `konstellation`.**
Everything else produces configuration, documentation, contracts or cloud resources.
`Scriipture` ships an npm package with a `scriipture` CLI entry point (a Node
script, like any npm tool). It is a developer tool that never runs on a node, so
it does not compete with `konstellationd`. Whether this rule should name it as
an exception is open (STATUS P31).

### 5.1 Relationships

```
  cosmos/evm v0.7.2 ─┐
  cosmos-sdk v0.54.2 ├─ imported via go.mod ──→ konstellation
  cometbft v0.39.3   │                             │
  ibc-go v11        ─┘                             │
                                                   │ make build
                                                   ▼
                                            konstellationd
                                            + SHA256 checksum
                                                   │
                       ┌───────────────────────────┤
                       ▼                           ▼
                  networks repo               GitHub Release
              (upgrade height +              (binary artifact)
               checksum recorded)                  │
                       │                           │
                       └──────────┬────────────────┘
                                  ▼
                            validators verify
                            checksum, stage via
                            cosmovisor, swap at
                            the governance height

  contracts ──(compiled bytecode)──→ networks/<net>/genesis.json
  infra ──(provisions)──→ the machines that run konstellationd
  explorer ──(reads)──→ an archive node with tracing enabled
  chain-config ──(publishes)──→ npm, consumed by dapp frontends
```

### 5.2 Cross-repo invariants

| Invariant | Enforced by |
|---|---|
| Genesis preinstall bytecode == compiled artifact | test in `contracts` |
| `networks/<net>/genesis.sha256` matches `genesis.json` | CI in `networks` |
| Every release tag has a checksum recorded in `networks` | `konstellation/RELEASING.md` |
| `chain-config` addresses match `contracts` deployments | `chain-config/test/invariant.test.ts` (reads `../contracts/preinstalls/*.json` and `../konstellation`, both directions; skips loudly if a sibling is absent) |
| Explorer RPC target is an archive node, not pruned | `infra` terraform **and** `explorer/scripts/check-rpc.sh` at stack start (chain id, state at block 1, `debug_traceTransaction`, WS) |
| Vesting-wallet addresses funded in `networks/<net>/genesis.json` == `contracts` `DeployVesting.s.sol predict()` output | test in `contracts` + `networks` CI — **to be written** (D12 built 2026-09-20) |

---

## 6. Repo structures

### 6.1 `konstellation` — the chain

**Testnet-1 state:**

```
konstellation/
├── app/
│   ├── app.go                 # module wiring, ante chain, precompile map
│   ├── encoding.go
│   ├── genesis.go
│   ├── preinstalls/           # verbatim copies of contracts/preinstalls/*.json, go:embed'd;
│   │                          # codeHash + EntryPoint↔SenderCreator pairing checked at init
│   └── upgrades/
│       └── noop.go
├── cmd/konstellationd/
│   ├── main.go
│   └── root.go                # bech32 prefix, default home dir
├── x/
│   ├── compliance/            # D6 (konstellation PR #10)
│   │   ├── keeper/            # lists, timelocked queue, EndBlock, msg + query servers, 7702 reset
│   │   ├── ante/              # chain-wide block-list enforcement, wraps cosmos/evm's ante
│   │   ├── ibc/               # ICS-20 receive gate: no IBC funding of a frozen address (§18)
│   │   ├── precompile/        # read-only ICompliance at 0x…0900
│   │   └── types/             # generated from proto/konstellation/compliance/v1
│   └── ratelimit/             # §13.2 / D15: IBC value-flow quotas, v1 + v2 middleware
│       ├── keeper/            # limits, flows, windows, packet parsing
│       ├── v2/                # IBC v2 middleware
│       └── types/             # generated from proto/konstellation/ratelimit/v1
├── proto/                     # buf; `make proto-gen` (gocosmos + grpc-gateway)
├── tests/
│   ├── integration/           # the real app in-process, driven with signed txs (`make test-integration`, `-tags test`)
│   └── e2e/                   # real nodes under interchaintest, own go.mod (`make docker-build && make test-e2e`)
├── Dockerfile                 # konstellation:e2e — for tests/e2e and local multi-node runs, NOT the release artifact (§2.6)
├── .github/workflows/
│   ├── ci.yml                 # build, unit, lint
│   ├── vuln.yml               # govulncheck: PR + nightly cron
│   └── release.yml            # signed tag → two independent builds, checksums must agree, provenance, GitHub Release (§2.6)
├── RELEASING.md               # the release checklist: tag, verify, record in networks/RELEASES.md
├── go.mod                     # zero local replaces
├── go.sum
├── Makefile
└── local_node.sh
```

**Added before mainnet:**

```
├── app/upgrades/
│   ├── v2/upgrade.go          # one package per release, permanently
│   └── v3/upgrade.go
├── x/
│   └── compliance/            # D6 (mint needs no module: D4 is x/mint's MintFn)
├── .github/
│   └── CODEOWNERS             # app.go and x/ require a second reviewer
├── SECURITY.md
└── audits/
    └── YYYY-MM-<firm>.pdf
```

A near-empty `x/` directory is the success signal. Every file there is code
someone must audit and the team must patch forever.

### 6.2 `networks`

```
networks/
├── devnet-1/                   # dapp developers; same files as testnet-1, 1 gentx (D18)
├── testnet-1/
│   ├── genesis.json
│   ├── genesis.sha256
│   ├── chain.json              # cosmos chain-registry format
│   ├── seeds.txt
│   ├── persistent_peers.txt
│   └── README.md               # join instructions, min hardware
├── konstellation-1/            # created at mainnet genesis ceremony
│   ├── genesis.json
│   ├── genesis.sha256
│   ├── gentx/                  # one pre-signed tx per launch validator
│   ├── addrbook.json
│   ├── snapshots.md            # state-sync RPCs + snapshot URLs
│   └── upgrades/
│       ├── v2-<name>.md        # height, binary URL, sha256, config deltas
│       └── v3-<name>.md
├── scripts/networks.sh         # launch validator count per network (1 / 4 / 4), checked by verify.sh and gen-genesis.sh
└── README.md
```

`upgrades/*.md` is the public artifact operators read during a coordinated
upgrade. Each file must contain: upgrade name, halt height, binary download URL,
SHA256, any `config.toml` or `app.toml` changes, and a rollback note.

### 6.3 `contracts`

```
contracts/
├── src/
│   ├── WKASH.sol                # wrapped native token; post-genesis deploy at 0x34Ab8285C63b876717C2c56151700D02623559bE
│   └── vesting/                # D12 Solidity vesting — NOT x/auth vesting accounts (OpenZeppelin v5.7.0 base)
│       ├── KonstellationVestingWallet.sol   # non-revocable: treasury, community tranches
│       ├── RevocableVestingWallet.sol       # team: one-shot revoke() by the foundation multisig
│       └── VestingSchedules.sol             # the one place TOKENOMICS.md §7's numbers live
├── script/
│   ├── VerifyPreinstalls.s.sol
│   ├── DeployWKASH.s.sol       # Create2Deployer + salt keccak256("konstellation-network/contracts:WKASH:v1")
│   ├── DeployVesting.s.sol     # JSON config → CREATE2 wallets; predict() gives genesis allocation addresses
│   ├── lib/Create2Deployer.sol
│   ├── lib/InitCodePins.sol    # canonical creation-code hashes; every script refuses a drifted build
│   └── config/vesting.example.json
├── CODEOWNERS                  # separate rows for src/vesting/ and preinstalls/
├── preinstalls/
│   ├── Multicall3.json         # 0xcA11bde05977b3631167028862bE2a173976CA11
│   ├── Permit2.json
│   ├── EntryPointV07.json
│   ├── SenderCreatorV07.json   # 0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C — required by EntryPointV07
│   ├── EntryPointV08.json
│   ├── SenderCreatorV08.json   # 0x449ED7C3e6Fee6a97311d4b55475DF59C44AdD33 — required by EntryPointV08
│   └── Create2Deployer.json
├── test/
│   ├── GenesisBytecode.t.sol   # asserts genesis blob == compiled artifact
│   ├── DeployWKASH.t.sol       # pins the WKASH address; fails if code/solc/optimizer/evm_version moves it
│   ├── DeployVesting.t.sol
│   └── vesting/
└── foundry.toml                # bytecode_hash = "none", cbor_metadata = false (see below)
```

**Deterministic addresses (2026-09-20):** WKASH and every vesting wallet are
CREATE2 deploys through the preinstalled `Create2Deployer`
(`0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2`), so their addresses are known
before genesis and `genesis.json` can fund a vesting wallet at block 0. Compiled
bytecode is metadata-free so a comment edit cannot move an address; the trade-off
is that Blockscout source verification is a *partial* match. **Vesting is
native-KASH only:** OpenZeppelin's ERC-20 `release(token)` path is disabled because
cosmos/evm's `werc20` precompile presents the native balance as an ERC-20, which
would let a beneficiary withdraw the same KASH twice.

Preinstalls must sit at their **canonical mainnet addresses** — wallet SDKs and
tooling hard-code them.

A preinstall never runs its constructor, so anything its constructor would have
deployed must be preinstalled too. Each ERC-4337 `EntryPoint` `CREATE`s a
`SenderCreator` (nonce 1) and stores the address as an immutable; without it
every UserOp carrying `initCode` and every `getSenderAddress()` reverts, and the
address (`CREATE(entryPoint, 1)`) cannot be recreated post-genesis.
`konstellation/app/preinstalls` enforces the pairing at `konstellationd init`
(see §6.1).

### 6.4 `infra` — private, permanently

```
infra/
├── terraform/
│   ├── modules/{hetzner,gcp}/{validator,sentry,rpc,archive,bastion,monitoring,cosigner}/
│   └── envs/{devnet-1,testnet-1,konstellation-1}/   # horcrux_mode, bastion_ssh_entry, monitoring_cloud, explorer_cidrs
├── ansible/
│   ├── roles/{node,cosmovisor,horcrux,monitoring_server,firewall,bastion,wireguard}/
│   └── inventories/{testnet-1,konstellation-1}   # hosts.yml + ssh_config generated by terraform
├── monitoring/
│   ├── prometheus/alerts.yml
│   └── grafana/
├── CODEOWNERS                  # separate rows for terraform/envs/konstellation-1/ and runbooks/
└── runbooks/
    ├── on-call.md              # §17 rota mechanics; schedule TBD
    ├── emergency-halt.md
    ├── coordinated-upgrade.md
    ├── validator-key-rotation.md
    └── incident-comms.md
```

Cross-cloud design (2026-09-20, `close-known-gaps`): each cloud has a bastion;
private-only hosts accept SSH only from their cloud's bastion and operators only
from `operator_ssh_cidrs`. A WireGuard tunnel between the two bastions, plus cloud
routes for each other's /24, is what lets one monitoring host and three
distributed Horcrux cosigners span both clouds. Hetzner hosts without a public
IP have no egress at all, so the Hetzner bastion is also the NAT gateway; GCP
uses Cloud NAT. The archive node binds JSON-RPC/WS to its private address
(`jsonrpc_bind_address`) so the explorer can reach it; everything else stays on
loopback except `rpc`. Nothing has been applied against real infrastructure.

Private because it is a map of where the validators live.

### 6.5 `explorer`

```
explorer/
├── docker-compose.yml          # one stack for every network, selected with --env-file
├── .env.local                  # dev chain 56670 — the only concrete endpoints
├── .env.devnet-1               # TODO-* hostnames; CI enforces they stay placeholders
├── .env.testnet-1              # same
├── .env.konstellation-1
├── envs/                       # per-service common env, every knob commented
├── nginx/
├── scripts/check-rpc.sh        # §5.2 archive/tracing preflight; backend won't start until it passes
├── CODEOWNERS
└── branding/                   # logo (placeholder), token-metadata.json
#   compose services: backend, nft-media-handler (worker), frontend, stats, verifier-init + verifier,
#   user-ops-indexer, proxy; profile local-s3: minio + init + proxy (:3082)
```

**Dependency:** Blockscout requires `debug_traceTransaction`, so it must point at
an **archive node with tracing enabled**, not a pruned RPC. Provision that node in
`infra` before standing up the explorer. **Against cosmos/evm v0.7.3,
`ETHEREUM_JSONRPC_GETH_TRACE_BY_BLOCK` must be `false`**: its
`debug_traceBlockByNumber` omits per-entry `txHash` and Blockscout's block-level
parser crashes; per-tx tracing works (found on the live dev-chain run, 2026-09-20).
Images are pinned tag@digest. **Decided 2026-09-20:** testnet-1 ships the pinned
public images (backend 9.0.2 / frontend v2.3.5) because they demonstrably work;
the public registry lags source by two majors (v10/v11 changed the database
schema — new internal-transactions key, numeric address ids), so before the
mainnet explorer goes live decide again between the public images and building
from the release tag into an org registry (see `explorer/README.md`). The
`explorer` repo is *only* configuration and branding for a Blockscout deployment
we host — there is no in-house explorer. **NFT media handler is on (decided
2026-09-21):** it runs as a second backend container in worker mode and needs an
S3-compatible bucket reachable over https:443 with anonymous read per network
(9.0.2 hard-codes the scheme/port) — provision it in `infra`; locally the
`local-s3` profile runs MinIO. The source verifier must run `linux/amd64` (solc
binaries) and its compiler volume must be owned by uid 1001 — both handled in
compose; expect *partial* matches for our metadata-stripped bytecode.
**Deployment requirements (review, 2026-09-21):** the stack publishes ports on
loopback only, behind an ingress that terminates TLS and **sets** (never appends)
`X-Forwarded-For` / `X-Forwarded-Proto` — the backend rate-limits on the leftmost
public XFF address; Erlang distribution lives on an `internal: true` compose
network and the stack must never be attached to a platform-shared network; the
media worker fetches arbitrary token URIs, so it needs an egress policy denying
RFC 1918 + `169.254.0.0/16` before NFT media is enabled on a real network (`infra`).

### 6.6 `docs`

```
docs/
├── docs/
│   ├── quickstart.md           # add network to MetaMask, first tx
│   ├── rpc-endpoints.md
│   ├── contracts.md            # preinstall addresses
│   ├── run-a-validator.md      # external operators will find the gaps here
│   ├── troubleshooting.md      # errors a user or operator can hit and what they mean
│   └── upgrades.md             # historical upgrade log
├── CODEOWNERS
└── docusaurus.config.js
```

### 6.7 `whitepaper`

```
whitepaper/
├── src/whitepaper.tex          # \input's src/sections/*.tex
├── src/sections/
├── releases/v1.0.pdf           # versioned; never edited in place — CI refuses PRs that touch releases/
├── Makefile                    # pdf / check / release VERSION=vX.Y
├── CODEOWNERS
└── CHANGELOG.md
```

Kept separate from `docs` because exchanges and investors cite specific versions,
and tokenomics changes need an auditable history.

---

## 7. Imported vs implemented

### 7.1 Imported — do not reimplement, do not fork

| Provided upstream | Package |
|---|---|
| EVM execution, statedb | `cosmos/evm` `x/vm` |
| ERC-20 ↔ IBC token representation | `cosmos/evm` `x/erc20` |
| EIP-1559 fee market | `cosmos/evm` `x/feemarket` |
| 6→18 decimal bridging | `cosmos/evm` `x/precisebank` |
| Precompiles: staking, distribution, bank, gov, ICS20, werc20, bech32, **p256** | `cosmos/evm` `precompiles/` |
| Ethereum JSON-RPC (`eth_`, `net_`, `web3_`, `debug_`, `txpool_`) + WebSocket | `cosmos/evm` |
| EIP-712 signing (MetaMask signs Cosmos msgs) | `cosmos/evm` |
| Permissioned EVM access control lists | `cosmos/evm` `x/vm` params |
| Staking, distribution, gov, slashing, bank, auth | `cosmos-sdk` |
| Upgrade orchestration, evidence | `cosmos-sdk` |
| Circuit breaker (`x/circuit`) | `cosmos-sdk` **`contrib/x/circuit`** — deprecated by Cosmos Labs in v0.54, unmaintained, outside their bug bounty. Used anyway (decided 2026-09-19, D14): ~1.3k stable lines, baseapp's `SetCircuitBreaker` hook is first-class. If a later SDK drops it, vendor it into `x/`. **Re-check on every cosmos-sdk bump**: `app/upstream_pin_test.go` pins the SDK version and fails with the checklist (package still shipped, `git log -- contrib/x/circuit`, router hook and `IsAllowed` semantics unchanged). |
| feegrant, authz | `cosmos-sdk` |
| Consensus, p2p, mempool, state sync, snapshots | `cometbft` |
| IBC clients, connections, channels, ICS20 | `ibc-go` |

### 7.2 Implemented in `konstellation`

- `app.go` module wiring and **ante handler chain composition**
- Custom precompiles (registered into the precompile map — does not need a fork)
- Custom modules under `x/`: `compliance` (D6), `ratelimit` (§13.2, D15 — written
  here because no rate-limiting module exists for ibc-go v11), and the
  `compliance/ibc` receive gate (§18)
- One upgrade handler package per release
- Genesis parameter set
- Numeric EIP-155 chain ID and Cosmos chain-id string
- Bech32 prefix and denom configuration

### 7.3 BlockSTM and Krakatoa

Both landed in `cosmos/evm` v0.7.0. They are independent features.

**BlockSTM** is parallel execution under a software-transactional-memory scheduler,
with per-transaction object stores for bloom filtering, log indexing and gas
accounting. It bundles **virtual fee collection** — EndBlock fee settlement through
a per-transaction bank object store, 18-decimal chains only. It is always opt-in.

**Decision: launch with BlockSTM OFF, and virtual fee collection OFF with it**
(2026-09-13). `app.go` installs `txnrunner.NewDefaultRunner` and does *not*
call `EVMKeeper.EnableVirtualFeeCollection()`; EVM fees go through the classic
`authante.DeductFees` / `SendCoinsFromModuleToAccount` path. Virtual fee
collection works with the sequential runner, but it is a v0.7.0-new,
consensus-relevant fee path shipped as part of the parallel bundle; it gets
enabled in the same coordinated upgrade as `NewSTMRunner`. Rationale:

- Both critical 2026 bugs were balance-accounting bugs in the *sequential* path,
  which has years of production mileage. The parallel path has months.
- A new chain does single-digit TPS; parallel execution matters in the hundreds.
- Backing it out post-launch with funds on chain is an emergency state-breaking
  downgrade. Enabling it later is a planned governance upgrade with a tested
  rollback.

**Enablement plan:** run a **non-validating shadow node** with the parallel runner
from day one — same mainnet, same genesis, zero voting power. Compare its app hash
against validators every block. A divergence finds a BlockSTM bug for free with no
funds at risk. Flip the validators after a clean month.

The runner wiring is required in v0.7 either way. `vmrunner.SetRunner` installs the
baseapp tx runner wrapped with the EVM module's `PatchTxResponses` post-execution
fix-up; without it, `log.Index` and `transactionIndex` on receipts are wrong.

```go
// app/app.go
txDecoder := encodingConfig.TxConfig.TxDecoder()

// launch configuration
vmrunner.SetRunner(bApp, txnrunner.NewDefaultRunner(txDecoder))

// post-soak swap
// vmrunner.SetRunner(bApp, txnrunner.NewSTMRunner(...))
```

Imports: `github.com/cosmos/cosmos-sdk/baseapp/txnrunner`,
`vmrunner "github.com/cosmos/evm/x/vm/runner"`.

**Krakatoa** moves the EVM mempool from CometBFT into the application layer. If
enabled, every validator needs `mempool.type = "app"` in `config.toml` — CometBFT
v0.39 requires the app-side mempool type whenever the application supplies an EVM
mempool, the default is `"flood"`, and the node errors out at startup otherwise.

---

## 8. Glossary

| Term | Meaning |
|---|---|
| `go.mod` | Go dependency manifest. Equivalent to `package.json`. |
| `go.sum` | Cryptographic hashes of every dependency. |
| `x/` | Cosmos SDK convention: "extensions", i.e. modules. `x/bank` = the bank module. |
| `/` in paths | Directory separator. In `github.com/cosmos/evm`, it is host/org/repo. |
| Ante handler | Code running **before** a transaction's messages execute. A chain of decorators doing signature verification, nonce checks, fee deduction, gas setup. **Order is security-critical** — fee deduction before signature verification would let anyone drain any account. |
| Post handler | Runs after message execution. |
| `min_self_delegation` | A **per-validator** field set in `MsgCreateValidator`, not a genesis param. Denominated in **base units** of the bond denom. At 18 decimals, 1 KASH = `1000000000000000000`. The validator is jailed if self-delegation drops below it. Can be raised, never lowered. A chain-wide floor requires a custom ante decorator. |
| `max_validators` | Genesis staking param. Size of the active set. Set high (100+) even at launch. |
| gentx | A pre-signed `create-validator` transaction merged into `genesis.json` before block zero. |
| Cosmovisor | Upgrade orchestrator. Swaps binaries at a governance-set halt height. |
| Sentry | A public-facing node that shields a validator, which has no public IP. |
| horcrux | Threshold signing across multiple cosigners. Gives HA and makes double-signing cryptographically hard. |

---

## 9. Infrastructure

### 9.1 Tool responsibilities

| Tool | Job |
|---|---|
| **OpenTofu** (`tofu`) | Provisions cloud resources: VMs, disks, firewall rules, DNS. Works across AWS, Hetzner, GCP, Vultr from one codebase. The code is Terraform HCL under `infra/terraform/`; "terraform" elsewhere in these docs means this layer, and the command is `tofu`. |
| **Ansible** | Configures servers that already exist: installs the binary, writes `config.toml`, sets up systemd and Cosmovisor. |
| **Coolify / k8s** | Stateless app tier only: explorer, faucet, docs, indexers, bundler, RPC fleet. |

OpenTofu builds the house, Ansible furnishes it. Both are required.

**Decided 2026-09-30: OpenTofu, not HashiCorp Terraform,** for every `plan` and
`apply` against a real network. OpenTofu is the open-source fork (Linux
Foundation, MPL-2.0) made after Terraform moved to the BSL in 2023; it is what is
installed and what every infra check so far has run. The two read the same HCL
today, but a state file written by one is not guaranteed to stay readable by the
other as they diverge, so each network's state is only ever touched by `tofu`.
Pin the version alongside the state bucket (STATUS P4) before the first apply.

**Do not run validators on Coolify or Kubernetes.** Validators need host-level
control (local NVMe tuning, systemd semantics, kernel networking) and strict
signing-key isolation. A platform that might reschedule a workload elsewhere is
the wrong abstraction for a process that must never run twice with the same key.

### 9.2 Topology

- **Sentry architecture, mandatory.** Validators: `pex = false`,
  `persistent_peers` = own sentries only, no public IP. Sentries:
  `private_peer_ids` = validator node ID so the address is never gossiped.
- **Key management:** horcrux threshold signing across 3+ regions, or tmkms +
  YubiHSM2. Horcrux preferred for a chain holding user funds.
- **Validator spec:** 8–16 vCPU, 32–64 GB RAM, 2–4 TB **local NVMe**, 1 Gbps.
  Network block storage costs block time — IAVL commit latency is disk-bound.
- **Provider spread:** diversify by ASN and jurisdiction. Mix bare metal
  (Hetzner, OVH, Latitude.sh, Equinix) with cloud (AWS, GCP). Avoid single-region
  and single-provider concentration.
- **Validator pruning:**

```toml
# app.toml
pruning = "custom"
pruning-keep-recent = "100"
pruning-interval = "10"
```

- **Archive nodes:** `pruning = "nothing"`, tracing enabled, at least two, not public.
- **Cosmovisor:** auto-download **OFF**. Binaries staged by hand into
  `$DAEMON_HOME/cosmovisor/upgrades/<name>/bin/` after checksum verification.
- **Monitoring:** `prometheus = true` in `config.toml` (port 26660), Grafana,
  tenderduty paging. Alert on missed blocks, falling peer count, block-time drift,
  disk headroom, and **no new blocks** — the last is the exploit tripwire.

### 9.3 Cross-cloud peering

Nodes find each other over the public internet on TCP 26656 regardless of provider:

```toml
# config.toml
seeds = "<node_id>@seed1.konstellation.network:26656"
persistent_peers = "<node_id>@10.0.1.5:26656,<node_id>@10.0.2.5:26656"
pex = false               # validators only
private_peer_ids = "..."  # on sentries: the validator's node_id
```

Terraform is per-provider (different resource types). Ansible is
provider-agnostic — one inventory spans the whole fleet.

### 9.4 Testnet vs mainnet coordination

| | devnet-1 | testnet-1 | konstellation-1 |
|---|---|---|---|
| Validators | 1, foundation-run; never admits others | 4, all foundation-run, permissioned (D7) | 4, all foundation-run at genesis, permissioned (D7); later admissions via D16 |
| Keys | foundation (see `infra` devnet-1 env) | foundation (Horcrux cosigners per §9.2) | foundation (Horcrux, dedicated cosigners mandatory) — plus each admitted operator's own |
| Upgrades | 2nd: after testnet-1, 1–2 weeks before mainnet, so dapps see it first; ansible + governance proposal | 1st: `ansible-playbook` across the fleet, **and** a governance proposal, so the gov path is rehearsed | 3rd: governance proposal + comms channel; ansible only for the foundation's own hosts |
| Emergency halt | `--halt-height` via ansible | `--halt-height` via ansible, rehearsed here first | `--halt-height` + Signal group once non-foundation validators exist |

Reconciled 2026-09-20, re-decided 2026-09-29 (D7, D18): **every launch validator
is foundation-run on every network**, 4 on testnet-1 and mainnet so testnet-1
rehearses exactly what mainnet will run, and 1 on devnet-1, which exists for dapp
developers and is not a rehearsal. Independent operators arrive only through the
D16 admission procedure, on testnet-1 and mainnet.

**Four equal validators tolerate exactly one failure** (CometBFT needs > ⅔ of
voting power: 3 of 4 keep producing blocks, 2 of 4 halt). Two consequences, both
binding on `infra`: the four must sit in **four separate failure domains** (which
domains is open, STATUS §5a P16), and while one validator is down for planned
work there is no margin left, so mainnet maintenance is one host at a time and
never during another incident.

Mainnet upgrade mechanics: signed release → upgrade doc in `networks` →
`MsgSoftwareUpgrade` setting the halt height → Cosmovisor swaps automatically.
Operators only need the binary pre-staged; they do not need to be awake.

---

## 10. Compliance design space

**D6 re-decided 2026-09-15: the ante-decorator row below, backed by an `x/compliance`
module, with a precompile on top so Solidity sees the same list.** (An earlier same-day
decision picked the precompile alone; the founders chose chain-wide coverage instead.) The
table is kept in full because the risks paragraph at the end now applies without
qualification. Enforcement lives at one of three levels:

| Level | Coverage | Cost |
|---|---|---|
| **Ante decorator** reading an `x/compliance` freeze list | every tx, native token included | ~300 lines Go |
| **Compliance precompile** at a fixed address | Solidity contracts call `isVerified(address)` | custom precompile, no fork |
| **Token contract** (ERC-3643 / T-REX) | that token only | pure Solidity |

**Freezing** is straightforward — the ante decorator rejects transactions touching
listed addresses. One EVM-specific wrinkle, decided 2026-09-19: **a block-list add
also clears any EIP-7702 delegation on the address** (`x/compliance/keeper/delegation.go`,
on the emergency, scheduled and governance paths alike). The ante cannot see internal
calls, so an EOA delegated to a smart-account wallet *before* the freeze would still
run that wallet's code when an EntryPoint or any forwarder called it — a clean relayer
could drain it with a UserOp the frozen key signed off-chain (reproduced live on
`cb6ace1`, and in `tests/integration`). Leaving that to governance was rejected: the
emergency path exists because three days is too long. Only the 23-byte `0xef0100‖addr`
form is touched — never real contract bytecode, so freezing a token contract does not
brick its holders — and only the code hash goes, not storage, so a lifted account is
restored by one new authorization. **Reversal** options, best to worst:

1. **Mint/burn controlled assets.** Burn at the thief, mint to the victim. What
   regulated stablecoin issuers do. Clean and auditable.
2. **Delayed settlement above a threshold.** A challenge window before large
   transfers settle. Prevents rather than reverses — the strongest design.
3. **Clawback role in the token contract.** Per-token, standard in ERC-3643.
4. **Governance state migration in an upgrade handler.** Nuclear. Requires a
   coordinated chain upgrade and sets a precedent.

**Protocol-level KYC:** an `x/compliance` module storing attestations (credential
hash, issuer, level, expiry, jurisdiction), PII held off-chain by a licensed
provider, an ante decorator gating unattested senders, and a precompile exposing
status to Solidity.

**Risks that must be recorded in the whitepaper if this path is chosen:**

- The freeze authority becomes the highest-value key on the chain. Multisig from
  genesis, timelocked non-emergency actions, all actions logged on-chain.
- The ability to freeze can create a legal *obligation* to freeze, across multiple
  jurisdictions. That is an ongoing staffed function with liability attached.
- It permanently changes positioning. Some developers will not build on a chain
  with a freeze switch; some institutions will not touch one without.

Prior art to study: Provenance, Noble, Canton Network, Kinto, ERC-3643.

---

## 11. Open decisions

Each of these blocks something. Assign an owner and a date. The economic
parameters these decisions produced — and how they interact — are collected in
`TOKENOMICS.md`; that file is the source of truth for the *numbers*, this table
for the *decisions*.

| # | Decision | Blocks | Notes |
|---|---|---|---|
| D1 | ~~Numeric EIP-155 chain ID~~ **DECIDED 2026-09-13: mainnet 5667, testnet 56671**; devnet **56672** added 2026-09-29 (D18) | — | All verified absent from `ethereum-lists/chains` (5667/56671 on 2026-09-13, re-checked with 56672 on 2026-09-29). Register there before testnet launch (STATUS P25). |
| D2 | ~~Token symbol, base denom, decimals~~ **DECIDED 2026-09-13: KASH / `esp` / 18** | — | Native 18-decimal, no `x/precisebank`. `akash` deliberately avoided (Akash Network collision). Not changeable post-genesis. |
| D3 | ~~Bech32 prefix~~ **DECIDED 2026-09-13: `kons`** | — | |
| D4 | ~~Emission model~~ **DECIDED 2026-09-15: stake-based issuance, modelled on Ethereum's post-merge formula** — `annual issuance (KASH) = F × √(bonded KASH)`, **F = 1265**, chosen against a **1,000,000,000 KASH genesis supply** (8 % APR at 25 % bonded, 4 % at 100 %; yield = F ÷ √bonded). No bonded-*ratio* targeting loop like the SDK default. Pairs with D5's burn for a net issuance-minus-burn dynamic. | `app/issuance.go`, `app/config/chain.go`, whitepaper | No custom module: implemented as stock `x/mint`'s `MintFn` (SDK ≥ 0.53 hook), so `x/` stays empty. F is a protocol constant (like Ethereum's `BASE_REWARD_FACTOR`), changed only by upgrade, not gov. `blocks_per_year` is a gov param that must track real block time — re-derive from testnet-1 before mainnet. Stake concentration at `max_validators` 30 (D10): the curve is chain-wide and distribution stays pro-rata, so it adds no concentration incentive of its own. |
| D5 | ~~Base fee disposition~~ **DECIDED 2026-09-15: burn** the EIP-1559 base fee | `app/feeburn.go`, `app.go`, whitepaper | Replaces the SDK default of routing base fee through `x/distribution`. Built as an app-level EndBlock step: `baseFee × BlockGasUsed` burned from the fee collector before `x/distribution` sweeps it; tips still go to validators. Fee collector holds `Burner`. Combines with D4 for Ethereum-style net issuance. |
| D6 | ~~Compliance scope~~ ~~precompile only (2026-09-15, morning)~~ **RE-DECIDED 2026-09-15: `x/compliance` module with a chain-wide ante decorator**, plus a precompile exposing the same list to Solidity | `x/compliance` (the one custom module under `x/`), audit scope, positioning, whitepaper | See §10. The chain itself refuses any tx that touches a listed address — EVM and Cosmos, native KASH included — before execution; Solidity gets `isVerified(address)` / `isFrozen(address)` from a precompile backed by the same store. Accepted trade-off: widest coverage, the freeze key becomes the highest-value key on the chain, and the §10 legal-obligation and positioning risks apply in full and go in the whitepaper. **Semantics and authority decided 2026-09-15:** both lists — an *allowlist* (`isVerified`) that contracts may consult, and a *blocklist* (`isFrozen`) the ante decorator enforces chain-wide; the chain never requires allowlisting to transact, only blocklisting stops a tx. Authority: a foundation multisig; non-emergency list changes go through a 24 h on-chain timelock; an emergency freeze takes effect immediately but auto-expires after the timelock unless ratified; governance can override any entry and replace the authority. Every action is an on-chain event. Legal review before it ships. **Built: konstellation PR #10 (2026-09-16)** — `x/compliance` with a synchronous mempool pre-check so frozen parties get an immediate error at the JSON-RPC. **Bank-level binding built 2026-09-22 (PR #15):** the block list is also a bank `SendRestriction` and guards x/vm's balance writes, closing the werc20-allowance drain (STATUS P20); a frozen address's native KASH does not move, while four protocol completions (gov deposit refunds, ICS-20 refunds, unbonding, validator-removal commission) may still credit it — exemption table in `x/compliance/keeper/restriction.go`. Solidity ERC-20 balances are contract storage, outside the chain's reach: that is what `isFrozen()` is for. Not gated: an incoming IBC transfer to a frozen address (Phase 3 middleware). **Ratification mechanics (2026-09-16, from the PR #10 review):** scheduling the permanent add extends a live emergency freeze to that update's `execute_at`, so ratification never leaves a gap; an address under a live emergency freeze, or within one timelock after it lapsed or was lifted, cannot be emergency-frozen again — only the scheduled path or governance can hold a freeze past one period. |
| D7 | ~~Validator set model~~ ~~5–10 self-run (2026-09-15)~~ ~~10 foundation-run, 5 Hetzner + 5 GCP (2026-09-20)~~ **RE-DECIDED 2026-09-29 (founder): 4 validators at genesis on testnet-1 and konstellation-1, 1 on devnet-1 (D18), all foundation-run; the 4 in four separate failure domains (which domains: STATUS P16). Unchanged from 2026-09-20: `max_validators` 30 (D10); admission of further, independent operators is permissioned (mechanism D16), moving to permissionless in stages by governance.** Same model on testnet-1 and konstellation-1. | genesis, whitepaper, §15 phases 5–6 | Does not require undoing D10's PoS/staking wiring. "Permissioned" means *who may become a validator*, not who may delegate — delegation is open from genesis. The stages of opening (triggers, target set size, voting-period lengthening) go in the whitepaper roadmap; their dates are not decided. |
| D8 | ~~Launch value ceiling~~ **DECIDED 2026-09-15: no bridge on day one** | bridge, treasury | Immediate next steps once the chain is live: (1) soak period (§15 phase 9); (2) in parallel, build + audit the bridge contract and the IBC rate-limiting middleware (§13); (3) calibrate hard daily/total caps using soak-period usage signal; (4) open the bridge only once soak is clean, both are audited, and caps are set — enforced in the contract, never the frontend. The non-bridge §13 rails (`x/circuit`, halt drill) proceed regardless of bridge timing. |
| D9 | ~~Audit firm and scope~~ **DECIDED 2026-09-15: Informal Systems** | timeline, budget | Lead times run weeks to months — start scoping calls now. Scope should follow "audit the delta" (§12) once Phase 3 safety rails and the D6 compliance precompile are stable, not before. |
| D10 | ~~Staking params~~ **DECIDED 2026-09-14: DPoS, capped active set. Unbonding 21d, `min_commission_rate` 5%, `max_validators` 30, downtime slash 0.01%, double-sign slash 5%** | — | `max_validators` 30 (not the earlier 100+ draft) is a deliberate DPoS cap, not an SDK default carried over. Implemented in `app/config/chain.go` + `app/app.go` `DefaultGenesis`. |
| D11 | ~~Governance params~~ **DECIDED: min deposit ~~10~~ **1 000 KASH**, expedited ~~50~~ **5 000 KASH** (raised 2026-09-15 once a 1 B supply was assumed; was 10 / 50 from 2026-09-13); deposits refundable on every outcome except veto (2026-09-15, pinned); voting period 3d, quorum 33.4%, threshold 50% (2026-09-14, SDK/Cosmos Hub defaults except voting period)** | — | `app/config/chain.go` + `app/app.go` `DefaultGenesis` (konstellation PR #6). `ExpeditedVotingPeriod` (1d), `VetoThreshold` (33.4%), `ExpeditedThreshold` (66.7%) left at SDK default — not named by D11. testnet-1/dev run 2 h / 30 min / 10 / 50 via the §18 profile (PR #7). Lengthen voting period later as the validator set decentralises. |
| D13 | ~~Krakatoa app-side EVM mempool~~ **DECIDED 2026-09-14: keep ON** (matches cosmos/evm v0.7 default; `init` already writes `mempool.type = "app"` — no code change needed) | — | Independent of BlockSTM. Every validator's `config.toml`+`app.toml` must agree; turning it off later means coordinating that flip across the whole validator set at once. |
| D14 | ~~Circuit breaker implementation~~ **DECIDED 2026-09-19: SDK `contrib/x/circuit`** (deprecated in v0.54, see §7.1) over a bespoke breaker | §13.1 | Authority is governance; the operations multisig gets `LEVEL_SUPER_ADMIN` through `account_permissions` in each network's `genesis.json` (§18), so the code needs no address. Checked at the router and in the ante/mempool pre-check (refused at submission with the reason); both walk into authz-nested messages (`app/circuit.go`), so a tripped type cannot be smuggled into blocks inside `MsgExec` for its fee. **Also inside cosmos/evm's tx-path precompiles** (`app/circuit_precompiles.go`, 2026-09-20 review): they call keepers directly and never see the router, so without that wrapper tripping `MsgTransfer` left the ICS20 precompile open to every EOA and contract. The wrapper maps each precompile tx method to the message it executes (table pinned against the shipped ABIs by test; an unclassified method fails closed). **Protected types**: the breaker never disables its own messages or governance's, whatever the disable list says, and a trip naming one is refused — a fat-fingered or compromised admin cannot weld the reset shut. Runbook: disabling `MsgTransfer` stops all IBC sends, Cosmos and EVM; disabling `MsgEthereumTx` pauses the whole EVM. |
| D16 | ~~Validator admission mechanism~~ **DECIDED 2026-09-20: gate `MsgCreateValidator` with `x/circuit`** — genesis ships with `/cosmos.staking.v1beta1.MsgCreateValidator` in `x/circuit`'s `disabled_type_urls` on both networks; the launch validators (4; 1 on devnet-1) exist through gentx, which bypasses the message router. **Admitting an operator:** the 3-of-5 operations multisig (`LEVEL_SUPER_ADMIN`, §18) resets the breaker, the operator submits `MsgCreateValidator`, the multisig disables it again. The three cannot share a block: the ante checks the breaker against pre-execution state, so a bundled `[reset, create]` tx is refused; the minimum is reset in block N, create in N+1, disable in N+1/N+2 — a window of two or more consecutive blocks with the mempool open to everyone. A pre-signed `create` broadcast before the reset commits is refused and its bytes are then locked out of the app mempool for `check_tx_retry_delay` (5 s), so it must be re-signed (adversarial review 2026-09-22). A validator created in that window *does* enter the active set (26 of the 30 seats are empty at genesis (29 on devnet-1) and `PowerReduction = 1e18`, so ≥ 1 KASH self-delegated qualifies) but holds negligible voting power against the 120 M KASH bonded at genesis, so the window is not a consensus exposure; it would sit in the set until it unbonds or is jailed for downtime (corrected 2026-09-21 by the whitepaper review). **Going permissionless:** a governance proposal removes the type from the disabled list permanently. Nothing new under `x/`; no audit surface beyond D14. Fallback if the window is ever a problem: gate the same message on `x/compliance`'s allowlist in the ante handler — small, but it changes D6's "allowlisting is never required" rule and is deliberately not built. | genesis (`x/circuit` state), `networks/<net>/genesis.json`, `infra/runbooks/validator-admission.md` (written 2026-09-20, unrehearsed — rehearse on testnet-1, §15 phase 5) | The breaker's protected-types list (D14) still excludes the breaker's own and gov's messages, so opening up can never be welded shut. **Gentxs do not bypass the router** — `ExecuteGenesisTx` runs the ante chain and msg router; the launch validators pass only because genutil's InitGenesis precedes circuit's (`app.go` genesis order, pinned by `TestGenesisOrderDeliversGentxsBeforeCircuit`, PR #14). |
| D17 | ~~EVM fork level~~ **DECIDED 2026-09-21: Prague (Pectra), which is what cosmos/evm v0.7.3 activates at genesis by default (`PragueTime = 0`). Osaka (Fusaka) is NOT enabled** even though the pinned go-ethereum fork implements it and `OsakaTime` is a genesis param. | genesis `evm` params, `contracts/foundry.toml` | Reasons: cosmos/evm never activates Osaka and its own code branches only on `IsPrague`, so it is an untested path upstream; Osaka's native EIP-7951 P-256 precompile lands at `0x100`, **the same address as cosmos/evm's p256 precompile** (passkey wallets, §14) — undefined which wins; EIP-7825's 16.7 M per-tx gas cap and EIP-7883 modexp repricing are untested against our fee market. Revisit when a cosmos/evm release activates Osaka (the upstream-watch issue is the trigger, §17). **Contracts compile for `evm_version = "prague"`** with the latest solc — never `osaka` (its `CLZ` opcode is invalid on a Prague chain). Cancun-targeted bytecode also runs unchanged on Prague. |
| D18 | **DECIDED 2026-09-29 (founder): three networks, Solana-style.** `devnet-1` (EIP-155 56672): dapp developers' network — 1 foundation-run validator, runs mainnet's binary version, faucet-fed, rarely reset, the default in `chain-config` and the docs. `testnet-1` (56671): validator and ops rehearsal — 4 validators, new releases land here first, upgrade/chaos/halt drills and D16 admissions happen here and may disrupt it. `konstellation-1` (5667): 4 validators. Upgrade order testnet-1 → devnet-1 → konstellation-1. | `app/config/chain.go` (devnet-1 ↔ 56672 known and replay-protected), `networks/devnet-1`, `infra` devnet-1 env, `chain-config`, `explorer`, `faucet`, `docs`, whitepaper | Separates the two jobs testnet-1 had: after mainnet every upgrade is drilled on testnet-1 first, which would otherwise disrupt the network dapp developers build on. devnet-1 carries no value, so it is not gated by the audit (§15 phase 4b). A single validator means devnet-1 halts whenever that node does; accepted. One binary still serves every network (§18). |
| D15 | ~~IBC rate limiting~~ **DECIDED 2026-09-19: own `x/ratelimit`** — no module exists for ibc-go v11 (ibc-apps' is v10-only, even on `main`); vendoring/porting its 4k lines was rejected in favour of ~800 lines modelled on its semantics | §13.2, D8 | Per (channel, denom) quotas as a % of the denom's supply snapshotted at window start, optionally capped by an absolute amount (`max_absolute_send/recv`, added 2026-09-20: for a voucher the supply *is* what was bridged in, but for the native denom it is the whole chain, so a percentage alone is a weak ceiling; the lower of the two applies — and when the channel value is 0, a not-yet-minted voucher, a positive percentage with a positive absolute cap uses the cap alone, so a foreign path can be limited before its first packet), **net** flow (a round trip does not eat the quota), pending sends undone on error ack/timeout within the window, governance-only messages. Sits outermost on the transfer stack, v1 and v2. A window reset never snapshots a zero supply (a voucher whose supply has all gone home) — it carries the previous channel value forward, else the threshold would be 0 and the path locked until governance removed the limit. Simplifications, recorded: no address whitelist; no async-ack tracking — safe only while nothing in the stack acks asynchronously (a phantom inflow would *widen* the send allowance under net flow, not narrow it; adding such an app means adding `WriteAcknowledgement` tracking). Percentages are of *net* flow, so `0` does not pause a path (sends are still allowed up to the window's inflow) — the pause is tripping `MsgTransfer` in x/circuit. Limits are set per channel by governance before the channel carries value; testnet-1 opens none. |
| D12 | ~~Vesting mechanism~~ **DECIDED 2026-09-15 (confirmed; was already decided in principle): Solidity vesting contracts**, not `x/auth` vesting accounts | contracts, genesis | KiiChain attributed its exploit to a flaw touching vesting accounts and balance handling. **Built 2026-09-20** in `contracts` (`src/vesting/`, branch `vesting-d12`, pending review): OpenZeppelin v5.7.0 base, native KASH only (ERC-20 path disabled — the `werc20` precompile mirrors the native balance), CREATE2 wallets whose addresses are known pre-genesis. **Team shape decided 2026-09-20:** 10 % of each grant liquid at genesis (a plain balance, not in a wallet), the other 90 % is 0 at the 12-month cliff then linear over 36 months. Community: 50 M pool seed in genesis `distribution` state; 280 M in non-revocable tranche wallets. **Constraint (review, 2026-09-21):** `revoker` and `treasury` are immutable per wallet and must be address-stable — an EVM Safe, never a Cosmos `x/auth` multisig (STATUS §5a P14). Before any allocation list is published, `DeployVesting.s.sol check()` must execute every init code locally; wallets are `Ownable2Step`. **Team vesting is revocable (decided 2026-09-15):** the foundation multisig can revoke a departing team member's grant; unvested tokens return to the treasury, vested tokens stay with the beneficiary. Treasury and community schedules are not revocable. |

---

## 12. Audits

**Audit the delta, not the framework.** `cosmos/evm` was audited by Sherlock
(Interchain Labs Collaborative Audit Report, July 2025). Paying to re-audit it
is wasted budget.

**In scope:**

- `app.go` module wiring and ante handler ordering
- Custom modules under `x/`: `compliance` (keeper, ante, mempool pre-check,
  precompile, IBC gate, **bank send restriction + EVM balance guard + protocol-flow
  marks + `checkFrozenERC20Transfer`**, PR #15), `ratelimit` (keeper, v1 + v2 middleware), and the
  `contrib/x/circuit` wiring
- Genesis parameters (a misconfigured param is a vulnerability)
- Preinstall contracts and their deterministic addresses
- `contracts/src/vesting/` and its deploy scripts — holds 72 % of genesis supply; Solidity, so a contest fits (see below)
- Upgrade handlers (a bad migration bricks the chain)
- Bridge contracts — highest priority if one exists

**Firms:** Informal Systems (deepest Cosmos SDK / CometBFT expertise, formal
methods), Zellic, Halborn, Oak Security. For the Solidity portion specifically, a
contest on Sherlock, Code4rena or Cantina is cheaper and effective — but contests
are a poor fit for Go consensus code.

Budget for a re-audit of fixes. The first report is not the end.

**If an audit is not affordable yet:** run a Solidity contest, stand up a funded
bug bounty on Immunefi, cap total value on chain hard, rate-limit every outflow,
and audit before lifting the cap.

---

## 13. Mandatory safety rails

All four ship before any user money moves.

1. **`x/circuit`** wired in `app.go`, authority held by a 3-of-5 multisig. Disables
   specific message types without halting the chain. **Built 2026-09-19** (D14):
   SDK `contrib/x/circuit`, router + ante + mempool pre-check; the multisig's
   permission is a genesis entry per network (§18).
2. **IBC rate limiting** middleware capping outflow per channel per time window.
   Highest-value single control on the list — converts "drained" into "lost one
   window". **Built 2026-09-19** (D15): `x/ratelimit`, governance-set quotas
   (percentage of supply, optional absolute cap), verified over a real
   Hermes-relayed channel in `tests/e2e`. Setting them is a §15 phase 9 gate. Alongside it,
   `x/compliance/ibc` gates incoming ICS-20 packets by the block list (§18).
3. **Bridge caps** enforced in the contract, not the frontend.
4. **A rehearsed halt drill** executed on testnet: simulated advisory at an awkward
   hour, halt at a height, patch, coordinated restart, back in under 90 minutes.

---

## 14. Account abstraction and x402

| Feature | Layer | Chain work required |
|---|---|---|
| ERC-4337 | **Application** | Preinstall EntryPoint v0.7 + v0.8 at canonical addresses; run a bundler (Rundler/Alto/Skandha) and paymaster |
| Passkey / WebAuthn accounts | mostly app | Needs the **p256 precompile (EIP-7212)** — already in `cosmos/evm` |
| EIP-7702 | **Protocol** | Requires Prague opcodes active in `x/vm` config — verify against the pinned geth, do not assume |
| x402 | **Application**, mostly off-chain | A stablecoin implementing **EIP-3009** (`transferWithAuthorization`), plus a facilitator |

**x402** is an HTTP standard, not a blockchain protocol. It uses the 402 Payment
Required status code to let a client pay for a resource inside the request/response
cycle with no account or signup. Released by Coinbase 6 May 2025, contributed to
the Linux Foundation; the x402 Foundation became operational 14 July 2026 with
around forty member organisations. Spec and Apache-2.0 SDKs (TypeScript, Python,
Go, Java) live under `x402-foundation/x402`.

Three roles: **client**, **resource server**, **facilitator**. The facilitator
verifies and settles on-chain so neither endpoint needs gas or an RPC.

v2 uses `PAYMENT-REQUIRED`, `PAYMENT-SIGNATURE`, `PAYMENT-RESPONSE` headers; v1
used `X-PAYMENT`. Every message carries an `x402Version` integer. **Build against
v2** — 2025-era tutorials use the old wire format.

To support x402 on Konstellation: a stablecoin with EIP-3009, a facilitator that
knows the chain (most existing ones serve Base and Solana, so likely self-hosted
from the reference implementation), reliable public RPC, and fast finality — which
CometBFT provides at 1–2 seconds.

**Note for planning:** almost nothing on this list requires changing the chain
software. The only genuinely protocol-level items are the p256 precompile (already
upstream) and EIP-7702 (a version setting).

---

## 15. Launch sequence

| Phase | Gate |
|---|---|
| 0 | Scaffold `konstellation` from the `evmd` reference, pin v0.7.3, zero local replaces |
| 1 | `govulncheck` clean, CI green, dependency graph verified |
| 2 | Customise: `app.go`, genesis params, preinstalls, custom modules |
| 3 | Ship all four safety rails (§13) |
| 4 | Audit the delta (§12) |
| 4b | **devnet-1 live** (D18): one foundation-run validator, public RPC, faucet, explorer. Needs only a signed release and `networks/devnet-1/genesis.json`; no audit gate, because it holds no value. From here on it tracks mainnet's binary version |
| 5 | **testnet-1 with the 4 foundation-run validators** (D7, re-decided 2026-09-29), 6–8 weeks minimum. Must include: one state-breaking upgrade drill, one chaos test (kill 1 of 4 validators mid-block: the chain must keep producing blocks; killing 2 halts it by construction, which the halt-and-restart drill covers), one halt-and-restart drill, and at least one validator admission through the D16 procedure |
| 6 | Admit the first independent operators onto testnet-1 through the D16 procedure. They find the gaps in `run-a-validator.md` that in-house engineers cannot see; fix the docs. |
| 7 | Bug bounty live **before** mainnet |
| 8 | Genesis ceremony: gentx collection, published genesis hash, independent verification by every operator |
| 9 | **konstellation-1 with a value ceiling** (D8). Soak a month. Lift the cap after the audit and a clean run. **By procedure, no IBC channel carries value until governance has set an `x/ratelimit` quota on it** — the module passes an unquoted path untouched and channel handshakes are permissionless, so this is a gate operators enforce, not a property the chain enforces; the hard stop is tripping `MsgTransfer` in `x/circuit`, and whether that ships tripped in mainnet genesis is open (STATUS §5a P18) — percentage *and* an absolute cap for native-denom paths, and for a foreign token's `ibc/…` path the absolute receive cap is what makes the limit settable *before* the first packet (the voucher has no supply yet; §13.2, §18); the quotas are a gate, not a follow-up. |
| 10 | Enable BlockSTM by governance upgrade after the shadow node shows a clean month |

---

## 16. Command reference

```bash
# --- reference clone: local only, never pushed, add to global gitignore ---
cd ~/src
git clone https://github.com/cosmos/evm.git evm-reference
cd evm-reference && git checkout v0.7.3

# --- verify the chain repo is clean ---
cd ~/src/konstellation
grep -n "cosmos/evm" go.mod
grep -n "^replace" go.mod
go mod graph | grep -i "cosmos/evm"
go list -m all | grep -E "cosmos|comet|ethereum"
govulncheck ./...

# --- local dev chain ---
cd ~/src/konstellation
make test-unit
make test-integration              # real app in-process, -tags test
make docker-build && make test-e2e # real nodes under interchaintest (Docker)
make test-solidity
./local_node.sh

# --- review an upstream release before bumping ---
cd ~/src/evm-reference
git fetch --tags
git diff v0.7.3..v0.7.4 -- x/vm/ precompiles/
git log --oneline v0.7.3..v0.7.4

# --- release build: never local (§2.6); a signed tag on main triggers release.yml ---
cd ~/src/konstellation
git checkout main && git pull --ff-only
git tag -s v0.1.0 -m "v0.1.0: testnet-1 genesis binary" && git push origin v0.1.0
# then: gh release download v0.1.0; sha256sum -c SHA256SUMS; record in networks/RELEASES.md
# full checklist: konstellation/RELEASING.md

# --- fleet upgrade, testnet only ---
cd ~/src/infra
ansible-playbook -i inventories/testnet-1 ansible/upgrade.yml
```

---

## 17. Standing responsibilities

**Ownership model (decided 2026-09-14): shared across engineering, not assigned to
individuals.** Any engineer may handle any row. Shared ownership only works with
a trigger and a deadline, so each row has both.

| Responsibility | Trigger | Deadline | Who |
|---|---|---|---|
| Watch `cosmos/evm` releases + `cosmos/security` | automated: `upstream-watch` opens an issue labelled `upstream-release` within 6 h of a new tag | self-assign the issue **within 1 working day**; review complete within 24 h of self-assigning (§4.2 target) | any engineer |
| Diff every upstream release | the same issue carries the hot-zone diff stat and checklist. Also re-check the copies and pins that move with upstream: `app/config/permissions.go` BlockedAddresses/maccPerms are copied in `faucet/src/blocked.ts` and `chain-config/src/contracts.ts`; `app/genesis.go` `InertUpstreamPrecompiles` vs `precompiles/types.DefaultStaticPrecompiles` (chain-config + `docs/contracts.md` follow); cosmos-sdk `server/util.go bindFlags` slice-flag flattening (`cmd/konstellationd/cmd/flags.go` — drop when fixed upstream) | as above; record the review in §4.1 before closing the issue | the engineer who self-assigned |
| `govulncheck` nightly review | automated: nightly `source` job opens an issue labelled `vulncheck` on failure | self-assign within 1 working day; fix or justify in `.govulncheck-allowlist` + §4.1.1 | any engineer |
| Validator on-call rotation | pager (tenderduty, §9.2 — archived upstream since 2025-01, pick a maintained fork before mainnet) | acknowledge within 15 min | rota — **must be a schedule, not "anyone"**; mechanics in `infra/runbooks/on-call.md`, schedule set in `infra` before testnet-1 |
| Halt drill rehearsal | calendar, quarterly | run within the quarter; write up in `infra/runbooks/` | whoever is on-call that week leads it |

Rules that make "any engineer" real:

1. An `upstream-release` or `vulncheck` issue with no assignee after one working
   day is an incident, not a backlog item.
2. Nobody closes one of these issues without the §4.1 / §4.1.1 record written.
3. The on-call row is the exception: pages need a named person at every moment.
   That is a rota in `infra`, decided when validators exist.

Before this model was recorded, v0.7.3 (a critical, state-breaking fix) shipped
on 3 Sep 2026 and was noticed on 13 Sep, by chance. The automation closes the
noticing gap; these rules close the responding gap.

**`CODEOWNERS` and this model:** GitHub has no org-wide default `CODEOWNERS` — it
only reads a file committed to *that* repo (root, `.github/`, or `docs/`), so each
repo needs its own copy; `.github`'s copy is a template to copy from, not something
GitHub applies for other repos automatically. To match "shared, not assigned to
individuals" above, a repo's `CODEOWNERS` should list all engineers (or an org team,
once one exists — none does yet, see `gh api orgs/Konstellation-Network/teams`) as
owners of a path, not one named person, except where a stricter rule is deliberately
wanted (e.g. `konstellation`'s `app.go`/`x/` second-reviewer requirement, §6).

---

## 18. devnet-1 vs testnet-1 vs konstellation-1: what differs

**Rule: one binary, one codebase.** `konstellationd` does not know which network it
is on beyond the chain-id checks in §1. Everything that differs between the three
networks (D18) lives in exactly two places — the network's `genesis.json` in
`networks/` and the environment in `infra/` — and every such difference is listed
here. Anything testnet-only that is not in this table is a bug in the table.
Agents: when you add something that is devnet-, testnet- or mainnet-only, add the row
in the same change.

| Area | devnet-1 | testnet-1 | konstellation-1 (mainnet) | Why they differ |
|---|---|---|---|---|
| Purpose | dapp developers | validator and ops rehearsal; new releases land here first | users | D18 |
| Binary version | mainnet's; upgraded 2nd, 1–2 weeks before mainnet | next release, upgraded 1st | current release, upgraded 3rd | drills on testnet-1 must not disrupt dapp developers |
| Cosmos chain-id / EIP-155 id | `devnet-1` / 56672 | `testnet-1` / 56671 | `konstellation-1` / 5667 | replay domains (D1); enforced in code both ways |
| Token value | none; faucet-fed | none; faucet-fed | real, from day one | — |
| Genesis supply & allocation | same shape as testnet-1, test addresses; the one validator holds the validator bucket | same 1 B shape as `TOKENOMICS.md §7`, filled with **test addresses**; faucet holds the "liquidity" bucket | `TOKENOMICS.md §7` with real beneficiaries and D12 vesting contracts | testnet exercises the shape, not the money |
| Issuance (D4), burn (D5), staking (D10) | identical | identical | identical | testnet must measure what mainnet will do |
| `blocks_per_year` | as testnet-1 until mainnet's is set, then mainnet's | initial estimate (1.5 s) | **set from testnet-1's observed block time** | the only tokenomics param testnet exists to calibrate |
| Governance timing & deposits | testnet profile (`ProfileFor`: anything but `konstellation-1`) | voting **2 h**, expedited **30 min**, deposits **10 / 50 KASH** — decided 2026-09-15; `app/config/network.go` `ProfileFor` (konstellation PR #7). Local/dev and unknown chain-ids get the same | 3 d / 1 d, 1 000 / 5 000 KASH (D11); only the exact chain-id `konstellation-1` selects it | upgrade drills and param changes on testnet should take hours, not days. Mainnet must be named, never fallen into |
| Validator set | **1** foundation-run validator; same `x/circuit` disable list from `init`; super admin = a dev key | **4** foundation-run validators in four failure domains (D7, P16), `max_validators` 30; `x/circuit` genesis `disabled_type_urls` = [`/cosmos.staking.v1beta1.MsgCreateValidator`], written by `konstellationd init` for every chain-id (`app/config/chain.go` `CircuitDisabledTypeURLs`, konstellation PR #14); super admin = a dev key in `account_permissions` (D7, D16) | identical disable list from `init`; super admin = the 3-of-5 ops multisig; decentralisation roadmap in whitepaper | same on purpose (2026-09-20): testnet rehearses mainnet's coordination and the admission procedure |
| Value ceiling & bridges | none needed | none needed | **value ceiling at launch, no bridge on day one** (D8) | limits mainnet blast radius while the chain soaks |
| Compliance (D6) | as testnet-1: dev key, short timelocks | `x/compliance` on; list authority = **a dev multisig / test key**, short timelocks (`local_node.sh`: validator key, 60 s) | `x/compliance` on; list authority = **foundation multisig**, 24 h timelocks — set in `networks/konstellation-1/genesis.json`, after legal review (§10) | same code path, different key holders and timelocks |
| Infra | Hetzner only, one location: bastion, 1 validator (plain key, no Horcrux — one validator on a valueless network), 1 sentry, public RPC, archive, monitoring; `infra/terraform/envs/devnet-1` | Hetzner + GCP; GCP validators on **Local SSD** (testnet-1 only, see `infra/README.md`) with `on_host_maintenance = MIGRATE` and a mount-guarded node unit so a lost disk means downtime, never signing from height 0 (§2.7; STATUS §5a P15); bastion, monitoring host and cross-cloud tunnel built (`close-known-gaps`, 2026-09-20); Horcrux runs `horcrux_mode = colocated` | persistent disks everywhere; `horcrux_mode = dedicated` (3 cosigners across hosts/regions/clouds), bastion, monitoring, backups all mandatory before genesis | double-sign risk (§2.7) is theoretical on testnet, financial on mainnet |
| IBC transfers **to** a frozen address | same | gated — `x/compliance/ibc` error-acks the packet, the sender chain refunds (built 2026-09-19) | same | same code, every network; testnet-1 has no external channels to exercise it on, `tests/e2e` does |
| IBC rate limits (`x/ratelimit`) | none: no external channels | none: no external channels | set by governance per channel **before** the channel carries value (§15 phase 9 gate; D8, D15); quotas calibrated from soak-period usage. Native-denom paths need `max_absolute_*` as well as a percentage — 1 % of KASH supply is 1 % of the whole chain. Foreign-token paths need `max_absolute_recv` to be limitable before the voucher exists (supply 0 → a percentage alone is refused as a typo) | limits are per-channel state in `genesis.json`/proposals, not code |
| Circuit breaker admin (`x/circuit`) | a dev key, `LEVEL_SUPER_ADMIN` | `account_permissions`: a dev key, `LEVEL_SUPER_ADMIN` | `account_permissions`: the **3-of-5 operations multisig**, `LEVEL_SUPER_ADMIN` (§13.1) — set in `networks/konstellation-1/genesis.json` | same code path, different key holders |
| Faucet | **primary faucet** — where dapp developers get KASH | required (`faucet` repo) | does not exist | — |
| Audit | not a gate (no value, §15 phase 4b) | runs against testnet-1 code (phase 4 precedes phase 5) | audit report published before genesis (D9, §12) | — |
| Bug bounty | — | optional | live before genesis (phase 7) | — |
| BlockSTM | follows mainnet | off | off at launch; enabled by governance after a clean shadow-node month (phase 10) | §2.5 |
| State-breaking upgrade drill, chaos test, halt/restart | never — devnet stays up; it takes each upgrade after testnet-1 has proven it | **must all happen here** (phase 5) | never rehearsed for the first time on mainnet | — |
| Explorer, docs, chain-config | primary dapp target; the default network in `chain-config` and the docs; same explorer images as testnet-1 | all three networks; explorer ships the pinned public Blockscout images (backend 9.0.2 / frontend v2.3.5 — decided 2026-09-20) | both networks; **re-evaluate the Blockscout version before the mainnet explorer goes live** (public images lag source by two majors; build-from-tag is the alternative) | the testnet explorer is proven working today; mainnet's has time to be newer |

How to read this against `STATUS.md`: STATUS says what is *built*; this table says
which network each thing is *for*. If a STATUS entry is testnet-only it should say
so and point here.
