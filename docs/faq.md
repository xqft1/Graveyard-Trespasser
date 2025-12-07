# FAQ – Graveyard Trespasser (GRAVE)

## What is GRAVE?

GRAVE (“Graveyard Trespasser”) is a token on the Internet Computer (IC) with:

- ICRC-1 / ICRC-2 support
- daily emission and vesting
- contribution-based distribution
- automated ICPSwap LP provisioning
- **blackholed token canister (immutable)**
- permanently locked liquidity

---

## Is the token transfer standard ICRC-1 or ICRC-2?

Both:

- **ICRC-1** – balances and transfers
- **ICRC-2** – allowance/approval logic and `transfer_from`

Compatible with most IC wallets and ICPSwap.

---

## How does the daily emission work?

- A `dailyMintAmount` mints once per day.
- It decays by 1% daily:
  - `dailyMintAmount := dailyMintAmount * 99 / 100`
- Distribution:
  - if ICP contributed → vests to contributors
  - if not → goes to the hardcoded reserve principal

All of this logic is now **permanently fixed**.

---

## What is vesting?

- Contribute ICP → receive vesting balance of GRAVE
- Vesting unlocks linearly over ~30 days
- Call `claimVestedGrave()` to receive unlocked tokens
- Vesting logic is now immutable

---

## What does “blackholed token canister” mean?

It means the token canister has no controller, and:

- cannot be upgraded
- cannot be changed
- admin functions are permanently disabled
- supply logic and emission rules are fixed
- no emergency override exists

The token is now fully autonomous.

---

## Will GRAVE still emit daily after blackholing?

Yes.

Daily minting is driven by `heartbeat()` inside the canister itself.  
This continues exactly as deployed, with no admin required.

---

## Can the team mint extra GRAVE after blackholing?

No.

- `adminMint` requires the controller principal
- The canister has no controller
- Therefore admin minting is permanently impossible
- Only the emission schedule mints supply

---

## How does liquidity become permanent?

- The auto-staker deposits ICP into ICPSwap
- Half converts to GRAVE
- Full-range LP is minted
- LP is transferred to the blackhole principal `aaaaa-aa`
- Blackholed LP is permanently locked and unrecoverable

No one (team, wallet, DAO, multisig) can pull liquidity.

---

## Do I have to use the auto-staker?

No.

You can:
- supply liquidity manually
- operate your own LP strategy
- or fork and replace the auto-staker

The auto-staker is reference logic.

---

## Is the auto-staker blackholed too?

Not necessarily.  
Only the **token** is currently blackholed.  

The auto-staker could be blackholed later, but does not need to be for the token to be decentralised.

---

## Can I fork this project?

Yes.

MIT licence allows:
- fork
- modify
- rebrand
- redeploy

Be sure to change:
- principal IDs
- emission schedule
- vesting params

---

## What happens if a bug is discovered?

In the **token** canister:
- it cannot be fixed
- behaviour is permanent
- supply logic cannot be patched

In the **auto-staker**:
- fixes may still be possible (until blackholed)


---

## Where can I learn more?

- Top-level [`README.md`](../README.md)
- [`architecture.md`](architecture.md)
- [`token.md`](token.md)
- [`auto-staker.md`](auto-staker.md)
- [`decentralisation.md`](decentralisation.md)