# Konstellation — Tokenomics

**Last updated:** 2026-09-15. Single source of truth for every economic parameter
of the chain: what is decided, what it is set to, where in code it lives, and what
is still open. `ENGINEERING.md §11` records *that* a decision was made;
this file records the resulting numbers and how they interact. When a number
here and the code disagree, the code is what validators run — fix this file.

Numbers below assume a **1,000,000,000 KASH genesis supply**. That figure is an
assumption D4's issuance constant was sized against on 2026-09-15; it becomes a
fact when `networks/` genesis allocations are written (§7).

---

## 1. Token

| | Value | Where |
|---|---|---|
| Symbol | **KASH** | D2 |
| Base denom | `esp`, 18 decimals (1 KASH = 10¹⁸ esp) | D2; `app/config/chain.go` |
| Gas token | KASH (same asset, no wrapped/second token) | §3 |
| Genesis supply | **1,000,000,000 KASH** (assumed, see §7) | — |
| Max supply | **uncapped** (`x/mint` `max_supply = 0`) | `app/genesis.go` |
| WKASH (ERC-20 wrapper) | post-genesis deploy, not a preinstall; the `werc20` precompile at `0xD4949664…` also exposes the native token to Solidity | `ENGINEERING.md §6.3` |

---

## 2. Issuance (D4)

New KASH is minted every block as a pure function of how much is bonded:

```
annual issuance (KASH) = F × √(bonded KASH)          F = 1265
staking yield (APR)    = F ÷ √(bonded KASH)
```

Modelled on Ethereum post-merge. There is **no** bonded-ratio target and no
rate-of-change loop (the SDK's default 7–20 % band targeting 67 % bonded is
switched off: those params are zeroed in genesis and ignored).

| Bonded share | Bonded | Staking APR | Issued / yr | Issued as % of supply |
|---|---|---|---|---|
| 10 % | 100 M | 12.65 % | 12.65 M | 1.27 % |
| 25 % | 250 M | **8.00 %** | **20.0 M** | **2.00 %** |
| 50 % | 500 M | 5.66 % | 28.3 M | 2.83 % |
| 75 % | 750 M | 4.62 % | 34.6 M | 3.46 % |
| 100 % | 1 B | 4.00 % | 40.0 M | 4.00 % |

Properties worth knowing:

- Doubling bonded stake raises total issuance by √2 (×1.41) and cuts per-staker
  yield by the same factor. Yield never goes negative and never hits zero.
- Because issuance grows sub-linearly, the *inflation rate* (issued ÷ supply) is
  bounded: at most F ÷ √supply = 4 % with everything bonded.
- The yield is chain-wide; `x/distribution` pays validators pro-rata by bonded
  stake, so validator-set size (30, D10) does not change anyone's yield.
- **F is a protocol constant**, like Ethereum's `BASE_REWARD_FACTOR`: changing it
  is a coordinated software upgrade, not a governance parameter change.
- Per-block provision = annual ÷ `blocks_per_year`. `blocks_per_year` **is** a
  governance parameter and must match real block time (currently set for
  ~1.5 s: 21,038,400). If blocks are slower, issuance is proportionally lower
  than the table, and vice versa. Re-derive from observed testnet-1 block time
  before mainnet.

