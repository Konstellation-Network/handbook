# Konstellation — Status & Handoff

**2026-09-29 — GitHub Actions is out of minutes.** The org is on the Free plan with
private repos (2 000 min/month); September's were all used by `konstellation`
(about 48 min per PR push, plus `upstream-watch` every 6 h), and without a
payment method jobs are refused ("recent account payments have failed"). The
quota should reset on 2026-10-01. The Free plan gives private repos **no branch
protection**, so red checks do not block merges. Until the quota resets or a
runner is added, **CI runs locally**: the `ci.yml`/`vuln.yml` steps with
`GOTOOLCHAIN=go1.26.8`, plus `make docker-build test-e2e`, with the results
posted as a PR comment. Done that way on 2026-09-29 for konstellation
#13/#14/#15 and new **#16** (otel bump for **GO-2026-6508**, published
2026-09-28; it failed `vuln/binary` on `main` and every PR), docs #2 and
chain-config #2. Every check passed, including a combined `main`+#16+#13+#14+#15
branch with 7/7 e2e tests. The #14 e2e failure was the test re-sending a
byte-identical tx (`tx already seen`); fixed in `3b09d25`. **All four merged
2026-09-29, each green on GitHub CI first:** #16 `4935d59` → #13 `1b2ccab` →
#14 `25e7d94` → #15 `06f9ebe`. #15's `README.md` conflict with #14 was
resolved by keeping both sections; the merged tree is identical to the tested
combined branch. docs #2 and chain-config #2 are still open and green. Build
provenance: `actions/attest-build-provenance` on a
private repo likely needs GitHub Enterprise Cloud, so check that before the
first tag.
**Later on 2026-09-29, the founder made eight repos public** so that Actions
runs free: `konstellation`, `contracts`, `networks`, `explorer`, `docs`,
`whitepaper`, `chain-config` and `faucet`. The intent is to make them private
again later. `whitepaper` was made private again the same day; it was public
for about an hour and has no forks. Its small CI job counts against the
private-repo minutes again. `infra`, `.github`, `waitlist` and `privacy-lab`
stay private.
The full history of all eight was scanned first (gitleaks plus a filename and
token-format pass): no secrets. The only hits were the public upstream dev0
key, the RFC 6455 sample WebSocket nonce, and the local-only or `TODO` values
in `explorer/.env.*`. Every public repo requires approval before a fork PR's
workflows run (`approval_policy = all_external_contributors`). **Before going
private again:** anything published while public is permanent, including
forks, clones and, if a release tag is pushed, the Sigstore log entry for the
build provenance. Branch protection is available on public repos but has not
been set.
**Next, toward testnet-1 (§5 item 8):** (1) P28: `gen-genesis.sh` writes the
circuit super-admin, plus a `verify.sh` assertion, in `networks`; (2) the first
signed release tag. #13's `release.yml` is on `main` but has never run, so
decide first whether a provenance entry in the public Sigstore log is
acceptable while `konstellation` is public. Then record the tag in
`networks/RELEASES.md` and cut `testnet-1/genesis.json`.

