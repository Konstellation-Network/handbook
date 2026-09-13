# Konstellation Network — Engineering Context

**Audience:** coding agents and engineers working on any Konstellation repo.
**Status:** pre-testnet. Nothing here is deployed yet.
**Last updated:** 2026-09-13 (D1–D3 decided; cosmos/evm pin bumped to v0.7.3)

Load this document as context before working in any `konstellation-network/*` repo.
Section 2 contains hard constraints that must not be violated without an explicit
human decision recorded in this file.

---

## 1. What we are building

Konstellation is a sovereign Layer 1 blockchain built on the Cosmos SDK with an
EVM execution layer. It is EVM-compatible: Solidity contracts, Ethereum JSON-RPC,
MetaMask/Rabby wallet support, Blockscout explorer.

The chain will launch with **real user funds from day one** and a validator set of
**5–10 nodes across multiple cloud providers**. Security posture is therefore
conservative by default.

**Naming conventions used throughout:**

| Item | Value | Status |
|---|---|---|
| GitHub org | `konstellation-network` | decided |
| Node binary | `konstellationd` | decided |
| Chain (display) | Konstellation | decided |
| Testnet network id | `testnet-1` | decided |
| Mainnet network id | `konstellation-1` | decided |
| Token symbol | KASH | decided 2026-09-13 (D2) |
| Base denom | `esp` (18 decimals; 1 KASH = 10^18 esp) | decided 2026-09-13 (D2) |
| Bech32 prefix | `kons` | decided 2026-09-13 (D3) |
| EIP-155 chain ID, mainnet | **5667** | decided 2026-09-13 (D1) |
| EIP-155 chain ID, testnet | **56671** | decided 2026-09-13 (D1) |
| EIP-155 chain ID, local dev | **56670** | decided 2026-09-13 (D1 follow-up): unlisted Cosmos chain-ids get this, never a real network's id |
| Where the EIP-155 id lives | `app.toml` → `[evm] evm-chain-id` | **Invariant: `genesis.json` decides the network; everything else is checked against it.** `init` writes the EVM id matching the chain-id in the genesis it produced; at startup a `--chain-id` or `client.toml` value that disagrees with genesis is an error naming both, and a known network with the wrong `evm-chain-id` refuses to start (`app/config.ValidateEVMChainID`). Four review passes converged on this; do not reintroduce any path that trusts a per-node file over genesis. |

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
  in `SetBalanceWithLocked`. Add an e2e test in `konstellation/tests/e2e` that
  sends an EVM transfer to a module account address and asserts rejection.

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
└── .github                ← org-wide CODEOWNERS, shared workflows. (pre-mainnet)
```

**There is exactly one repo that produces an executable: `konstellation`.**
Everything else produces configuration, documentation, contracts or cloud resources.

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
| Every release tag has a checksum recorded in `networks` | release checklist |
| `chain-config` addresses match `contracts` deployments | test in `chain-config` |
| Explorer RPC target is an archive node, not pruned | `infra` terraform |

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
│   └── upgrades/
│       └── noop.go
├── cmd/konstellationd/
│   ├── main.go
│   └── root.go                # bech32 prefix, default home dir
├── x/                         # empty unless a custom module exists
├── tests/e2e/                 # interchaintest
├── .github/workflows/
│   ├── ci.yml                 # build, unit, lint
│   └── vuln.yml               # govulncheck: PR + nightly cron
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
│   ├── mint/                  # only if custom emission curve (see §11)
│   └── compliance/            # only if regulated features (see §10)
├── .github/
│   ├── CODEOWNERS             # app.go and x/ require a second reviewer
│   └── workflows/release.yml  # reproducible build, checksums, signed tag
├── SECURITY.md
└── audits/
    └── YYYY-MM-<firm>.pdf
```

A near-empty `x/` directory is the success signal. Every file there is code
someone must audit and the team must patch forever.

### 6.2 `networks`

```
networks/
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
└── README.md
```

`upgrades/*.md` is the public artifact operators read during a coordinated
upgrade. Each file must contain: upgrade name, halt height, binary download URL,
SHA256, any `config.toml` or `app.toml` changes, and a rollback note.

### 6.3 `contracts`

```
contracts/
├── src/
│   ├── WKONS.sol
│   └── vesting/                # Solidity vesting — NOT x/auth vesting accounts
├── script/
│   └── VerifyPreinstalls.s.sol
├── preinstalls/
│   ├── Multicall3.json         # 0xcA11bde05977b3631167028862bE2a173976CA11
│   ├── Permit2.json
│   ├── EntryPointV07.json
│   ├── EntryPointV08.json
│   └── Create2Deployer.json
├── test/
│   └── GenesisBytecode.t.sol   # asserts genesis blob == compiled artifact
└── foundry.toml
```