Code: `konstellation/app/issuance.go` (curve, installed as `x/mint`'s `MintFn`),
`app/config/chain.go` (`MintIssuanceFactor`, `MintBlocksPerYear`).

### 2.1 Where issued KASH goes

Minted coins enter the fee collector and are swept by `x/distribution` every
block, together with transaction tips (§3):

1. **Community tax** — `community_tax` share to the community pool, spendable
   only by governance. Currently the **SDK default 2 %** — not an explicit
   decision yet (§7).
2. The rest to validators pro-rata by bonded stake. Each validator takes its
   **commission** (chain-wide floor **5 %**, D10) and passes the remainder to
   its delegators pro-rata.

So a delegator's realised yield ≈ APR × (1 − 0.02) × (1 − commission).
At 25 % bonded with a 5 % commission validator: 8.00 % × 0.98 × 0.95 ≈ **7.45 %**.

---

## 3. Fees and burn (D5)

Konstellation runs EIP-1559 for every transaction, EVM and Cosmos alike.

| Parameter | Value | Note |
|---|---|---|
| Initial base fee | 1 gwei-equivalent (10⁹ esp per gas) | cosmos/evm default; adjusts from block 1 |
| Base-fee change denominator | 8 | ±12.5 % per block max, as Ethereum |
| Elasticity multiplier | 2 | target = ½ block gas limit |
| `min_gas_price` (base-fee floor) | **0** | cosmos/evm default — base fee can decay toward 0 in idle periods; see §7 |
| `min_gas_multiplier` | 0.5 | anti-manipulation floor on recorded gasWanted; not a user-facing charge |

**Every tx pays `gasUsed × (baseFee + tip)`.** Of that:

- **`baseFee × gasUsed` is burned** — destroyed at the end of every block,
  before `x/distribution` can see it. Ethereum semantics.
- **The tip** (`priority fee`) goes to validators and delegators through the same
  pipeline as issuance (§2.1).

For Cosmos-SDK txs, which prepay for `gasWanted`, the burn is still on
`gasUsed`; the `baseFee × (gasWanted − gasUsed)` slack goes to validators like a
tip. Code: `konstellation/app/feeburn.go`; the fee collector holds `Burner`.

### 3.1 Net supply

```
Δsupply per block = issuance(bonded) − baseFee × gasUsed
```

Burn scales with usage and congestion; issuance scales with stake. Order of
magnitude, at 1.5 s blocks (≈21 M blocks/yr):

| Avg base fee | Avg gas / block | Burned / yr |
|---|---|---|
| 1 gwei | 1 M | 21 k KASH |
| 1 gwei | 10 M | 210 k KASH |
| 10 gwei | 10 M | 2.1 M KASH |
| 50 gwei | 20 M | 21 M KASH |

Against ~20 M KASH/yr issued at 25 % bonded, the chain is **net inflationary
until sustained demand pushes the base fee into the tens of gwei** at high
utilisation — the same shape as Ethereum, where net deflation only occurred in
periods of heavy use. This is expected and not a design flaw: burn is a function
of demand for blockspace, issuance a function of security budget.

---

## 4. Staking (D10)

| Parameter | Value |
|---|---|
| Consensus | DPoS, `x/staking` |
| Active set (`max_validators`) | **30** |
| Unbonding period | **21 days** |
| Minimum commission | **5 %** |
| Double-sign slash | **5 %** of stake, permanent tombstone |
| Downtime slash | **0.01 %** of stake |
| Downtime definition | miss > 50 % of a 100-block window (SDK default) |
| Downtime jail | 10 minutes, then unjail tx (SDK default) |
| Launch validator set | 5–10 self-run nodes, permissioned at launch (D7) |

Slashed stake is burned. Code: `app/config/chain.go`, `app/app.go`.

---

## 5. Governance (D11)

| Parameter | Value | Note |
|---|---|---|
| Min proposal deposit | **10 KASH** | to enter the voting period |
| Expedited min deposit | **50 KASH** | 1-day vote, ⅔ threshold |
| Max deposit period | 2 days | SDK default |
| Voting period | **3 days** | lengthen as the set decentralises |
| Expedited voting period | 1 day | SDK default |
| Quorum | **33.4 %** | of bonded stake |
| Pass threshold | **50 %** | of non-abstain votes |
| Expedited threshold | 66.7 % | SDK default |
| Veto threshold | 33.4 % | SDK default |
| Deposit on veto | **burned** | SDK default (`burn_vote_veto = true`) |
| Deposit on failed quorum / plain rejection | refunded | SDK defaults |

Deposits are refunded on any outcome except veto, so **the deposit is a spam
bond, not a cost**. Against a 1 B supply, 10 KASH is 1 × 10⁻⁸ of supply —
roughly 50× smaller as a share of supply than Cosmos Hub's 250 ATOM. Whether
that is too low depends on KASH's price and how the community pool is guarded;
it is a governance parameter and can be raised by proposal at any time. Flagged
in §7.

Code: `app/config/chain.go`, `app/app.go`.

---

## 6. Flow of value, end to end

```
                     ┌─────────────── issuance: F × √bonded ───────────────┐
                     │                                                     ▼
 users ──gas×(base+tip)──▶ fee collector ──── EndBlock: burn base×gasUsed ──▶ 🔥
                                  │
                                  └──── next BeginBlock: x/distribution
                                            ├── 2 % community pool  (gov-spendable)
                                            └── 98 % validators, pro-rata by stake
                                                  ├── commission ≥ 5 %  → validator
                                                  └── remainder         → delegators
```

---

## 7. Open items

Not decisions in `ENGINEERING.md §11`'s sense (every numbered one is resolved),
but numbers that are either assumed, defaulted, or need re-checking:

| Item | Current | Why it matters | Where it gets settled |
|---|---|---|---|
| Genesis supply | 1 B KASH, **assumed** | F = 1265 was sized against it; a materially different supply should re-open F | `networks/<net>/genesis.json` allocations |
| Genesis allocation & vesting | not written | who holds what at block 1; vesting is Solidity contracts (D12), so allocations to vesting contracts need those built first | `networks/`, `contracts/src/vesting/` |
| Community tax | 2 % (SDK default) | 2 % of all issuance + tips accrues to a gov-controlled pool; no explicit decision recorded | `app/app.go` distribution genesis; gov param |
| Gov min deposit vs supply | 10 / 50 KASH | tiny as a share of 1 B; spam bond only | gov param, raise by proposal |
| `blocks_per_year` | 21,038,400 (1.5 s) | scales issuance linearly; must match observed block time | gov param, after testnet-1 |
| `min_gas_price` | 0 | base fee can decay to ~0 when idle; a floor guarantees a minimum burn and spam cost | feemarket gov param |
| Whitepaper | not written | §2–§6 above are the material for its economics section (D7, D8 also pending there) | `whitepaper` |
