# Graveyard Trespasser (GRAVE)

Graveyard Trespasser (ticker: **GRAVE**) is an open-source Internet Computer
(IC) token system with:

- A **blackholed ICRC-1 / ICRC-2 compatible token canister** (`GraveToken`)
- A **daily emission + vesting mechanism** based on ICP contributions
- A **contribution flow** that routes ICP to a reserve address and LP operator
- An **auto-staker canister** (`GraveAutoStaker`) that:
  - performs periodic ICP → GRAVE buybacks on ICPSwap
  - mints LP positions
  - sends LP positions to the **blackhole principal** `aaaaa-aa`
  - effectively locks liquidity permanently

The token canister **has already been blackholed**, making the token
fully autonomous, unchangeable, and permanently decentralised.

🔗 **Official Website**  
<https://xc3mi-sqaaa-aaaaj-a2mhq-cai.icp0.io/>

---

## 🧩 Components

### 1. `GraveToken` canister

Motoko actor (persistent) implementing:

- **ICRC-1**
  - `icrc1_name`, `icrc1_symbol`, `icrc1_decimals`
  - `icrc1_total_supply`, `icrc1_fee`
  - `icrc1_minting_account`
  - `icrc1_metadata`
  - `icrc1_supported_standards`
  - `icrc1_balance_of`
  - `icrc1_transfer`
- **ICRC-2**
  - `icrc2_approve`
  - `icrc2_allowance`
  - `icrc2_transfer_from`

Additional functionality:

- **Contribution & Vesting**
  - `contributeAndLockLiquidity(amountE8s : Nat)` pulls ICP from user via
    `icrc2_transfer_from` on the ICP ledger.
  - Tracks per-user contributions in `todayContrib`.
  - Distributes daily GRAVE based on share of total ICP contributed.
  - Vesting period is ~30 days; users claim via `claimVestedGrave()`.

- **Daily Emissions (via `heartbeat`)**
  - Once per “day” (using nanosecond timestamps) the canister:
    - aggregates contributions
    - calculates GRAVE emission for that day
    - mints to either:
      - the token canister account (if there were contributors), or
      - the reserve principal (if there were none)
  - `dailyMintAmount` decays by 1% each cycle:
    ```motoko
    dailyMintAmount := dailyMintAmount * 99 / 100;
    ```

- **Admin / View**
  - `adminMint(to, quantity)`
  - `setLogo(uri)`
  - `setPoolPrincipal(p)`
  - `getVestedAmount`, `getUnlockedAmount`
  - `getTotalICPContributed`, `getUserContribution`
  - `getPoolAccount`, `getNextMintTime`

Admin functions required a specific `controllerPrincipal`.  
Since the canister **is already blackholed**, these functions are now permanently unusable.

---

### 2. `GraveAutoStaker` canister

Motoko actor (persistent) that automates buyback and LP provisioning:

- Integrates with:
  - ICP ledger (ICRC-1 + ICRC-2 interface)
  - GRAVE token canister
  - ICPSwap pool canister

Core behaviour:

- Maintains a **reserve balance** of ICP
- Periodically (max once per 24h) checks its ICP balance
- Uses 50% of excess ICP to:
  1. Approve & deposit ICP into ICPSwap pool
  2. Swap half the ICP to GRAVE
  3. Mint full-range LP (wide ticks around current price)
  4. Transfer the LP position to **blackhole principal** `aaaaa-aa`

Key public methods:

- `manual_run()` – manually triggers the logic
- `get_status()` – returns current balances, last run time, last usage, ticks
- `update_config(newReserve, newMinTick, newMaxTick)` – adjusts configuration

---

## 🏗 Architecture

See [`docs/architecture.md`](docs/architecture.md) for an ASCII diagram and
explanation of the data flows between:

- users
- GraveToken canister (blackholed)
- GraveAutoStaker canister
- ICP ledger
- ICPSwap pool
- reserve and LP operator addresses
- blackhole principal

---

## 🧪 Development & Deployment

> These steps are intentionally generic. Adjust paths and canister names to
> your `dfx.json` and project layout.

### Clone

```bash
git clone https://github.com/xqft1/graveyard-trespasser.git
cd graveyard-trespasser
```