Preinstalls must sit at their **canonical mainnet addresses** — wallet SDKs and
tooling hard-code them.

### 6.4 `infra` — private, permanently

```
infra/
├── terraform/
│   ├── modules/{validator,sentry,rpc,archive}/
│   └── envs/{testnet-1,konstellation-1}/
├── ansible/
│   ├── roles/{node,cosmovisor,horcrux,monitoring,firewall}/
│   └── inventories/{testnet-1,konstellation-1}
├── monitoring/
│   ├── prometheus/alerts.yml
│   └── grafana/
└── runbooks/
    ├── emergency-halt.md
    ├── coordinated-upgrade.md
    ├── validator-key-rotation.md
    └── incident-comms.md
```

Private because it is a map of where the validators live.

### 6.5 `explorer`

```
explorer/
├── docker-compose.yml          # blockscout backend, frontend, postgres, stats
├── .env.testnet-1
├── .env.konstellation-1
└── branding/                   # logo, colours, token metadata
```

**Dependency:** Blockscout requires `debug_traceTransaction`, so it must point at
an **archive node with tracing enabled**, not a pruned RPC. Provision that node in
`infra` before standing up the explorer.

### 6.6 `docs`

```
docs/
├── docs/
│   ├── quickstart.md           # add network to MetaMask, first tx
│   ├── rpc-endpoints.md
│   ├── contracts.md            # preinstall addresses
│   ├── run-a-validator.md      # external operators will find the gaps here
│   └── upgrades.md             # historical upgrade log
└── docusaurus.config.js
```

### 6.7 `whitepaper`

