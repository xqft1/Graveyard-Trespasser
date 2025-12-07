# Decentralisation (Blackholed Token)

The GRAVE token canister has already been **blackholed**. This means the
token’s code, behaviour, emission schedule, and vesting logic are now
**permanent and cannot ever be changed**. No controller exists, and no upgrades
are possible.

---

## What Blackholing Means

- no administrator
- no controller
- no upgrade capability
- no emergency patching
- no parameter changes
- no additional privileged minting
- all admin functions are permanently disabled

The token is now a fully autonomous, self-governing smart contract.

---

## Supply & Emission

The supply is governed entirely by the deployed code:

- daily mint
- 1% daily decay of emission amount
- vesting to contributors
- permanent emission schedule

Nothing can change this behaviour, including the development team.

---

## Vesting and Claiming

All vesting and unlocking behaviour continues automatically:

- vesting period is fixed
- unlock rate is fixed
- claiming logic is fixed
- vesting rules cannot be modified

Users can always claim their vested tokens based on the immutable logic.

---

## Liquidity Lock (Blackhole Principal)

LP minted via the liquidity process is transferred to the **blackhole principal**
(`aaaaa-aa`), making it unrecoverable and permanently locked.

This ensures:

- no team custody of LP
- no ability to withdraw liquidity
- no rugpull potential
- permanent decentralisation of liquidity

---

## Trust Model

Because the token cannot be changed:

- there is no need to trust a developer
- no multi-sig controls exist
- no “admin key” can take control
- no future intervention is possible

The only behaviour you rely on is the code itself.

---

## Remaining Upgradable Components

The only potentially upgradable component is the **auto-staker**, which handles
LP formation. The token itself does not depend on upgrades to the auto-staker.

If desired, the auto-staker could also be blackholed in the future.

---

## Final State

The GRAVE token now operates as a fully decentralised system with:

- blackholed token logic
- immutable supply schedule
- immutable vesting behaviour
- permanent liquidity
- no administrators
- no external control

The smart contract is the final authority.