**Updated:** 2026-09-22 — **six of the seven non-chain PRs merged** after three review
passes each (review → fix, second review on infra/faucet → fix, adversarial review →
fix): contracts #2 (`4cc909a`), whitepaper #1 (`dea2c8e`), docs #1 (`b3b63bc`),
faucet #1 (`a4dd1cd`), infra #1 (`1eae435`), explorer #1 (`5de9f60`). **chain-config
#1 still open** (CI green now that `CONTRACTS_READ_TOKEN` exists; merge, then drop
the `ref: vesting-d12` line from its CI). The adversarial pass surfaced chain-level
findings that are now the critical path — see §5a **P12, P17, P18, P20, P24, P26,
P27** (all `konstellation`) and the infra architecture decisions **P16, P21–P23**.
Feature branches kept (not deleted) by request.
Earlier — 2026-09-20 (evening) — seven non-chain repos advanced in parallel,
each on an unpushed local branch (see §1 per repo and §5a for the
decisions they surfaced): `contracts` D12 vesting + WKASH pinned at
`0x34Ab8285C63b876717C2c56151700D02623559bE` (`vesting-d12`), `whitepaper` v1.0
draft, 27 pp (`whitepaper-v1-draft`), `docs` four pages filled (`fill-docs-pages`),
`chain-config` package + §5.2 invariant test (`scaffold-package`), `faucet` live-tested
on the dev chain (`scaffold-faucet`), `infra` all "Known gaps" closed
(`close-known-gaps`), `explorer` Blockscout stack live-indexing the dev chain
(`scaffold-blockscout`). Every repo now has a `CODEOWNERS`. **Same evening: D7 re-decided (10
foundation-run validators, admission permissioned, both networks), D16 admission via
`x/circuit`, D12 team 10 % at TGE, community pool 50 M — `TOKENOMICS.md §7`
rewritten; `contracts` and `whitepaper` branches being updated to match.** Next:
review + PR each branch; §5a P1–P10.
Earlier the same day — **Phase 3 (safety rails, §13) merged: konstellation PR #12
(`a9051f6`).** `x/circuit` (SDK contrib, D14) wired into the router, ante chain, mempool
pre-check and the tx-path precompiles, authz-nested messages included, its own and gov's
messages untrippable; `x/ratelimit` (own module, D15 — nothing exists for ibc-go v11) as
the outermost transfer middleware, v1 and v2, percentage-of-supply quotas with optional
absolute caps, fails closed; `x/compliance/ibc` gating incoming ICS-20 packets by the
block list. Verified over a real Hermes-relayed channel between two nodes
(`tests/e2e/ibc_test.go`). Three automated review rounds, nine findings, all closed with
tests (see §5 item 6). The 3-of-5 multisig is a genesis entry per network, not code —
still to be chosen. **Next: cut a release and build testnet-1 genesis (§5 item 8).**
**Phase 2 complete: konstellation PR #11 (`40bafaa`, 2026-09-19):** a block-list add
now clears an existing EIP-7702 delegation (the
drain path the PR #10 reviews left open, reproduced and closed in the same test); the
by-hand EVM checks from PR #10 are automated in a new in-process harness
(`tests/integration`, `make test-integration`); `tests/e2e` is live — a `Dockerfile`
and four interchaintest tests against real nodes (§2a restart regression, freeze via
CLI → refused at `eth_sendRawTransaction`, §4.1.1 module-account transfer, chain
identity); the §4.1.1 module-account test exists at both levels, and the e2e one
surfaced that such a transfer vanished from `eth_*` after charging gas — now refused at
submission with the reason (`app/blocked_recipient.go`, see §3).
`x/compliance` (PR #10) merged `9ad388b` 2026-09-17 — the last Phase 2 item. Chain-wide
block-list enforcement (EVM + Cosmos, with an immediate "address is frozen" at every
submission path), timelocked authority with emergency freeze/expiry, governance
override, read-only precompile at `0x…0900`, all verified live. Needs legal review
(§10) and the mainnet authority address before it ships. Phase 3 not started.
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
| 2 — customise: genesis params, preinstalls, custom modules | **done** — genesis params (#3), preinstalls (#4), D4 issuance + D5 burn (#5), econ params (#6), network profiles (#7), `x/compliance` (D6, #10 merged 2026-09-17), loose ends + both test harnesses (#11 merged `40bafaa` 2026-09-19) |
| 3 — safety rails (§13) | **done** — PR #12 merged `a9051f6` 2026-09-20: circuit breaker (D14) + IBC rate limiting (D15) + IBC receive gate; bridge caps n/a (no bridge, D8); halt drill is a Phase 5 output |
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
request — **since 2026-09-20 (D7): 5 validators/sentries + 1 archive on Hetzner, 5
validators/sentries + 1 archive + 1 RPC on GCP**, 26 hosts colocated / 29 with
dedicated cosigners (was 3 + 2; terraform modules per provider, ansible roles for
node/cosmovisor/horcrux/monitoring/firewall, prometheus alert rules) —
pushed to `origin/main` as `0b011f4`, but not yet applied against real
infrastructure. This matches `ENGINEERING.md §1`'s own
"5-10 nodes across multiple cloud providers" target and §9.3's "nodes find
each other over the public internet regardless of provider" — multi-cloud
here isn't a deviation, it's the documented baseline. The GCP
validators use Local SSD, which is ephemeral across host maintenance events;
this was a deliberate testnet-1-only call (documented at length in
`terraform/modules/gcp/validator`'s `local_ssd_count` variable and
`infra/README.md`) that MUST be revisited before any mainnet validator runs on
GCP, given the double-sign risk in `ENGINEERING.md §2.7`. See
`infra/README.md` "Known gaps" for what's missing before a real `terraform apply`.
**Gaps closed 2026-09-20 on branch `close-known-gaps` (5 commits, unpushed, nothing
applied):** bastion modules for both clouds (private-only hosts reach SSH only via
their cloud's bastion; the Hetzner bastion is also the NAT gateway because
public-IP-less Hetzner hosts have no egress at all; GCP gets Cloud NAT), a
WireGuard site-to-site tunnel between the two bastions with routes so monitoring
and cosigners are cloud-agnostic, a monitoring host (Prometheus/Alertmanager/
Grafana/tenderduty, `alert_*` route is a placeholder), dedicated Horcrux
cosigners behind `horcrux_mode` (`colocated` default for testnet-1; `dedicated`
mandatory before mainnet, §18), the four §6.4 runbooks plus `on-call.md`,
`CODEOWNERS`, `runbooks/validator-admission.md` (the D16 procedure, unrehearsed),
and the archive node's `[json-rpc] address`/`ws-address` now bind
the private address (`jsonrpc_bind_address`, gated by `explorer_cidrs`) so the
explorer can reach it. Validated with `tofu validate` + a credential-free
`tofu plan` (60 resources at 10 validators; caught two latent bugs in the original scaffold: GCP
firewalls without `source_ranges`, rpc modules lacking a `private_ip` output),
`ansible-playbook --syntax-check`, `ansible-lint`, every template rendered.
**Review fix round 2026-09-21 (`3f68c01`, 22 findings):** first-apply blockers
fixed (Hetzner `ash` outside the eu-central subnet, two 404 download URLs, the
v2 `horcrux cosigner start` command), the ansible re-run that re-pointed
`cosmovisor/current` to `genesis`, cosmovisor's data backup onto the boot disk
(`UNSAFE_SKIP_BACKUP=true`, H-1 snapshot is the backup), the §2.7 mount guard
(`RequiresMountsFor` on every host with a data volume), single-entry bastion
routing over the tunnel (`Table = off` + src routes), Hetzner private hosts' route/DNS
before apt, tenderduty perms + `[rpc] laddr` reconciled per role, bastion scrape
targets, the always-firing `BlockTimeDrift`, and a controller-only
`ansible/tests/render_test.yml` that asserts each. **Second pass + round 3
(`f733b86`):** the render test was vacuous for three guards — it now imports the
shipped role tasks and five documented mutations each fail it; a data-rebuild guard
refuses to format a validator's data device while a consensus key exists (the §2.7
residual: re-running `site.yml` after a wiped Local SSD); and the honest test caught
Prometheus about to listen on CometBFT's 26660 (`prometheus_web_port`).
**Adversarial round (`3dfae83`):** the coordinated-upgrade rollback section that would
have tombstoned the whole set is rewritten (`--unsafe-skip-upgrades`, never a `data/`
restore; state-file handling explained); tenderduty digest-pinned and sandboxed;
downloads into a root-owned cache with a second checksum before root extracts
(TOCTOU); the emergency patch survives `site.yml`; WireGuard peer pubkeys validated
(fact injection → root); validators accept p2p only from their own cloud's sentry
/32s, sentries cross-peered; GCP VMs on a scopeless dedicated SA, shielded, project
SSH keys blocked; jailed-validator and cosigner-down alerts; admission tx carries fee
+ timeout-height; 7-mutation render test. P16/P21/P22/P23 remain decisions with
honest interim text.
Still open: state bucket, topology
defaults (§5a P5, P15), version pins, on-call rota, and tenderduty is **archived
upstream (2025-01-02)** — evaluate a maintained fork before mainnet.

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
of baking bespoke, not-yet-audited bytecode into `genesis.json`. **Built 2026-09-20
on branch `vesting-d12` (6 commits, unpushed):** `script/DeployWKASH.s.sol` pins
**WKASH at `0x34Ab8285C63b876717C2c56151700D02623559bE`** (salt
`keccak256("konstellation-network/contracts:WKASH:v1")`, init-code hash
`0x0802161d…68e64`, same on every network; cross-checked with `cast create2`);
`foundry.toml` strips bytecode metadata (`bytecode_hash = "none"`,
`cbor_metadata = false`) so CREATE2 addresses depend on code only — Blockscout
verifies as a partial match. **D12 `src/vesting/`** on OpenZeppelin v5.7.0
(submodule, pinned): `KonstellationVestingWallet` (non-revocable, linear +
optional cliff, native KASH), `RevocableVestingWallet` (one-shot `revoke()` by an
immutable `revoker` = foundation multisig; unvested → immutable `treasury`,
vested stays with the beneficiary), `VestingSchedules` (the one place
`TOKENOMICS.md §7`'s numbers live), `script/DeployVesting.s.sol` (JSON config →
CREATE2 wallets; addresses are known pre-genesis, so `genesis.json` can hold each
allocation at its wallet address from block 0 — tested). 56 tests incl. 5 fuzz
properties × 1000 runs. **ERC-20 `release(token)` is disabled on purpose** (see
§3): cosmos/evm's `werc20` precompile mirrors the native balance as an ERC-20, so
OZ's stock path would let a beneficiary withdraw the same KASH twice. Vesting is
native-KASH only. `CODEOWNERS` added with separate rows for `src/vesting/` and
`preinstalls/`. Defaults the agent picked that need confirming are in §5a.
**Review rounds 2026-09-21:** first pass (`8ac5a7d`, 85 tests) — config validation,
`check()` executes every init code, init-code pins, typed JSON parsing,
`Ownable2Step`; adversarial pass (`09cc107`, 103 tests) — scripts refuse drifted
builds (`script/lib/InitCodePins.sol`, any compiler override fails `check()`),
duplicate JSON keys detected, funding compares `balance + released()` (dust cannot
veto a mainnet deploy; `run()` idempotent; `fund()` no double-pay), semantic
config checks (label charset, treasury ∉ wallets, stale TGE, §7 divisibility
enforced), `.env` ignored and never read, SHA-pinned CI, a 4-invariant stateful
fuzz. **Pre-publish procedure for any allocation list: `forge script
script/DeployVesting.s.sol --sig "check()"` on the canonical build.**

`docs` has a Docusaurus site scaffolded and pushed to `main` (`2f2e598`, 2026-09-14);
CI (`npm ci && npm run build`, with `onBrokenLinks: 'throw'`) added 2026-09-15.
**Filled 2026-09-20 on branch `fill-docs-pages` (`b1e4c43`, unpushed; build green):**
`contracts.md` (all 10 preinstalls with addresses copied from
`contracts/preinstalls/*.json` and cosmos/evm v0.7.3, selectors checked against the
pinned bytecode; precompile table incl. `ICompliance` at `0x…0900` with the
interface copied verbatim; WKASH and vesting addresses marked TBD),
`run-a-validator.md` (hardware, ports from a real `init` run — note `init` writes
`[json-rpc] enable = false` and `[api] enable = false`, so an RPC node enables them
by hand — cosmovisor layout, the exact chain-id-mismatch error strings from the
`a9051f6` binary, §2.6/§2.7 callouts), new `troubleshooting.md` (the
invisible-to-`eth_*` failure with `tx_search` recipes, module-account refusal,
"address is frozen", circuit-breaker errors, the PR #8 restart panic as an
old-binary marker), `quickstart.md` (MetaMask params for testnet-1 and local dev,
first tx with `cast`), `CODEOWNERS`. `rpc-endpoints.md` / `upgrades.md` stay
stubbed until `networks/testnet-1` exists; every URL is a marked TBD.
Hosting/domain for the site is still undecided (`docusaurus.config.js` `url` is a
placeholder).
**Review rounds 2026-09-21:** `bb94830` (D7/D16 admission flow, vesting/WKASH as
built, real circuit-breaker strings, infra's unit) and adversarial `b62ed62`: freeze
semantics stated honestly (stops signing and direct receipt; does not immobilise
balance — P20), Horcrux steps that actually remove the key from the host, admission tx
with fee + timeout, genesis by tag with a separately published hash, attestation
pinned to repo + workflow, cosmovisor pinned, private-doc citations replaced by inline
facts, WKASH marked provisional until on testnet-1.

`networks` is scaffolded — **PR #1** (https://github.com/Konstellation-Network/networks/pull/1)
**merged** into `main` as `c88fd34` on 2026-09-16 after a `/code-review` pass (8 findings,
1 medium: silent gentx failure; all reproduced and fixed): `ENGINEERING.md §6.2` layout, `CODEOWNERS`,
`scripts/verify.sh` + CI enforcing the §5.2 `genesis.sha256` invariant (plus
`chain_id == directory` in `genesis.json`/`chain.json`, peer-file format, the six
mandatory `upgrades/*.md` sections), `scripts/gen-genesis.sh` (reproducible:
`init` + allocations in whole KASH summing to `TOKENOMICS.md §7`'s 1 B + gentxs +
pinned `GENESIS_TIME`; verified byte-identical across runs against the dev binary
with 5 real gentxs), `testnet-1/{chain.json,allocations.example.json,README.md}`
join docs with TBDs marked, `templates/upgrade.md`, `RELEASES.md` checksum ledger.
**No `genesis.json` yet, deliberately** — it waits on konstellation #5–#7, D6 and
the §2a restart panic; cutting one now would only be regenerated.

`explorer`, `whitepaper`, `chain-config` and `faucet` were `init`-only until
2026-09-20; each now has one unpushed local branch (no PR yet):

- **`whitepaper`** — `whitepaper-v1-draft` (2 commits): `src/whitepaper.tex` +
  `src/sections/*.tex` covering every decided item (D1–D15, §10 risks, D7
  roadmap, D8 sequencing, §14, §12/§15), `Makefile` (`pdf`/`check`/`release`),
  CI (SHA-pinned `latex-action`; refuses PRs that touch `releases/`),
  `CHANGELOG.md`, `CODEOWNERS`. Builds: **27 pages, no unresolved references**
  (`tectonic` installed via Homebrew for the local build; CI uses latexmk).
  **18 `\todo{}` placeholders** need human input — the list is auto-generated
  at the end of the PDF; todo #4 (permissioned mechanism) is now answered by D16,
  the rest are §5a P2. `[legal review]`
  markers on the compliance section, token characterisation and disclaimers.
  **Review rounds 2026-09-21:** `ae45b70` (18 wording findings) and adversarial
  `375dd63` (29 pp, 20 todos): the false "single provider outage cannot halt the
  chain" claim corrected (P16); all yield/return/market language neutralised or
  `[legal review]`-marked; governance stated as the foundation over itself at launch;
  freeze-voters residual (P17) and freeze-does-not-immobilise-balance (P20) stated
  honestly; IBC quotas as procedure (P18); incident/audit claims corrected; provider
  names removed; multisig-distinctness todo (P19); `releases/` guard fixed and run
  on push; TeX image digest-pinned.
- **`chain-config`** — `scaffold-package` (2 commits): TypeScript package
  `@konstellation-network/chain-config` (ESM + CJS + types, zero runtime deps):
  `konstellation` / `testnet` / `localnet` as viem-compatible `Chain` objects plus
  `cosmosChainId`, `bech32Prefix`, `baseDenom`; a `contracts` map of all 10
  preinstalls + 12 precompiles; EIP-3085 params. **§5.2 invariant test** reads
  `../contracts/preinstalls/*.json` and the konstellation repo (chain ids, denom,
  precompile addresses) in both directions; skips loudly if the sibling is
  absent; flipping one nibble fails it. 33/33 tests. `"private": true` until the
  npm scope is claimed and a licence chosen; CI only enforces the invariant on
  GitHub once a `CONTRACTS_READ_TOKEN` secret exists (`contracts` is private).
  RPC/explorer URLs deliberately empty. **Fix round 2026-09-21 (`20b2ecc`, 38 tests):**
  publishes `contracts.wkash` = `0x34Ab8285C63b876717C2c56151700D02623559bE` (read from
  the pin in `contracts/test/DeployWKASH.t.sol`, so drift fails) and renames the native
  precompile key to `werc20` — the two are different contracts; MetaMask Mobile now accepts
  the `wallet_addEthereumChain` params (empty `blockExplorerUrls` omitted); the §5.2
  invariant fails rather than skips on a broken sibling; CI checks out both `contracts`
  and `konstellation`, so `CONTRACTS_READ_TOKEN` needs read access to **both** (P6). **Adversarial round (`1fcd9ac`, 52 tests):** CI is now **red**, not
  yellow, when the invariant cannot run (fork PRs red by design); `dist/` is tested
  against `src` on build and pack; every address has a literal expectation; parsers
  strip comments and require exactly one match; inert `vesting` precompile removed
  (P24 chain side still open); prototype-safe `getNetworkById`; gated OIDC publish
  workflow (needs npm org + LICENSE + `private` off — P6/P25). CI checks out
  `contracts` at `vesting-d12` until it merges — drop the `ref:` then.
- **`faucet`** — `scaffold-faucet` (`172b026`): TypeScript/viem service (one
  runtime dep), `POST /request` accepts `0x` and `kons1…` (in-house bech32),
  per-address + per-IP cooldown behind a store interface (memory default, Redis
  optional), refuses the zero address, all 10 module accounts and 28 precompiles
  (**a copy of `konstellation/app/config/permissions.go` — must move with it**),
  optional hCaptcha/Turnstile (**off by default; on before public**), refuses
  `CHAIN_ID=5667` at startup (§18 testnet-only). 47 tests; **live-verified on
  the dev chain**: two real sends (`0x33fab7c6…`, `0x8002198a…`), repeat → 429,
  fee collector → 400 `blocked_recipient`; Docker image built and reached the
  host chain. Defaults to confirm: 10 KASH/request, 24 h cooldown. Side finding:
  the `cosmos1…` comment for `dev0` in `konstellation/local_node.sh` is stale
  upstream text (`…gp95srxm` is the correct encoding).
  **Fix round 2026-09-21 (`6a9f10c`, 80 tests):** the review drained it live three ways
  — slow-RPC repeat payouts (cooldown released after a broadcast), leftmost-hop
  `X-Forwarded-For` trust, and nonce collisions (app-side mempool keeps `pending`
  flat within a block) — all closed and re-proven against the reviewer's scripts: one
  broadcast per request with receipt wait (`200 confirmed` / `202` broadcast), local
  nonce counter (5 parallel → 5 × 200), rightmost validated XFF hop, IPv6 keyed by /64,
  `application/json` + same-origin required, digest-pinned image, history-walking
  secret scan. **Second pass + round 3 (`12692fa`, 92 tests):** the first fix
  introduced a lockout (a node-answered `nonce too low` kept the cooldown with no
  payout) — now an in-request resync + retry, 3 s hash-lookup polling on transport
  loss, origin check works behind a Host-rewriting proxy (`PUBLIC_ORIGIN`), Redis
  client behind a Docker build-arg. Two instances sharing one key: 8/8 confirmed. **Adversarial
  round (`008208b`, 101 tests):** payouts signed at exactly 21 000 gas and recipients
  with code (contracts, 7702 delegations) refused before any claim; forwarded headers
  honoured only from peers in a required `TRUSTED_PROXY_CIDRS`; compose default
  `TRUST_PROXY=false`; startup refuses captcha-off in production unless
  `ALLOW_NO_CAPTCHA=true`; lockfile scanned.
- **`explorer`** — `scaffold-blockscout` (2 commits): one `docker-compose.yml`
  for all networks selected by `--env-file` (`.env.local` concrete; testnet-1 /
  konstellation-1 all `TODO-*`, CI enforces they stay placeholders); every image
  pinned tag@digest, CI rejects `latest`; `scripts/check-rpc.sh` preflight
  enforces the §5.2 archive invariant (chain id, state at block 1,
  `debug_traceTransaction`, WS) and the backend won't start until it passes;
  ERC-4337 user-ops indexer on for v0.7/v0.8; placeholder SVG logo.
  **Live-verified: indexed the dev chain to head** (3049 blocks, internal txs
  traced, a fresh `cast send` visible in `/api/v2` within seconds). Two
  findings: (1) **`ETHEREUM_JSONRPC_GETH_TRACE_BY_BLOCK=false` is mandatory** —
  cosmos/evm v0.7.3's `debug_traceBlockByNumber` omits per-entry `txHash` and
  crashes Blockscout's block parser; per-tx tracing works. (2) **Public
  Blockscout images lag source by two majors** (registry stops at backend 9.0.2
  / frontend v2.3.5, source is 11.3.1; newer images go to a private registry
  only) — decided: 9.0.2 for testnet-1, re-decide for mainnet (§5a).
  **2026-09-21 (`65b453f`): NFT media handler enabled** (founder decision) as a
  second backend container in worker mode; thumbnails are pushed to S3-compatible
  storage — Blockscout 9.0.2 hard-codes https:443 for the bucket, so **each real
  network needs an R2/S3 bucket with TLS + anonymous read** (`NFT_MEDIA_S3_*`
  placeholders; an `infra` item). Locally a `local-s3` compose profile runs
  MinIO with a self-signed cert. Verified end to end with a scratch ERC-721 (three
  tokens: https PNG, small PNG, IPFS) — metadata indexed, 60/250/500 px thumbnails
  generated and served. Upstream quirk worked around: the handler's in-progress
  queue never expires across restarts, so the backend clears
  `dets/tasks_in_progress` at start. Two **verifier bugs fixed** the same day: the
  compilers volume was root-owned (verification always failed —
  `verifier-init` chowns it) and solc is amd64-only (`platform: linux/amd64`).
  Proof: WKASH at `0x34Ab82…59bE` verified on the local stack, `is_verified:
  true, is_partially_verified: true` — the expected partial match for
  metadata-stripped bytecode. Dev-chain contracts deployed by the contracts agent
  the same evening (WKASH, 13 vesting wallets from a back-dated scratch config, a
  live `release()`) are indexed there. **Fix round 2026-09-21 (`a9c86b3`, 16 findings,
  CI green):** frontend env validation per network is a CI step (testnet-1's was
  failing on an empty port); API rate limit keyed per client behind the proxy (ingress
  must *set*, not append, `X-Forwarded-For`); `FIRST_BLOCK=1`; published ports bound
  to loopback; Erlang distribution on an `internal: true` network; 8 MB verification
  uploads; placeholder guard checks rendered values. **NFT media ships OFF for
  testnet-1/mainnet** (profile-gated) until P11's bucket exists; on locally.
  **Gas tracker (`7dae2d3`):** "N/A Gwei" was a real 0 — the oracle ignores zero-priced
  txs and falls back to the base fee, which decays to 0 because `min_gas_price = 0`
  (`TOKENOMICS.md §3`); window widened to 28 800 blocks and the sub-unit name set to
  `esp` (10⁹ esp renders as **Gesp**). On an idle chain it will read N/A again — inherent
  to a zero-floor fee market; the public RPC's 1 gwei node-local floor (P15) is what
  makes testnet-1 read ~1 Gesp. A protocol floor would be a TOKENOMICS §3 decision.
  For `konstellation`: Blockscout's realtime fetcher logs `failed to get receipts …
  tx not found` ~17×/12 min because `newHeads` fires before the node's EVM tx index
  commits; catchup recovers — cosmos/evm indexer timing, worth a §2a note if it ever
  matters beyond log noise.
  **Adversarial round (`291f9f3`, CI green):** XFF honoured only from
  `TRUSTED_INGRESS_CIDR` at our nginx (rate-limit spoofing closed; deploy-time warning
  when bound off loopback without it); oracle window 2 400 blocks (~40 min poison vs
  half a day); redis `requirepass` and both databases + redis on an `internal` `data`
  network; CPU/memory/pid limits on every service; verifier on its own network with the
  backend only; `INDEXER_TOKEN_INSTANCE_HOST_FILTERING_ENABLED=true` pinned with CIDR
  denies (SSRF probes → `blacklist`); `local-s3` profile refused for real networks;
  preflight proves tracing with `debug_traceCall`.

## 2. Decisions made (all recorded in ENGINEERING.md; every numbered decision D1–D13 is now resolved)

| | Value | Where |
|---|---|---|
| D1 EIP-155 ids (2026-09-13) | mainnet **5667**, testnet-1 **56671**, local/unknown **56670** | §1, §11 |
| D2 token (2026-09-13) | **KASH**, base denom `esp`, 18 decimals, no precisebank | §1, §11 |
| D3 bech32 (2026-09-13) | `kons` | §1, §11 |
| D4 emission (2026-09-15) | **stake-based issuance modelled on Ethereum post-merge**: `annual KASH = F × √(bonded KASH)`, **F = 1265** against an assumed **1 B KASH genesis supply** (8 % APR at 25 % bonded, 4 % at 100 %). No bonded-ratio loop. Built as stock `x/mint`'s `MintFn` — no custom module — **PR #5, open** | §11; `app/issuance.go`, `app/config/chain.go` |
| D5 base fee (2026-09-15) | **burn** the EIP-1559 base fee: `baseFee × BlockGasUsed` burned from the fee collector at EndBlock, tips still to validators — **PR #5, open** | §11; `app/feeburn.go` |
| D6 compliance (re-decided 2026-09-15) | **`x/compliance` module + chain-wide ante decorator**, with a precompile so Solidity sees the same list. Was "precompile only" earlier the same day. Built — **PR #10 (open, 2026-09-16)**; legal review still needed before mainnet | §10, §11, §18 |
| D7 validator set (2026-09-15) | ~~5–10 self-run, permissioned at launch~~ **superseded 2026-09-20 — see the re-decided row below** | §11 |
| D8 launch value ceiling (2026-09-15) | **no bridge on day one**; post-launch sequence (soak → build+audit bridge & IBC rate-limit middleware in parallel → calibrate caps → open with caps enforced in-contract) recorded in §11 | §11, §13 |
| D9 audit (2026-09-15) | **Informal Systems** | §11, §12 |
| D10 (2026-09-14) | staking: DPoS, unbonding 21d, `min_commission_rate` 5%, **`max_validators` 30**, downtime slash 0.01%, double-sign slash 5% — **merged, PR #3 (`21da290`)** | §11; `app/config/chain.go` + `app/app.go` |
| D11 | gov: min deposit **1 000 KASH** / expedited **5 000 KASH** (raised 2026-09-15 from 10 / 50, **PR #6 merged `a46cde7` 2026-09-16**), refundable unless vetoed (pinned); voting period **3d**, quorum **33.4%**, threshold **50%** (2026-09-14, merged PR #3 `21da290`). testnet-1/dev: 2 h / 30 min / 10 / 50 (PR #7) | §11, §18; `app/config/chain.go` + `app/app.go` |
| D12 vesting (confirmed 2026-09-15) | Solidity vesting contracts, not `x/auth` vesting accounts. `contracts/src/vesting/` — **built 2026-09-20 on `contracts` branch `vesting-d12`, pending review/PR** (OZ v5.7.0 base; ERC-20 path disabled — werc20 double-withdraw; see §1, §3, §5a) | §11 |
| D13 Krakatoa mempool (2026-09-14) | keep app-side EVM mempool **ON** — no code change, already the default behaviour | §11 |
| D14 circuit breaker (2026-09-19) | SDK **`contrib/x/circuit`** (deprecated in 0.54, unmaintained — vendor if dropped) over a bespoke one. Gov is authority; ops multisig granted in genesis | §7.1, §11, §13, §18 |
| D15 IBC rate limiting (2026-09-19) | **own `x/ratelimit`**: no module for ibc-go v11 exists; ibc-apps' semantics (% of supply, net flow, undo on error ack/timeout), gov-only messages, no whitelist | §11, §13 |
| D7 validator set (re-decided 2026-09-20) | **10 validators at genesis, all foundation-run (`infra`: 5 Hetzner + 5 GCP), `max_validators` 30, admission of independent operators permissioned, opening in stages by gov; same on testnet-1 and mainnet** (was 5–10 self-run). §9.4/§15/§18 reconciled | §1, §9.4, §11, §15, §18 |
| D16 validator admission (2026-09-20) | **`MsgCreateValidator` disabled in `x/circuit` genesis state**; ops multisig resets/disables around each admission; gov proposal removes it to go permissionless. No new module. Runbook: `infra/runbooks/validator-admission.md` (unrehearsed) | §11, §18 |
| D12 shape (2026-09-20) | **team: 10 % liquid at genesis, 90 % 12-mo cliff + 36-mo linear**; community: **50 M pool seed in genesis `distribution` state**, 280 M in tranche wallets; genesis float 322 M (32.2 %) | `TOKENOMICS.md §7`, §11 |
| D17 EVM fork (2026-09-21) | **Prague** — cosmos/evm's default; **Osaka not enabled** (0x100 p256 collision, untested upstream). Contracts recompiled with solc 0.8.37 / `evm_version = "prague"` on `vesting-d12` (`5fa5ee9`) — **bytecode byte-identical to 0.8.28/cancun, so no address moved**; WKASH stays `0x34Ab82…59bE`, 59/59 tests | §11 D17, `contracts/foundry.toml` |
| Blockscout version (2026-09-20) | testnet-1 ships the pinned public images 9.0.2 / v2.3.5; re-decide for mainnet | §6.5, §18 |
| cosmos/evm pin | **v0.7.3** (v0.7.2 has GHSA-367m-g444-9mg3) | §2.4, §3, §4.1 |
| Go | `go 1.26.0` min, `toolchain go1.26.8` (1.25 is out of support) | §3 |
| BlockSTM | OFF; **virtual fee collection also OFF** (same bundle) | §2.5, §7.3 |
| feemarket `min_gas_multiplier` | **0.5**, explicit (PR #3, `21da290`) — upstream default, now a recorded decision | §3; `app/config/chain.go` |
| Dependency: grpc | **v1.83.2** (PR #9, `2f3880e`, 2026-09-16) for GO-2026-6348 / -6441 / -6443, all reachable. `make vulncheck-binary` now builds with symbols so local matches CI | §4.1, §4.3 |
| Chain-id invariant | **genesis.json decides the network; every per-node file is checked against it, in both directions** (a real network's EVM id is used only by that network) | §1 |
| WKASH (was WKONS) | renamed 2026-09-15 to match the D2 token symbol; ships as a **post-genesis deploy**, not a genesis preinstall — see §1. **Address pinned 2026-09-20: `0x34Ab8285C63b876717C2c56151700D02623559bE`** (Create2Deployer + salt `keccak256("konstellation-network/contracts:WKASH:v1")`, `contracts` `vesting-d12`) | §6.3, §11 |
| Genesis preinstalls (2026-09-15) | cosmos/evm's 5 defaults + `EntryPointV07`/`V08`, each with its `SenderCreator`, + `Create2Deployer` at canonical mainnet addresses — **merged, PR #4 (`dc1a4db`)**. Bytecode source of truth is `contracts/preinstalls/`; a preinstall never runs its constructor, so constructor-deployed companions must be preinstalled too | §6.1, §6.3; `app/preinstalls/` |

## 2a. Known problems — open

| Found | Symptom | What we know | Severity |
|---|---|---|---|
| 2026-09-15 | **A restarted node panics on its first EVM tx.** `panic: module account  does not exist: unknown address` from `x/vm` `DeductTxCostsFromUserBalance` in the EVM mempool recheck, on the first `eth_sendRawTransaction` after `konstellationd start` on existing state. | **Root-caused and fixed — konstellation PR #8, merged `642e7b3` 2026-09-16.** `x/vm` routes EVM fees via the SDK's `authante.DeductFees` → `authante.FeeRecipientModule`, a package global that is `""` until `NewDeductFeeDecorator` runs; cosmos/evm v0.7.3 builds its Cosmos ante chain lazily per tx, so the global is only set after the first *Cosmos* tx in the process. Fresh chains get that from InitChain's gentxs; restarts don't. Proven on the unpatched binary: one Cosmos tx after restart makes the EVM tx succeed. Fix: pin the global in `setAnteHandler`. 3/3 restarts now survive. The startup log `failed to initialize rechecker context … invalid height` is a separate self-healing race, not the cause. Upstream: **cosmos/evm#1288** (https://github.com/cosmos/evm/issues/1288, filed 2026-09-15). Our fix does not depend on it. | was blocking testnet-1; **fixed — PR #8 merged `642e7b3`, 2026-09-16** |
| 2026-09-21 | **`infra/runbooks/coordinated-upgrade.md` rollback section would tombstone the entire validator set**: "restore `data/` from the H−1 snapshot, do not touch `priv_validator_state.json`" — the state file is *inside* `data/`; validators have already precommitted block H when the upgrade handler panics, so a restored set re-runs consensus at H and double-signs. | Correct recovery for a failed handler is `--unsafe-skip-upgrades H` on the old binary, never a data restore; if `data/` is ever restored, re-place the current state file. Rewrite before the phase-5 drill. Fix in flight on `close-known-gaps`. | **open — critical (runbook)** |
| 2026-09-21 | **Frozen address can still be drained via a pre-freeze allowance on the werc20 precompile, and funded by any contract call.** `x/compliance` enforces at the ante (signers + tx `to`), not at bank level; precompiles move balance directly. Reproduced (see §5a P20). | Needs a bank `SendRestriction` keyed on the block list, or precompile wrapping. Not blocking testnet-1; **must close before mainnet** (D6 semantics as documented to exchanges are wrong until then). | **fixed — PR #15, merged `06f9ebe` 2026-09-29** |
| 2026-09-15 | Fee collector `Burner` permission is stored on the module account at creation. A network that ever ran a binary without it (or a genesis exported from one) will panic in `BurnCoins` at the first EndBlock with gas used after upgrading to PR #5. | Not a problem for testnet-1 or mainnet, which start on a post-PR-#5 binary. Recorded so the first real upgrade handler pattern includes "rewrite module account permissions" if it ever applies. | note |

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
- `app/mempool.go` wraps cosmos/evm's mempool (`complianceMempool`) so the D6
  freeze check runs on the JSON-RPC's direct `Mempool.Insert` path. cosmos/evm's
  `server/start.go` type-asserts `*evmmempool.Mempool` to call `SetClientCtx`;
  that assertion no longer matches and the call is skipped. **Harmless on
  v0.7.3 — the setter stores a value nothing reads.** Every upstream bump
  (§17 upstream-release review) must grep `clientCtx` in `mempool/` and, if a
  reader appeared, forward the call from the wrapper. Flagged by the PR #10
  human review; `app/upstream_pin_test.go` fails on any cosmos/evm version
  change and prints this check (and the EIP-7702 one below) so it cannot be
  skipped.
- `x/compliance/ante` treats the authority of every EIP-7702 authorization
  as a signer (PR #10 `/code-review`, 2026-09-17): without it a clean relayer
  could install code on a frozen EOA and drain it by internal call. A
  delegation installed *before* the freeze is cleared by the keeper at
  freeze time (`x/compliance/keeper/delegation.go`, decided 2026-09-19,
  `ENGINEERING.md §10`): only the `0xef0100‖addr` code hash goes, storage
  stays, real contract bytecode is never touched. The keeper gets x/vm via
  `SetEVMKeeper` in `app.New` because it is built before the EVM keeper
  (the precompile needs it); `tests/integration` fails if that wiring is
  dropped. Emits `compliance_delegation_reset`.
- `tests/integration` is behind the `test` build tag (`make test-integration`,
  CI runs it). Not optional: cosmos/evm's EVM chain config is a
  once-per-process global unless that tag is on, and every test builds its
  own app. `go test ./...` skips the directory silently.
- Upstream `evmd` (and so our `app.go`) hands the transfer keeper the channel
  keeper directly as its ICS4 wrapper, so the callbacks middleware is **not on
  the send path** — only on receive. Its own comment says otherwise. Not
  changed (matching upstream); the rate limiter is put on the send path
  explicitly (`TransferKeeper.WithICS4Wrapper(rateLimitMiddleware)`) and
  `tests/e2e/ibc_test.go` proves it is.
- `x/ratelimit` error acks carry only the ABCI code (`ABCI code: 6`), as all
  ibc-go error acks do; the reason and numbers are in the
  `ratelimit_quota_exceeded` event on the receiving chain. A refused *send*
  fails the tx with the full message.
- `tests/e2e` is its own Go module (interchaintest v10.0.1 is on SDK 0.53
  and carries third-party `replace` pins; `ENGINEERING.md §2.2` records why
  that is fine). `go test ./...` from the repo root does not enter it;
  `make test-e2e` does. It needs Docker running and `make docker-build`
  first; CI has a separate `e2e` job that does both.
- **An EVM tx that fails as an SDK tx is invisible to `eth_*`.** When an
  EVM tx passes the ante but fails at the SDK level in the block (code ≠ 0),
  cosmos/evm does not index it as an Ethereum tx (`indexer/kv_indexer.go`,
  `TxSucessOrExpectedFailure`): `eth_getTransactionReceipt` /
  `eth_getTransactionByHash` return "not found", gas is charged, and the
  reason is only in CometBFT's `tx_search`
  (`ethereum_tx.ethereumTxHash='0x…'`). Changing that means forking the
  indexer and RPC backend (§2.1), so instead the one case a user can hit by
  hand — a value transfer straight to a module account or precompile, the
  §4.1.1 guard — is now refused at the ante handler and the mempool
  pre-check (`app/blocked_recipient.go`, PR #11): `eth_sendRawTransaction`
  answers "… is not allowed to receive funds: it is the "fee_collector"
  module account", nothing is charged, the nonce is not consumed. Verified in
  `tests/integration` and against a real node in `tests/e2e`. Residual: value
  sent to a blocked address by an *internal* call (contract → module account)
  still fails at stateDB commit, invisibly. Worth a line in `docs/`
  troubleshooting when that page is written.
- `SenderCreatorV07`/`V08` look redundant next to the EntryPoints but are not:
  each EntryPoint's bytecode hard-references its SenderCreator as an immutable
  and a preinstall never runs the constructor that would have deployed it.
  Dropping either makes `getSenderAddress()` and every UserOp with `initCode`
  revert with empty data (`konstellation` PR #4 review; tests cover it).

- **A frozen signer is refused with different codes at CheckTx and DeliverTx**
  (PR #15): the mempool pre-check answers `compliance/6 "address is frozen"`; the
  ante chain fails earlier in cosmos/evm's fee deduction because the bank
  restriction refuses the fee send — `sdk/5 "… address is frozen: insufficient
  funds"`. Both refuse, nothing is charged, the reason is in the text. Also: a tx
  refused by the pre-check stays in CometBFT's tx cache (`tx already seen`) — resend
  with new bytes (new memo/fee), noted for the admission runbook.
- **A frozen balance can still go *up* from protocol completions** (gov deposit
  refunds, ICS-20 refunds, unbonding, validator-removal commission) — deliberate,
  PR #15: each was shown to halt the chain or corrupt module state if refused. A
  contract's internal `CALL{value}` into a frozen address fails invisibly at
  stateDB commit, the same class as the module-account guard; the direct
  `transfer`/`transferFrom` precompile paths are refused at submission instead.
- **`cmd/konstellationd/cmd/flags.go` re-parses slice flags after the SDK's config
  interception** — deliberate (PR #14): cosmos-sdk `server/util.go bindFlags` turns a
  TOML array into the one-element string `["[a b]"]` for every StringSlice flag
  (`ws-origins`, `index-events`, …), which is why a browser `Origin` matching
  `ws-origins` got 403. Remove when cosmos-sdk fixes it; `TestStartHonoursAppTomlWSOrigins`
  fails if the repair is dropped.
- **`contracts/src/vesting/*` revert on `release(address token)`** — deliberate.
  cosmos/evm's `werc20` precompile (`0xD4949664…`) presents the native balance
  as an ERC-20, so OZ `VestingWallet`'s stock ERC-20 path would let a
  beneficiary withdraw the same KASH twice (native + "ERC-20"). Vesting is
  native-KASH only; ERC-20s sent to a wallet are unrecoverable. Also
  `renounceOwnership` reverts.
- **`explorer` runs Blockscout with `ETHEREUM_JSONRPC_GETH_TRACE_BY_BLOCK=false`**
  — not a tuning choice: cosmos/evm v0.7.3's `debug_traceBlockByNumber` returns
  entries without `txHash` and Blockscout's block-level parser crashes on every
  batch. Per-tx `debug_traceTransaction` works and is what the indexer uses.
- **`contracts` compiles with bytecode metadata stripped** (`bytecode_hash =
  "none"`, `cbor_metadata = false`) so a comment edit cannot move a CREATE2
  address; only code / solc / optimizer / `evm_version` changes do, and
  `test/DeployWKASH.t.sol` pins the address so such a change fails loudly.
  Consequence: Blockscout source verification is a *partial* match.

## 4. Open decisions

**None remaining.** Every numbered decision (D1–D13) is resolved as of 2026-09-15 —
see §2 above and `ENGINEERING.md §11` for the full record. What's left is *building*
what D4/D5/D6/D9/D12 call for (§5), not deciding anything further.

One non-numbered item still open: the on-call rota (§17) — the model (shared,
any engineer, issue-driven, 1-working-day self-assign) is decided, and the
*mechanics* now exist (`infra/runbooks/on-call.md`, `close-known-gaps`), but the
schedule itself waits until validators exist, per §17's own text.

The 2026-09-20 parallel work surfaced a set of calls and doc inconsistencies;
the founder settled the substantive ones the same day (D7 re-decided, D16 new,
D12 shape, community pool, Blockscout) — see §2 and **§5a**, which also lists
what is still pending (P1–P10).

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
   - ~~**D4 (emission)**~~ ~~**D5 (base fee)**~~ built together in
     **PR #5** (https://github.com/Konstellation-Network/konstellation/pull/5,
     open 2026-09-15): `app/issuance.go` (√bonded curve as `x/mint`'s `MintFn`,
     F = 1265) and `app/feeburn.go` (EndBlock burn of `baseFee × BlockGasUsed`).
     Verified on a local node: curve to the digit; EVM and Cosmos txs each burn
     exactly `baseFee × gasUsed`; Δsupply = Σminted − Σburned. Two things still
     owed: re-derive `blocks_per_year` from observed testnet-1 block time before
     mainnet (gov param), and the **1 B KASH genesis supply** F was sized
     against is an assumption until `networks/` allocations exist.
   - ~~**D6 (compliance)**~~ built in **PR #10**
     (https://github.com/Konstellation-Network/konstellation/pull/10, opened
     2026-09-16, **merged `9ad388b` 2026-09-17** after three human review
     rounds and three automated passes — 15 findings, all closed with tests):
     `x/compliance` — allow + block lists, `MsgScheduleUpdate` behind the
     timelock, `MsgEmergencyFreeze` with auto-expiry, `MsgGovUpdate` override,
     ante enforcement across EVM and Cosmos plus a synchronous mempool
     pre-check, `ICompliance` precompile at `0x…0900`. Verified live end to
     end. Still owed before mainnet: **legal review** (§10), the foundation
     multisig address in `networks/konstellation-1/genesis.json`, and (Phase 3)
     IBC middleware so an incoming transfer to a frozen address is gated too.
     Follow-ups from the 2026-09-17 reviews, **both closed in PR #11
     (`40bafaa`, 2026-09-19)**: (a) the by-hand EVM checks (transfer, deploy,
     frozen sender at CheckTx + DeliverTx + Cosmos, frozen recipient,
     relayed 7702 authorization) are `tests/integration/compliance_test.go`,
     real signed txs through the real app — the test that would have caught
     `f63c1b7`. (b) a freeze on an EOA already carrying an EIP-7702
     delegation now clears it (`keeper/delegation.go`; decision recorded in
     `ENGINEERING.md §10`). `TestFreezeResetsExistingDelegation` first
     drains the delegated EOA through an ERC-4337 EntryPoint with a UserOp
     the owner signed off-chain and a clean relayer — proving the hole —
     then freezes and shows the same UserOp moves nothing, the
     `compliance_delegation_reset` event fires, and one re-delegation after
     lifting brings the wallet back already initialised (storage intact).
     Verified to fail without the fix (2026-09-19: "frozen delegated EOA was
     drained").
   - ~~**D12 (vesting):** `contracts/src/vesting/`~~ **built 2026-09-20 on
     `contracts` branch `vesting-d12`** (see §1). Owed: review + PR; the §5a
     defaults confirmed (team-schedule reading, 365-day year, immutable
     revoker/treasury, the TOKENOMICS §7 community-pool inconsistency); real
     beneficiaries/amounts/TGE in `script/config/vesting.json` when known; a
     `networks` CI check that genesis allocations at vesting-wallet addresses
     equal `DeployVesting.s.sol predict()` output (new §5.2 row).
   - **D9 (audit):** start scoping calls with Informal Systems now (lead
     times run weeks to months) — but per §12, actually schedule the audit
     once Phase 3 + D6 are stable, not before. **Scope changed 2026-09-16:**
     `x/` was empty when D9 was decided; `x/compliance` (PR #10) adds
     ~1,550 hand-written consensus-critical lines (keeper, ante extractor,
     mempool pre-check, precompile) that must be in the statement of work,
     alongside `app/feeburn.go` and `app/issuance.go`.
   - ~~**D7/D8 (whitepaper):**~~ **drafted 2026-09-20 on `whitepaper` branch
     `whitepaper-v1-draft`** (27 pp, see §1) including the D7 roadmap and D8
     sequencing. Owed: the 18 `\todo{}` answers (§5a lists the load-bearing
     ones), legal review of the compliance/disclaimer sections, review + PR,
     then `make release VERSION=v1.0`.
6. ~~Phase 3: `x/circuit` wired with multisig authority, IBC rate-limit middleware
   (§13)~~ **built 2026-09-19, merged 2026-09-20 as PR #12 (`a9051f6`)**. Not "just wiring" in the
   end: SDK 0.54 moved `x/circuit` to unmaintained `contrib/` (used anyway, D14), and
   no rate limiter exists for ibc-go v11, so `x/ratelimit` is ours (D15, ~800 lines +
   proto, in the audit scope). Also `x/compliance/ibc` (§18 IBC-to-frozen row). Tests:
   `x/ratelimit` keeper + mock-middleware units, `x/compliance/ibc` units,
   `tests/integration/circuit_test.go` (trip/reset, authz-nested, EVM pause),
   `tests/e2e/ibc_test.go` (two chains + Hermes, gov proposal, real transfers).
   PR #12 review fixes (2026-09-20): window reset/update carry the channel value
   forward on zero supply (was a deadlock until gov removed the limit);
   `GetRateLimit` propagates store errors instead of failing open; the circuit
   ante/mempool check walks into authz `MsgExec` (`app/circuit.go`). Same day:
   `Quota` gained optional `max_absolute_send/recv` (the lower of it and the
   percentage applies — needed for native-denom paths, where "1 %" is 1 % of
   the chain); `app/upstream_pin_test.go` now also pins cosmos-sdk so a bump
   forces the `contrib/x/circuit` re-check; setting quotas before a channel
   carries value is a §15 phase 9 gate — and is now possible for foreign
   tokens: a fresh `ibc/…` voucher has no supply, so `max_absolute_recv` stands
   alone until it does (third review round). REST `rate_limit/{channel}/{denom=**}`
   so voucher denoms resolve.
   **Owed:** the 3-of-5 operations multisig address for `circuit.account_permissions`
   in each network's genesis (a decision, not code); per-channel quotas by gov before
   any mainnet channel opens (D8).
7. ~~`tests/e2e` first test: EVM transfer *to a module account* rejected (§4.1.1)~~
   done 2026-09-19, twice: `tests/integration/module_account_test.go`
   (in-process, the x/vm guard itself, four module accounts) and
   `tests/e2e/module_account_test.go` (a real node, through
   `eth_sendRawTransaction`, plus what the RPC shows — see §3). `tests/e2e`
   now exists: `Dockerfile` (`konstellation:e2e`, not a release artifact),
   interchaintest v10.0.1 in its own module, four tests — the §2a restart
   regression (PR #8) as a real process restart, an emergency freeze issued
   through the CLI and refused at the JSON-RPC (`app/mempool.go`'s wrapper
   path, unreachable from ABCI-level tests), the module-account transfer,
   and chain identity (EIP-155 id from `init`). ~40 s per test, one
   single-validator chain each. Next for this directory: the Phase 5
   drills (upgrade, chaos, halt) once there is a release to upgrade from.
8. `networks/testnet-1/`: tooling and docs are in `networks` PR #1 (see §1). The
   genesis itself: once #5–#7 are on `konstellation` `main`, D6 is built and the
   §2a restart panic is fixed, tag a release, add it to `networks/RELEASES.md`,
   fill `testnet-1/allocations.json` with the real test addresses (faucet, dev
   multisig, five validator keys from `infra`), then
   `GENESIS_TIME=… scripts/gen-genesis.sh testnet-1 --pre-gentx` → gentxs →
   `--gentxs` → commit `genesis.json` + `genesis.sha256` (§6.2). Peers/endpoints
   in `chain.json`, `seeds.txt`, `persistent_peers.txt` need `infra` applied.
9. `.github` repo: **not** "org-wide `CODEOWNERS`" — GitHub doesn't support that;
   confirmed against GitHub's default-community-health-file docs 2026-09-15, which
   list `CONTRIBUTING`/`SECURITY`/`SUPPORT`/issue templates as org-defaultable and
   do not include `CODEOWNERS`. Added a `CODEOWNERS` template here (§17) plus notes
   in `README.md`/`ENGINEERING.md §5,§17` correcting the earlier wording. What's
   still open: each of the other repos needs its own committed `CODEOWNERS`,
   copied from this template — that's a task for a session scoped to that repo, not
   this one. Done so far: `networks` (PR #1, merged 2026-09-16); **every other repo
   on its 2026-09-20 branch** (`contracts`, `whitepaper`, `docs`, `chain-config`,
   `faucet`, `infra`, `explorer`) — lands when those merge. Note `gh api
   orgs/Konstellation-Network/members` now also lists `folajindayo` and `Signor1`,
   and `Sammyowase` (three, as of 2026-09-21), who are in neither the template nor any copy — decide whether to add them
   (§5a). (`ENGINEERING.md`, `CLAUDE.md`, `STATUS.md`, `wt` already live here;
   `bootstrap.sh` recreates the org dir.)
10. `infra`: testnet-1 scaffold pushed (`0b011f4`); ~~bastion + monitoring host,
    dedicated cosigners, runbooks~~ **built 2026-09-20 on branch
    `close-known-gaps`** (see §1), still not a real deployment. Before a real
    `terraform apply`: review + PR the branch; pick the state bucket
    (`backend.tf`); confirm the three topology defaults (§5a); fill the empty
    `konstellandd_version`/`*_sha256` vars (now also `prometheus_sha256`,
    `alertmanager_sha256`) once `konstellation` cuts a release (waits on step
    8); on-call rota + `alert_*` vault values; a route from the explorer host
    into a private network.

## 5a. Decisions surfaced 2026-09-20 — settled and pending

The parallel repo work surfaced these. The founder answered most the same day;
the rest wait. **Network column:** which network the decision actually bites on
(`ENGINEERING.md §18` is the authoritative matrix).

**Settled 2026-09-20** (recorded in `ENGINEERING.md §11` / `TOKENOMICS.md §7`):

| # | Decision | Outcome | Network |
|---|---|---|---|
| 1 | Community bucket: 30 M liquid vs 50 M pool seed | **50 M.** The community-pool seed is 50 M, written into genesis `distribution` state (module account — no key, gov-spend only, cannot be a vesting beneficiary). The other 280 M (grants 180 M, incentives 100 M) vests in non-revocable tranche wallets, 30/25/20/15/10 % per year. Genesis float is now 322 M (32.2 %). | mainnet economics; testnet-1 mirrors the *shape* with test addresses |
| 2 | Team vesting shape | **10 % of each grant liquid at genesis** (plain balance), 90 % behind a 12-month cliff then linear 36 months; 365-day years; `revoker`/`treasury` immutable per wallet. | mainnet; testnet-1 mirrors the shape |
| 3 | Validator set + "permissioned" mechanism (was D7 vs §9.4 contradiction) | **D7 re-decided: 10 validators at genesis, all foundation-run, `max_validators` 30, admission permissioned, opening up in stages by governance. D16: `MsgCreateValidator` disabled in `x/circuit` genesis state; the ops multisig resets/disables around each admission; a gov proposal removes it for good.** Same on both networks. §9.4, §15 phases 5–6, §18 reconciled. | **both, identically** |
| 4 | Blockscout version | **Ship the pinned public images (9.0.2 / v2.3.5) on testnet-1; re-decide before the mainnet explorer** (public images lag source by two majors). The `explorer` repo is configuration for a Blockscout we host — there is no in-house explorer. | testnet-1 now; mainnet re-decides |
| 5 | `CODEOWNERS` template missing two org members | **Tentative; leave the template as is.** | — |
| 6b | NFT indexing + media handler | **Enabled (2026-09-21)**: Blockscout's `nft_media_handler` worker runs in the stack; needs object storage per network (P11). | both |
| 6a | Faucet: where the KASH comes from | The faucet is a service holding one key; that key's address is a **genesis allocation on testnet-1 only**, funded from the "liquidity & public distribution" bucket (80 M test KASH, §18) — enough for 8 M requests at 10 KASH. No faucet exists on mainnet. | testnet-1 only |

**Still pending** (defaults in the branches stand until answered):

| # | Item | Default in place | Network |
|---|---|---|---|
| ~~P1~~ | ~~Foundation's share of the 10~~ **answered 2026-09-20: all 10 are foundation-run, both networks** → `infra` scales from 5 to 10 validators (being applied on `close-known-gaps`) | — | both |
| P2 | Whitepaper `\todo`s: roadmap stage triggers/targets for opening the set; mainnet 3-of-5 ops multisig and compliance-authority signer sets; bridge design; bundler/paymaster operator; audit SoW dates; bounty platform; publishing entity; whether team beneficiaries are named | placeholders | mainnet (multisigs also have testnet dev-key stand-ins) |
| P3 | Real team beneficiaries, amounts and TGE for `contracts/script/config/vesting.json` | example addresses | mainnet |
| P4 | `infra` state bucket (`backend.tf`) | none — must be created and named before any `terraform apply` | testnet-1 first |
| P5 | `infra` topology: per-cloud bastions vs one entry point; monitoring on GCP | per-cloud, GCP | testnet-1 first, mainnet inherits |
| P6 | npm scope `@konstellation-network` + a LICENSE for the org (no repo has one) | package `"private": true` | both (publishing) |
| P7 | Faucet amount and cooldown; captcha must be on before public | 10 KASH, 24 h, captcha off | testnet-1 only |
| P8 | `docs` hosting/domain | `docs.konstellation.network` placeholder | both |
| P9 | tenderduty (paging) is archived upstream — pick a maintained fork | tenderduty | mainnet (fine for testnet) |
| P11 | NFT media storage: an S3-compatible bucket (R2/S3) with TLS + anonymous read per network, keys into `explorer/.env.<net>` `NFT_MEDIA_S3_*`; a pinning/paid IPFS gateway (ipfs.io rate-limits) | local MinIO only | testnet-1 first |
| ~~P27~~ (done PR #14 `3243793`: cause is cosmos-sdk v0.54.3 `server/util.go bindFlags` flattening TOML arrays into one-element slices — not cosmos/evm `checkOrigin`; repaired in `cmd/konstellationd/cmd/flags.go`, drop when fixed upstream; README tells dapp devs to list hosts) | `konstellation` JSON-RPC WebSocket: with `ws-origins = ["127.0.0.1", "localhost"]` an upgrade carrying `Origin: http://localhost` or `http://127.0.0.1` gets **403** while a request with no `Origin` passes (explorer review, dev node). Either the running node's allowed-origins slice is not what app.toml says (flag/TOML-array parsing) or `checkOrigin` compares differently; browser dapps using `eth_subscribe` over WS would be refused. Reproduce and fix or document. | open | both |
| **P28** | **`networks/scripts/gen-genesis.sh` must write the circuit super-admin** (`app_state.circuit.account_permissions` = the ops multisig / dev key with `LEVEL_SUPER_ADMIN`) — today a script-cut genesis closes the `MsgCreateValidator` gate with no admin, so every admission or emergency trip would first need a governance proposal (3 d mainnet). Add a `--circuit-admin <bech32>` step required with `--gentxs`, and a `verify.sh` assertion (list == [MsgCreateValidator], ≥ 1 super-admin). Also update `infra/runbooks/validator-admission.md` for the real window shape (reset N → create N+1 → disable; never broadcast the pre-signed file before `query tx <reset>` shows a height; re-sign if refused). | missing | both |
| ~~P26~~ (done `c1f1337` on PR #13) | `konstellation/RELEASING.md` and the release-notes text in `release.yml` verify provenance with `gh attestation verify --owner Konstellation-Network`, which accepts a build attested from **any** org repo. Change to `--repo Konstellation-Network/konstellation --signer-workflow Konstellation-Network/konstellation/.github/workflows/release.yml` (docs already say so). Small; fold into the release-workflow PR. | `--owner` | both |
| ~~P24~~ (done PR #14 `8605e79`: 0x…0803 dropped from `ActiveStaticPrecompiles`, 10 active; `docs/contracts.md:86` still lists vesting — docs follow-up) | **Genesis marks the `vesting` precompile (`0x…0803`) active but cosmos/evm v0.7.3 ships no implementation** — every call/tx to it fails with `precompiled contract not stored in memory` (adversarial chain-config review 2026-09-21). Drop it from `ActiveStaticPrecompiles` in `konstellation/app/genesis.go` (and from chain-config/docs), or document it as inert. | listed active | both |
| **P25** | **Register EIP-155 ids 5667 / 56671 at `ethereum-lists/chains` now** (D1 said "before testnet"; still absent 2026-09-21 — wallets warn, and nobody else must take them) and **claim the npm org `@konstellation-network`** before any repo goes public (`@konstellation` already belongs to a stranger; a squat at the exact install name is the risk). Ties to P6. | unregistered / unclaimed | both |
| **P21** (interim in infra `3dfae83`) | **Cosigner admin domains (adversarial infra review 2026-09-21).** One `deploy` SSH key with NOPASSWD root on every host incl. all three Horcrux cosigners — one leaked key = three shards = the consensus key of all ten validators. Also the default `cosigner_placement` puts two shards in one hcloud account (one API token → rescue-boot two servers → threshold). Decide: separate keys/operators per cosigner, hardware-backed, sudo restricted; one shard per provider (needs a third provider, ties to P16). **Mainnet-blocking.** | one key, 2 shards on Hetzner | mainnet (testnet colocated) |
| **P22** (interim in infra `3dfae83`) | **Cosigner connectivity in `dedicated` mode**: cosigners reach each other through the bastion WireGuard tunnel, so tunnel down → the far-cloud cosigner is partitioned → 5 of 10 validators stop signing → halt. Cosigners need their own peer-pinned mesh over public IPs (or redundant tunnels). README and `CloudUnreachable` currently claim the opposite. | tunnel | mainnet |
| **P23** (interim in infra `3dfae83`) | **Sentry topology**: one sentry per validator and `persistent_peers` = own sentry; four DoS'd sentry IPs halt the chain. Each validator should peer with ≥ 2 sentries and sentries cross-peer. Also validators admit p2p from the whole /24 (incl. the internet-facing RPC node) — narrow to own sentries. | 1:1 | both |
| ~~P20~~ (fixed, PR #15 `402a921`: bank `SendRestriction` + x/vm balance guard + submission-time refusal of `transfer`/`transferFrom` naming a frozen address; exemptions for gov deposit refunds, ICS-20 refunds, unbonding, validator-removal commission — each demonstrated necessary) | Was: **A compliance freeze does not immobilise bank balance (chain bug, adversarial docs review 2026-09-21).** Reproduced on the dev chain: an EOA approves a spender on the werc20 precompile (`0xD4949664…`), is emergency-frozen (`isFrozen` true, its own sends refused), then `transferFrom(frozen, spender)` **succeeds** and `transfer(to = frozen)` succeeds. The ante checks signers and the tx `to` (the precompile); the precompile moves bank balance directly and `x/compliance` installs no bank `SendRestriction`. Any pre-freeze ERC-20/contract allowance drains a frozen account; any contract call funds it. Fix in `konstellation`: a bank send restriction on frozen `from`/`to` (covers werc20, IBC, everything), and/or a compliance wrapper on the werc20/bank precompiles like `app/circuit_precompiles.go`; then re-state the semantics in docs/whitepaper honestly ("a freeze stops signing and being the direct recipient"). Audit scope. | open | both |
| **P16** | **Liveness under provider loss (adversarial whitepaper review, 2026-09-21).** 5 Hetzner + 5 GCP at equal stake: losing either provider = 50 % of voting power → CometBFT halts (>⅓ offline). All five GCP validators sit in **one region, `us-central1`** (`infra/terraform/envs/testnet-1/variables.tf`), so one regional outage halts the chain; the §15 chaos test (kill 40 %) is past the halt threshold by construction. The split prevents forging/censorship, not halts. Decide: a third provider, unequal weighting, or accept halt-on-provider-loss (and say so). At minimum spread the GCP five across regions. | as built | both |
| **P17** | **`x/compliance` can freeze governance out (chain bug class).** *Design note in PR #15: option A (exempt gov messages from the ante check) is now weaker — a frozen signer cannot pay fees after PR #15, so A also needs a fee carve-out and lets a frozen large staker keep voting; **option B recommended: widen the protected set so bonded validator operators and x/circuit super-admins can be frozen only by governance, never by the list authority** (same pattern as the existing authority protection).* Protected-from-freeze = module accounts, gov, the authority (`app.go:1132-1144`); validator operator accounts, the ops 3-of-5 and the treasury multisig are freezable, and the ante refuses any tx from a frozen signer incl. `MsgVote`/`MsgDeposit`. A compromised authority freezes the ten operators + ops multisig, schedules the permanent adds → 100 % of bonded stake cannot vote, quorum unreachable forever, breaker untrippable. Fix in `konstellation`: exempt `x/gov` messages from the freeze check and/or add bonded operators + circuit super-admins to the protected set; add to the audit scope. | open | both |
| **P18** | **Unquoted IBC paths pass `x/ratelimit` untouched** (`keeper/flow.go:164-176`) and channel handshakes are permissionless — "no channel carries value until governance sets a quota" (§15 phase 9) is procedure, not a property; an exploit's exit through a fresh channel is unlimited. Decide: ship `/ibc.applications.transfer.v1.MsgTransfer` in circuit `disabled_type_urls` at genesis (D16 pattern; both networks) or make `x/ratelimit` default-deny for unquoted paths. | open | mainnet (testnet has no channels) |
| **P19** | **Are the five multisigs distinct key sets?** compliance authority, ops 3-of-5 (circuit), team-grant revoker, treasury, community-tranche beneficiary. One set = one compromise freezes, pauses EVM/IBC, and controls 250 M treasury + 198 M revoke + 280 M community. Intent should be: compliance authority and ops multisig ≠ treasury. Ties to P2/P14. | unstated | mainnet |
| P15 | **Two infra defaults from the fix round (2026-09-21, `3f68c01`)**: (a) GCP validators now `on_host_maintenance = MIGRATE` (GCP docs say Local SSD live-migrates with data; was `TERMINATE` + auto-restart, the §2.7 path) — re-confirm against current GCP docs before the first apply; (b) the public RPC node runs node-local `minimum-gas-prices = 1000000000esp` (1 gwei) as a spam guard — protocol floor stays 0 (`TOKENOMICS.md §3`); confirm the number. | as stated | testnet-1 first |
| P14 | **Vesting `revoker`/`treasury` type** (contracts review L3): both are immutable per wallet, so they must be address-stable — an EVM Safe qualifies, a Cosmos `x/auth` multisig does **not** (address derives from pubkeys+threshold, changes on signer rotation). Keep immutable (current) or add a timelocked `setRevoker`. Ties to P2 (which multisig). | immutable | mainnet |
| P13 | `networks/testnet-1/README.md` still says "in-house (5 nodes) … 3–5 external operators invited in phase 6" and offers readers the gentx path — stale D7/D16 (docs review 2026-09-21). Fix with the genesis work. | stale | testnet-1 |
| ~~P12~~ | **done 2026-09-22, konstellation PR #14 (`dbc61d4`)**: `init` writes the disable list on every chain-id; unit/integration/e2e cover the refusal string and the admission window; **but** nothing writes the super-admin: `gen-genesis.sh` produces a genesis with the gate closed and `account_permissions` empty (adversarial review) — see P28. Was: **D16 is decided but not implemented in genesis tooling**: `konstellationd init` writes `x/circuit` `disabled_type_urls: []` and `networks/scripts/gen-genesis.sh` has no circuit step (found by the docs review 2026-09-21). Add `/cosmos.staking.v1beta1.MsgCreateValidator` to circuit genesis state in `gen-genesis.sh` (or the network profile) before the testnet-1 genesis is cut; `tests/e2e` should assert the refusal. | not done | both |
| ~~P10~~ | ~~D16 admission runbook~~ **written** (`infra/runbooks/validator-admission.md`, `close-known-gaps` `7ae9164`); rehearsal is a §15 phase 5 item | — | both |

## 6. Tooling and locations

- `./wt` at org root: `init`, `create` (GitHub, private), `clone`, `new`/`rm`
  worktrees, `status`, `each`. Refuses `evm`/`cosmos-sdk`/`cometbft`/`ibc-go`.
- `~/src/evm-reference`: local clone of cosmos/evm at **v0.7.3**. Never pushed.
  Use it to diff upstream releases (`ENGINEERING.md §16`).
- `konstellation`: `make build` (sha256 printed), `make verify-deps`,
  `make vulncheck` / `vulncheck-binary`, `make test-unit`, `make test-integration`
  (in-process app tests, `-tags test`; ~2 s), `make docker-build` + `make test-e2e`
  (interchaintest against real nodes; ~8 min for five tests, the two-chain IBC one is
  ~4 min and pulls `ghcr.io/informalsystems/hermes`; Docker Desktop must be
  running — `open -a Docker`), `make lint` / `lint-e2e`,
  `./local_node.sh -y` (dev chain, JSON-RPC :8545, metrics :26660, chain id 56670).
- Dev mnemonics in `local_node.sh` are public; `dev0` = `0xC6Fe5D33615a1C52c08018c47E8Bc53646A0E101`.
- `contracts`: `forge test`; `forge script script/DeployWKASH.s.sol` / `DeployVesting.s.sol`
  (`predict()` prints addresses for genesis allocations). `chain-config`: `npm test`
  (the §5.2 invariant needs `../contracts` and `../konstellation` present, or
  `KONSTELLATION_CONTRACTS_DIR` / `KONSTELLATION_CHAIN_DIR`). `faucet`: `npm test`;
  `FAUCET_PRIVATE_KEY=<dev0> RPC_URL=http://127.0.0.1:8545 CHAIN_ID=56670 npm start`.
  `explorer`: `docker compose --env-file .env.local up -d` → http://localhost:3080
  (needs a node on :8545 with `--pruning nothing` and the `debug` namespace on;
  `.env.local` sets `COMPOSE_PROFILES=local-s3` so NFT thumbnails work at :3082).
  `docs`: `npx docusaurus start --port 3002` (3000 is often taken by Docker).
  `whitepaper`: `make pdf` (tectonic or latexmk), `make check`. `infra`: `tofu`
  works in place of terraform for `fmt`/`validate`/credential-free `plan`.

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

## 9. How PR #13 (release workflow) was reviewed — 2026-09-22

`/code-review` against `release-workflow`. Four findings, all fixed in that
branch. Three are worth carrying forward because they are not visible in the
final diff:

- **`actions/checkout@v4` destroys annotated tags.** On a tag push `github.sha`
  is the *commit* SHA, so checkout's `testRef()` compares it against
  `git rev-parse refs/tags/<tag>` (the *tag object* SHA), never matches, and
  re-fetches `+<commit>:refs/tags/<tag>` — rewriting the annotated tag into a
  lightweight one in the workspace (actions/checkout#290; fixed only on v5).
  Any workspace `git cat-file -t`/`git rev-parse` on a pushed tag is therefore
  wrong. `release.yml` asks the GitHub API instead. Do not "simplify" it back
  to git.
- **The release binary must be built in bookworm** (ENGINEERING.md §3, new
  row). CGO is on and nothing static-links, so building on the ubuntu-24.04
  runner links against glibc 2.39 while the fleet is debian-12/glibc 2.36 —
  a release that goes green and then bricks every validator at the upgrade
  height. It runs as `docker run` rather than a job-level `container:`
  deliberately: the "Free disk space" step is a host step, and without it the
  link runs the runner out of space (`ci.yml`, 2026-09-20). Note that
  `make verify-deps` stays on the host — `golang:1.26-bookworm` ships no jq.
  `BUILD_IMAGE` is a **digest**, not that tag: the tag moves on every Go patch
  and Debian rebuild, and if it moved between the two matrix builds the
  release would fail as "non-reproducible" with nothing actually wrong. It is
  bumped by hand — see RELEASING.md's pre-tag checklist.
- **`SHA256SUMS` is now checked against the bytes being published**, not just
  against the other runner's string. That file is what `networks/RELEASES.md`
  and `infra`'s `konstellationd_sha256` are copied from, so a bad artifact
  round-trip would have broken verification for every operator after the fact.

The fourth was a doc slip: `RELEASING.md` said `upgrades/<version>.md`; the
convention is `upgrades/v<N>-<name>.md`, `<name>` being the
`MsgSoftwareUpgrade` plan name (`networks/templates/upgrade.md`, §6.2).

Still unverified end to end: no signed tag has been pushed through the
workflow yet. The first real tag is the proof — watch the `tag` job and the
`debian:12` smoke-run specifically.