```
whitepaper/
├── src/whitepaper.tex
├── releases/v1.0.pdf           # versioned; never edited in place
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
| Upgrade orchestration, circuit breaker, evidence | `cosmos-sdk` |
| feegrant, authz | `cosmos-sdk` |
| Consensus, p2p, mempool, state sync, snapshots | `cometbft` |
| IBC clients, connections, channels, ICS20 | `ibc-go` |

### 7.2 Implemented in `konstellation`

- `app.go` module wiring and **ante handler chain composition**
- Custom precompiles (registered into the precompile map — does not need a fork)
- Custom modules under `x/` (minter, compliance) if the decisions in §11 require them
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
| `min_self_delegation` | A **per-validator** field set in `MsgCreateValidator`, not a genesis param. Denominated in **base units** of the bond denom. At 18 decimals, 1 KONS = `1000000000000000000`. The validator is jailed if self-delegation drops below it. Can be raised, never lowered. A chain-wide floor requires a custom ante decorator. |
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
| **Terraform** | Provisions cloud resources: VMs, disks, firewall rules, DNS. Works across AWS, Hetzner, GCP, Vultr from one codebase. |
| **Ansible** | Configures servers that already exist: installs the binary, writes `config.toml`, sets up systemd and Cosmovisor. |
| **Coolify / k8s** | Stateless app tier only: explorer, faucet, docs, indexers, bundler, RPC fleet. |

Terraform builds the house, Ansible furnishes it. Both are required.

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

| | testnet-1 | konstellation-1 |
|---|---|---|
| Validators | 5, all in-house | 7+ independent operators |
| Keys | held by the team | each operator holds their own |
| Upgrades | `ansible-playbook` across the fleet | governance proposal + comms channel |
| Emergency halt | direct SSH | `--halt-height` + Signal group |

Mainnet upgrade mechanics: signed release → upgrade doc in `networks` →
`MsgSoftwareUpgrade` setting the halt height → Cosmovisor swaps automatically.
Operators only need the binary pre-staged; they do not need to be awake.

---

## 10. Compliance design space

Under evaluation, not yet decided. Enforcement can live at three levels:

| Level | Coverage | Cost |
|---|---|---|
| **Ante decorator** reading an `x/compliance` freeze list | every tx, native token included | ~300 lines Go |
| **Compliance precompile** at a fixed address | Solidity contracts call `isVerified(address)` | custom precompile, no fork |
| **Token contract** (ERC-3643 / T-REX) | that token only | pure Solidity |

**Freezing** is straightforward — the ante decorator rejects transactions touching
listed addresses. **Reversal** options, best to worst:

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

Each of these blocks something. Assign an owner and a date.

| # | Decision | Blocks | Notes |
|---|---|---|---|
| D1 | ~~Numeric EIP-155 chain ID~~ **DECIDED 2026-09-13: mainnet 5667, testnet 56671** | — | Both verified absent from `ethereum-lists/chains` on 2026-09-13. Register there before testnet launch. |
| D2 | ~~Token symbol, base denom, decimals~~ **DECIDED 2026-09-13: KASH / `esp` / 18** | — | Native 18-decimal, no `x/precisebank`. `akash` deliberately avoided (Akash Network collision). Not changeable post-genesis. |
| D3 | ~~Bech32 prefix~~ **DECIDED 2026-09-13: `kons`** | — | |
| D4 | **Emission model** | `x/mint`, whitepaper | SDK default is dynamic 7–20% inflation targeting 67% bonded — poor optics for a payments token. Alternative: fixed per-block emission on a decay curve from a pre-mint. Requires a custom module. |
| D5 | **Base fee disposition** | `app.go`, whitepaper | Default routes EIP-1559 base fee through `x/distribution`. Burn requires custom fee-collector wiring. Changing later is a visible economic change. |
| D6 | **Compliance scope** | `x/compliance`, audit scope, positioning | See §10. Decide before the audit is scoped. |
| D7 | **Validator set model** | genesis, whitepaper | 5–10 self-run validators is a permissioned network. Consider the SDK's native POA module with a published decentralisation roadmap. State it honestly either way. |
| D8 | **Launch value ceiling** | bridge, treasury | Strong recommendation: no bridge on day one, or hard daily caps + IBC rate limiting, soaking at modest value for a month. |
| D9 | **Audit firm and scope** | timeline, budget | Lead times run weeks to months. Start scoping calls now. See §12. |
| D10 | **Staking params** | genesis | Unbonding 21d, `min_commission_rate` 5%, `max_validators` 100+, downtime slash ~0.01%, double-sign 5%. |
| D11 | **Governance params** — *partially decided 2026-09-13:* min deposit **10 KASH**, expedited **50 KASH** (SDK defaults scaled to 18 decimals; `app/config/chain.go`) | genesis | Still open: voting period (3–5 day at launch for responsiveness; lengthen as the set decentralises), quorum, threshold. Expedited proposals enabled. |
| D13 | **Krakatoa app-side EVM mempool** (on by cosmos/evm v0.7 default; `init` writes `mempool.type = "app"` accordingly) | every validator's `config.toml`/`app.toml` | Independent of BlockSTM. Not decided — raised 2026-09-13 during scaffold review. Turning it off later means every validator changes `app.toml` + `config.toml` together. |
| D12 | **Vesting mechanism** | contracts, genesis | Decided in principle: Solidity vesting contracts, **not** `x/auth` vesting accounts. KiiChain attributed its exploit to a flaw touching vesting accounts and balance handling. Confirm and implement. |

---

## 12. Audits

**Audit the delta, not the framework.** `cosmos/evm` was audited by Sherlock
(Interchain Labs Collaborative Audit Report, July 2025). Paying to re-audit it
is wasted budget.

**In scope:**

- `app.go` module wiring and ante handler ordering
- Custom modules under `x/`
- Genesis parameters (a misconfigured param is a vulnerability)
- Preinstall contracts and their deterministic addresses
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
   specific message types without halting the chain.
2. **IBC rate limiting** middleware capping outflow per channel per time window.
   Highest-value single control on the list — converts "drained" into "lost one
   window".
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
| 5 | **testnet-1, in-house**, 6–8 weeks minimum. Must include: one state-breaking upgrade drill, one chaos test (kill 40% of validators mid-block), one halt-and-restart drill |
| 6 | Invite 3–5 external operators onto testnet-1. They will find the gaps in `run-a-validator.md` that in-house engineers cannot see. Fix the docs. |
| 7 | Bug bounty live **before** mainnet |
| 8 | Genesis ceremony: gentx collection, published genesis hash, independent verification by every operator |
| 9 | **konstellation-1 with a value ceiling** (D8). Soak a month. Lift the cap after the audit and a clean run. |
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
make test-solidity
./local_node.sh

# --- review an upstream release before bumping ---
cd ~/src/evm-reference
git fetch --tags
git diff v0.7.3..v0.7.4 -- x/vm/ precompiles/
git log --oneline v0.7.3..v0.7.4

# --- release build ---
cd ~/src/konstellation
make build
sha256sum build/konstellationd   # record in networks/<net>/upgrades/

# --- fleet upgrade, testnet only ---
cd ~/src/infra
ansible-playbook -i inventories/testnet-1 ansible/upgrade.yml
```

---

## 17. Standing responsibilities

| Responsibility | Cadence | Owner |
|---|---|---|
| Watch `cosmos/evm` releases + `cosmos/security` | continuous | **unassigned** |
| Diff every upstream release | per release | **unassigned** |
| `govulncheck` nightly review | daily | automated + **unassigned** |
| Validator on-call rotation | continuous | **unassigned** |
| Halt drill rehearsal | quarterly | **unassigned** |

Assign these before testnet-1. An unassigned patch-watch responsibility is exactly
how a chain ends up five months behind a critical fix.
