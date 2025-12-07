# GraveToken – Token Canister (Blackholed)

This document describes the immutable GRAVE token canister.  
The token canister has already been **blackholed**, meaning its behaviour is now
permanent, autonomous, and cannot be changed or upgraded.

---

## Standards

The GRAVE token permanently implements:

- **ICRC-1** (core token)
- **ICRC-2** (allowances and approvals)

This ensures ongoing compatibility with:

- ICPSwap
- Kongswap
- IC wallets
- Any generic ICRC-1/2 tooling

No further protocol changes are possible.

---

## Metadata (Permanent)

- **Name:** `Graveyard Trespasser`
- **Symbol:** `GRAVE`
- **Decimals:** `8`
- **Fee:** `0`
- **Minting Account:** the token canister’s own principal

All metadata is final and can no longer be modified.

---

## Core ICRC Functions

### ICRC-1

- `icrc1_name`
- `icrc1_symbol`
- `icrc1_decimals`
- `icrc1_total_supply`
- `icrc1_fee`
- `icrc1_minting_account`
- `icrc1_metadata`
- `icrc1_supported_standards`
- `icrc1_balance_of`
- `icrc1_transfer`

### ICRC-2

- `icrc2_approve`
- `icrc2_allowance`
- `icrc2_transfer_from`

All functionality continues normally following blackholing.  
Allowance and transfer rules are entirely defined by the deployed code.

---

## Daily Emission (Immutable)

The emission schedule is autonomous.

- The canister mints `dailyMintAmount` each day (using `heartbeat`)
- After each emission, the daily rate decays by 1%:

```motoko
dailyMintAmount := dailyMintAmount * 99 / 100;
```

- If there were contributions that day:
  - minted GRAVE vests to contributors
- If no contributions:
  - minted GRAVE goes to the predefined reserve principal

These rules are hard-coded and cannot be changed.

---

## Contribution / Vesting Logic

Although the canister is blackholed, the contribution and claiming logic remain
functional:

### Contribute

- ICP is pulled using the ICP ledger (`icrc2_transfer_from`)
- 10% goes to the reserve wallet
- 90% goes to the LP operator wallet
- Contribution amounts are recorded and used for the next daily distribution

### Vesting

- GRAVE earned via contributions is vested to each principal
- Vesting duration is fixed (~30 days)
- Vesting unlocks linearly based on elapsed time

### Claiming

- Users may call `claimVestedGrave()` at any time
- Claimed amounts transfer from canister account to user account
- Remaining vesting continues autonomously

All vesting rules are permanently set.

---

## Admin Functions

Any function previously gated by the controller principal is now **permanently disabled**, including:

- `adminMint`
- `setLogo`
- `setPoolPrincipal`
- any function requiring `controllerPrincipal`

These calls will always fail because the canister has no valid controller.

---

## Immutable Behaviour

Because the token canister has been blackholed:

- no new code can ever be deployed
- no parameters can be changed
- no admin calls can be executed
- no minting beyond the emission schedule is possible
- no emergency fixes can be performed

The GRAVE token is now a fully autonomous on-chain asset.

---

## Guarantees

Following blackhole:

- Emissions continue indefinitely with built-in decay
- Vesting and claiming remain available
- Transfers and approvals behave exactly as deployed
- No arbitrary minting is possible
- No rug mechanics or admin backdoors exist
- All future behaviour is 100% determined by the immutable code

---

## Summary

GRAVE now operates as a **self-governing ICRC token** whose logic:

- cannot be upgraded  
- cannot be altered  
- cannot be administratively controlled  

The system’s supply, emission schedule, vesting behaviour, and transfer rules are
locked forever as deployed, providing a maximally decentralised and
tamper-resistant token.