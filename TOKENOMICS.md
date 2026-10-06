# Konstellation — Tokenomics

**Last updated:** 2026-09-15 (genesis allocation decided, §7; community tax, gov deposit, min_gas_price decided). Single source of truth for every economic parameter
of the chain: what is decided, what it is set to, where in code it lives, and what
is still open. `ENGINEERING.md §11` records *that* a decision was made;
this file records the resulting numbers and how they interact. When a number
here and the code disagree, the code is what validators run — fix this file.

Genesis supply is **1,000,000,000 KASH** (decided 2026-09-15 with the allocation in §7).

---

## 1. Token

| | Value | Where |
|---|---|---|
| Symbol | **KASH** | D2 |
| Base denom | `esp`, 18 decimals (1 KASH = 10¹⁸ esp) | D2; `app/config/chain.go` |
| Gas token | KASH (same asset, no wrapped/second token) | §3 |
| Genesis supply | **1,000,000,000 KASH** | §7 |
| Max supply | **uncapped** (`x/mint` `max_supply = 0`) | `app/genesis.go` |
| WKASH (ERC-20 wrapper) | post-genesis deploy, not a preinstall, at **`0x34Ab8285C63b876717C2c56151700D02623559bE`** on every network (CREATE2, pinned 2026-09-20); the `werc20` precompile at `0xD4949664…` also exposes the native token to Solidity | `ENGINEERING.md §6.3` |

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
   only by governance. **2 %** (decided 2026-09-15; the SDK default, kept and
   set explicitly — konstellation PR #6).
2. The rest to validators pro-rata by bonded stake. Each validator takes its
   **commission** (chain-wide floor **5 %**, D10) and passes the remainder to
   its delegators pro-rata.

So a delegator's realised yield ≈ APR × (1 − 0.02) × (1 − commission).
At 25 % bonded with a 5 % commission validator: 8.00 % × 0.98 × 0.95 ≈ **7.45 %**.

---

## 3. Fees and burn (D5)

> Node-local note (2026-09-21): the protocol `min_gas_price` floor below is 0. The
> foundation's *public RPC node* additionally sets a node-local
> `minimum-gas-prices = 1000000000esp` (1 gwei) in `app.toml` as a spam guard
> (`infra` `group_vars/rpc.yml`). It is not consensus and changes nothing here;
> confirm the value (STATUS §5a P15).

Konstellation runs EIP-1559 for every transaction, EVM and Cosmos alike.

| Parameter | Value | Note |
|---|---|---|
| Initial base fee | 1 gwei-equivalent (10⁹ esp per gas) | cosmos/evm default; adjusts from block 1 |
| Base-fee change denominator | 8 | ±12.5 % per block max, as Ethereum |
| Elasticity multiplier | 2 | target = ½ block gas limit |
| `min_gas_price` (base-fee floor) | **0** | decided 2026-09-15 (PR #6): no protocol floor; the base fee may decay toward 0 when idle. Gov param if that ever changes |
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
| Launch validator set | **4 foundation-run validators at genesis, `max_validators` 30, further admission permissioned** (D7, re-decided 2026-09-29; mechanism D16) — same on testnet-1 and mainnet; devnet-1 runs 1 (D18) |

Slashed stake is burned. Code: `app/config/chain.go`, `app/app.go`.

---

## 5. Governance (D11)

| Parameter | Value | Note |
|---|---|---|
| Min proposal deposit | **1 000 KASH** | to enter the voting period (raised from SDK default 10, 2026-09-15, PR #6). **testnet-1: 10** |
| Expedited min deposit | **5 000 KASH** | 1-day vote, ⅔ threshold. **testnet-1: 50** |
| Max deposit period | 2 days | SDK default |
| Voting period | **3 days** | lengthen as the set decentralises. **testnet-1: 2 h** (`ENGINEERING.md §18`) |
| Expedited voting period | 1 day | SDK default. **testnet-1: 30 min** |
| Quorum | **33.4 %** | of bonded stake |
| Pass threshold | **50 %** | of non-abstain votes |
| Expedited threshold | 66.7 % | SDK default |
| Veto threshold | 33.4 % | SDK default |
| Deposit on veto | **burned** | `burn_vote_veto = true`, pinned (decided 2026-09-15) |
| Deposit on failed quorum / plain rejection / pass | **refunded** | `burn_vote_quorum = false`, `burn_proposal_deposit_prevote = false`, pinned |

Deposits are refunded on any outcome except veto, so **the deposit is a spam
bond, not a cost**: it decides who can afford to *propose*, not what proposing
costs. 1 000 KASH is 1 × 10⁻⁶ of the 1 B supply — inside what any serious
proposer holds, well above what a spammer wants locked for up to 5 days per
proposal. Governance parameter; adjustable by proposal.

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

## 7. Genesis allocation — DECIDED 2026-09-15

Brief from the founders: favour the founding team, the community/developers,
and a treasury. Confirmed as proposed. On a 1,000,000,000 KASH supply:

| Bucket | Share | KASH | Liquid at genesis | Vesting / release | Held by |
|---|---|---|---|---|---|
| **Founding team & early contributors** | **22 %** | 220 M | **22 M (10 % of each grant)** | remaining 90 %: 12-month cliff, then linear over 36 months (4 years total) — decided 2026-09-20 | liquid part paid to each member's address in genesis; locked part in a D12 revocable vesting wallet, one per person |
| **Community & developers** | **33 %** | 330 M | **50 M** (the community-pool seed, decided 2026-09-20) | remaining 280 M released over 5 years, front-loaded | see split below |
| **Treasury (foundation)** | **25 %** | 250 M | 50 M | 20 % liquid at genesis, remainder linear over 48 months | foundation multisig (≥ 3-of-5); vesting contract for the locked part |
| **Validator bootstrap & staking** | **12 %** | 120 M | 120 M, bonded | none — bonded at genesis via gentx | the foundation, as operator of all 4 launch validators, 30 M each (D7) |
| **Liquidity & public distribution** | **8 %** | 80 M | 80 M | none | foundation, earmarked (DEX liquidity, market makers, any public sale) |
| | **100 %** | 1 000 M | **322 M (32.2 %)** | | |

The x/circuit super admin must hold a genesis balance, or it has no account and
cannot sign an admission window or an emergency trip (`networks` #3, 2026-09-30).
The devnet-1 and testnet-1 example allocations carve **1 000 KASH** for it out of
the treasury row (treasury 249 999 000 + admin 1 000). Bucket totals and the 322 M
liquid figure are unchanged. Mainnet's funding for the operations multisig is to
be confirmed with its allocation list.

Community & developers, 33 %, split:

| Sub-bucket | Share | KASH | At genesis | Purpose | Steward |
|---|---|---|---|---|---|
| Ecosystem & developer grants | 18 % | 180 M | locked | builders, integrations, tooling, bug bounties | foundation grants committee; large grants ratified by governance. Non-revocable vesting wallets, beneficiary = foundation multisig, 5 yearly tranches 30/25/20/15/10 % (54/45/36/27/18 M), each vesting linearly within its year |
| User & developer incentives | 10 % | 100 M | locked | usage rewards, airdrops, liquidity-mining, hackathon prizes | foundation, programme by programme. Same wallet shape, tranches 30/25/20/15/10 % (30/25/20/15/10 M), linear within each year |
| On-chain community pool seed | 5 % | 50 M | **liquid** | governance-spendable from day one, on top of the 2 % tax | `x/distribution` community pool, gov proposals only — **written directly into genesis `distribution` state**, never through a contract |

The community pool is a Cosmos *module account*: no key holds it, only a passed
governance proposal (`MsgCommunityPoolSpend`) moves anything out, and the chain's
own §4.1.1 guard refuses EVM value transfers into it. So it is the one part of
this bucket that cannot sit behind a vesting contract; it is seeded in genesis
and grows by the 2 % tax. Grants and incentives, which the foundation spends
programmatically, are the parts that vest.

Why these numbers:

- **Team 22 %** is the middle of the L1 range (Solana 12.5 %, Aptos 19 %,
  Sui 20 %, Avalanche 10 %; Sei/Berachain higher). **10 % of each grant is
  liquid at launch** (decided 2026-09-20) so members have something in hand;
  the other 90 % is behind a 1-year cliff and vests over the following 3 years,
  so 90 % of the team's allocation is still unsellable in year 1.
- **Community 33 % is the largest bucket** — it is what "favour the community"
  looks like on paper, and grants + incentives are the actual growth lever for a
  new EVM chain.
- **Treasury 25 %** covers audits (D9), infra, legal, listings and multi-year
  runway; 20 % liquid because those costs start before launch.
- **Validator 12 % bonded at genesis** ⇒ ~120 M bonded on day one ⇒ **≈11.5 %
  staking APR** from D4's curve, high enough to pull outside delegations in as
  the set opens up (D7), and falling naturally as they arrive.
- **32.2 % liquid at genesis** (validators' bonded stake 120 M + treasury
  tranche 50 M + liquidity 80 M + community-pool seed 50 M + team 22 M) is
  enough float for a functioning market without a supply overhang; the bonded
  120 M is not actually sellable without a 21-day unbond, and the pool's 50 M
  only moves by governance.

Year-by-year circulating supply (issuance excluded; community = 50 M pool
seed at genesis + 280 M released 30 / 25 / 20 / 15 / 10 % per year; team =
22 M at genesis + 198 M vesting linearly from month 12 to month 48):

| End of year | Team | Community | Treasury | Validators | Liquidity | **Circulating** |
|---|---|---|---|---|---|---|
| genesis | 22 M | 50 M | 50 M | 120 M | 80 M | **322 M (32.2 %)** |
| 1 | 22 M | 134 M | 100 M | 120 M | 80 M | **456 M (45.6 %)** |
| 2 | 88 M | 204 M | 150 M | 120 M | 80 M | **642 M (64.2 %)** |
| 3 | 154 M | 260 M | 200 M | 120 M | 80 M | **814 M (81.4 %)** |
| 4 | 220 M | 302 M | 250 M | 120 M | 80 M | **972 M (97.2 %)** |
| 5 | 220 M | 330 M | 250 M | 120 M | 80 M | **1 000 M (100 %)** |

(Superseded 2026-09-20: the earlier table had team 0 at genesis and community
30 M; both moved by the decisions above.)

What this unblocks: the D12 vesting contracts have a concrete spec (cliff +
linear, per-beneficiary), and `networks/testnet-1/genesis.json` can mirror the
shape with test allocations (`ENGINEERING.md §18`). Team vesting is
**revocable** (decided 2026-09-15): the foundation multisig may revoke a
departing member's grant; unvested tokens return to the treasury, vested
tokens are the beneficiary's. Treasury and community schedules are not
revocable. Not needed
yet: names and individual amounts inside the team bucket.

**Code (2026-09-20):** `contracts/src/vesting/VestingSchedules.sol` (branch
`vesting-d12`) is where these numbers live; a vesting year is 365 days. The
locked 90 % of a team grant is *0 at the 12-month cliff, then linear over 36
months* (start = TGE + 1 y, cliff 0, duration 3 y); the liquid 10 % never
touches a contract — it is a plain genesis balance. Wallet addresses are
CREATE2-deterministic, so `genesis.json` funds each wallet directly; wallets are
`Ownable2Step`, and grant amounts must be whole KASH divisible by 10 (team) / 20
(community) for the split to be exact — **enforced by the deploy script since
2026-09-21**. The
community-pool seed is genesis `distribution` state (see the sub-bucket table).
The 30 M-vs-50 M inconsistency this section used to carry was resolved
2026-09-20 in favour of **50 M**.

**Glossary, because these words carry the whole section:** a *vesting schedule*
is the rule for when locked tokens become the holder's to move. A *cliff* is a
period during which nothing at all unlocks — the team's is 12 months, so a
member who leaves in month 8 walks away with only their liquid 10 %. *Linear
vesting* then releases a constant amount per second until the end (the team's
runs 36 months after the cliff, so at month 24 — twelve months into the
36 — one third of the locked part is releasable, matching the 88 M in the
table). *Tranches* split a bucket into dated portions: the community buckets
have one per year, front-loaded (30 % in year 1, then 25/20/15/10), and as
built each year's tranche vests linearly *within* its year, so the year-end
totals in the table are exact and nothing waits for a single unlock date. (If
hard step-unlocks at each year-end are wanted instead, that is a one-line change
in `VestingSchedules.communityTranche` — not chosen.) *Revocable* (team only) means
the foundation multisig can stop a schedule: what has vested stays with the
member, what has not returns to the treasury. `release()` on a wallet moves
whatever has vested so far to the beneficiary; nobody else can move it.

## 8. Open items

Not decisions in `ENGINEERING.md §11`'s sense (every numbered one is resolved),
but numbers that are either assumed, defaulted, or need re-checking:

| Item | Current | Why it matters | Where it gets settled |
|---|---|---|---|
| Genesis supply | **1 B KASH, decided** with §7 | F = 1265 was sized against it | — |
| `blocks_per_year` | 21,038,400 (1.5 s) | scales issuance linearly; must match observed block time | gov param, after testnet-1 |
| Whitepaper | **v1.0 drafted 2026-09-20** (`whitepaper` branch `whitepaper-v1-draft`, 27 pp) | economics section written from §2–§7; 18 `\todo{}` items and legal review outstanding | `whitepaper` |
| Team vesting shape | **decided 2026-09-20**: 10 % liquid at genesis; 90 % 0-at-cliff (12 mo) then linear 36 mo, 365-day years | — | `VestingSchedules.sol` + genesis allocations |
| Community 30 M liquid vs 50 M pool seed | **resolved 2026-09-20: 50 M**, seeded in genesis `distribution` state; 280 M vests | — | §7 |
| Portal XP to airdrop | **undecided** (STATUS P36). Portal pays 1/24 XP per hourly tap; a $1 one-day auto-streak pays 1 XP, recorded as `auto_streak` | the obvious source, "User & developer incentives" (§7), vests linearly within year 1, so little is unlocked at TGE | a founder decision, then a claim contract on konstellation-1 |
