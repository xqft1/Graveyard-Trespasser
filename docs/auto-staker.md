# GraveAutoStaker – Auto Staking / LP Canister

This document describes the auto-staker canister, which automates:

- ICP → GRAVE buybacks
- LP minting in an ICPSwap pool
- blackholing of LP positions

---

## Goals

- Use excess ICP held by the canister to:
  - buy GRAVE
  - provide liquidity in a wide range
  - send LP positions to the blackhole principal `aaaaa-aa`
- Turn liquidity into a **permanent, non-withdrawable** pool.

---

## External Canisters

The auto-staker talks to:

- **ICP Ledger**
  - ICRC-1 + ICRC-2 interface (alias `ICRC`)
- **GRAVE Token**
  - ICRC ledger for price relation in pool
- **ICPSwap Pool**
  - Implements methods like:
    - `depositFrom`
    - `swap`
    - `getUserUnusedBalance`
    - `metadata`
    - `mint`
    - `transferPosition`

---

## Configuration

Key configuration fields:

- `ICP_FEE_E8S : Nat = 10_000`
  - ICP ledger transfer fee (0.0001 ICP).
- `POOL_FEE : Nat = 3000`
  - ICPSwap pool fee tier.
- `TICK_SPACING : Int = 60`
  - tick spacing for the fee tier (Uniswap v3 style).
- `GLOBAL_MIN_TICK`, `GLOBAL_MAX_TICK`
  - broad bounds for tick selection.
- `icpReserveE8s : Nat`
  - ICP amount to keep as a reserve (e.g. 0.1 ICP).
- `lastStakeTimeNanos : Int`
  - last time a successful stake/buyback happened.
- `ONE_DAY_NANOS`
  - minimum cooldown between runs.
- `minTick`, `maxTick`
  - last used tick range for LP minting.
- `BLACKHOLE : Principal = Principal.fromText("aaaaa-aa")`
  - principal to send LP positions to.

---

## Core Functions

### `manual_run() : async ()`

- Public entrypoint to run the staking logic.
- Calls `checkAndStake()` internally.

### `get_status()`

Returns a record:

- `icp_balance_e8s : Nat;`
- `last_processed_available_e8s : Nat;`
- `icp_reserve_e8s : Nat;`
- `last_run_nanos : Int;`
- `last_stake_time_nanos : Int;`
- `last_buyback_amount_e8s : Nat;`
- `min_tick : Int;`
- `max_tick : Int;`
- `one_day_nanos : Int;`

As part of `get_status`, it may also call `checkAndStake()` to ensure the state
is up-to-date.

### `update_config(newReserve, newMinTick_, newMaxTick_)`

Allows adjusting:

- ICP reserve amount
- minimum tick
- maximum tick

This function invokes `checkAndStake()` first, then applies updates.

---

## Internal Execution Flow

### `checkAndStake()`

1. Update `lastRunNanos` with current time.
2. If `lastStakeTimeNanos` is recent (within `ONE_DAY_NANOS`), exit.
3. Query `icp.icrc1_balance_of(icpAccount())`.
4. If balance ≤ `icpReserveE8s`, exit.
5. Compute `available = balance - icpReserveE8s`.
6. Compute `amountToUse = available / 2`.
7. If `amountToUse` is too small for fee, exit.
8. Call `buybackAndProvideFullRange(amountToUse)`.
9. If successful:
   - update `lastProcessedAvailableE8s`
   - update `lastStakeTimeNanos`
   - update `lastBuybackAmountE8s`

### `buybackAndProvideFullRange(amountE8s) : async Bool`

Steps:

1. Ensure `amountE8s > ICP_FEE_E8S`.
2. Compute `depositAmount = amountE8s - ICP_FEE_E8S`.
3. Compute `swapAmount = depositAmount / 2`.
4. Approve ICP pool spender (`icrc2_approve`).
5. Call `pool.depositFrom` to deposit ICP.
6. Call `pool.swap` to convert half ICP → GRAVE.
7. Call `pool.getUserUnusedBalance` to get internal balances:
   - `balance0` (ICP)
   - `balance1` (GRAVE)
8. Determine current tick from `pool.metadata()`.
9. Select a wide tick range around the current tick and align to `TICK_SPACING`.
10. Call `pool.mint` to create LP position.
11. Call `pool.transferPosition` to send LP position to `BLACKHOLE`.

---

## Blackholing Behaviour

- LP positions minted by the auto-staker are immediately transferred to
  `aaaaa-aa`.
- Once transferred:
  - no one can control or close those positions
  - liquidity stays in the pool effectively forever.

This provides **strong decentralisation of liquidity**, especially if used
consistently over time.

---

## Upgrade Considerations

Because the auto-staker is complex and interacts with external protocols, it is
often desirable to:

- keep it **upgradeable** initially, and only consider blackholing it once:
  - the logic is thoroughly tested
  - the strategy is stable
  - the community is comfortable with it being immutable

See [`decentralisation.md`](decentralisation.md) for more discussion.
