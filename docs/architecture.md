# Architecture Overview (Blackholed Token)

This document describes the on-chain architecture of the Graveyard Trespasser (GRAVE) ecosystem after the GRAVE token canister has been **permanently blackholed**.  
The token code, emission schedule, and vesting logic are now immutable and cannot be upgraded.

---

## Components

- **GraveToken** (blackholed ICRC-1/2 token canister)
- **GraveAutoStaker** (liquidity automation canister)
- **ICP Ledger**
- **ICPSwap Pool**
- **Blackhole Principal `aaaaa-aa`**
- **User wallets**

---

## High-Level Architecture (ASCII)

```
                       ┌────────────────────────────┐
                       │  User Wallet / ICP Holder  │
                       └───────────────┬────────────┘
                                       │ contribute
                                       ▼
                          ┌─────────────────────────┐
                          │     GraveToken          │
                          │      (Blackholed)       │
                          ├─────────────────────────┤
                          │ - ICRC-1 & ICRC-2       │
                          │ - daily emission        │
                          │ - vesting               │
                          │ - contribution tracking │
                          │ - immutable logic       │
                          └──────────┬──────────────┘
                                     │
                   ┌─────────────────┼─────────────────┐
                   │                 │                 │
                   │ 10% to reserve  │ 90% to LP wallet│
                   ▼                 ▼                 (operator wallet)
          ┌────────────────┐   ┌────────────────┐
          │ reserve wallet │   │ LP operator    │
          └────────────────┘   └────────────────┘
                                      │ manually deposit to pool
                                      ▼
                             ┌────────────────────┐
                             │   ICPSwap Pool     │
                             │    (Uniswap v3)    │
                             └───────┬────────────┘
                                     │ LP minted
                                     ▼
                          ┌──────────────────────────┐
                          │  BLACKHOLE principal     │
                          │       aaaaa-aa           │
                          │   (permanent LP burn)    │
                          └──────────┬───────────────┘
                                     │
                                     ▼

                     ┌──────────────────────────────┐
                     │      GraveAutoStaker          │
                     ├──────────────────────────────┤
                     │ - daily ICP check             │
                     │ - swap half to GRAVE          │
                     │ - mint LP full-range          │
                     │ - send LP to blackhole        │
                     │ - dynamic ticks               │
                     └──────────────────────────────┘
```

---

## Flow Summary

1. Users contribute ICP  
2. ICP routed to reserve + LP operator  
3. GRAVE token records contributions and vesting  
4. Daily emission mints new GRAVE autonomously  
5. Auto-staker deposits ICP into ICPSwap  
6. Half swapped for GRAVE  
7. LP minted full-range  
8. LP transferred to `aaaaa-aa` for permanent locking  

At no point can anyone withdraw liquidity or mint arbitrary supply.

---

## Blackholed Token Behaviour

The GRAVE token canister:

- has no controller
- cannot be upgraded
- cannot be paused
- cannot be edited
- will emit GRAVE autonomously forever
- applies daily emission decay
- continues vesting logic
- allows claims from users
- enforces ICRC-1 and ICRC-2 rules permanently

Admin functions are permanently disabled.

---

## Liquidity Architecture

- All LP minted is transferred to the **blackhole principal (`aaaaa-aa`)**
- No human, wallet, or DAO controls LP
- Liquidity becomes permanent
- No rugpull possible
- No liquidity withdrawal possible

This ensures extreme decentralisation: liquidity is fully on-chain and permanently locked.

---

## Auto-Staker

The GraveAutoStaker canister:
- monitors ICP balance
- executes periodic buyback
- deposits to pool
- mints LP
- burns LP by transferring to blackhole
- optionally upgradable (until blackholed)

The auto-staker is separate from the token, allowing operational improvements without affecting token immutability.

---

## Trust Model After Blackhole

Because the token canister is already blackholed:

- emission & supply schedule are immutable
- no administrative override exists
- no mint authority beyond algorithmic emission
- vesting parameters are fixed
- supply inflation is entirely predictable

The only adjustable component is the auto-staker (unless it, too, becomes blackholed in the future).

---

## Guarantees

- Decentralised token (blackholed)
- Permanent LP (blackholed)
- Autonomous emission
- Immutable economics
- Immutable vesting schedule
- No emergency backdoors
- No privileged mint authority
- No controller exists

Everything behaves exactly as the deployed code specifies—forever.