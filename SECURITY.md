# Security Policy

## Current Status

The **GRAVE token canister has been blackholed**.  
This means:

- no controllers exist
- no upgrades are possible
- the token logic cannot be altered
- no patches, hotfixes, or code changes can be applied

All behaviour of the token, its emission, and its vesting schedule are therefore **permanent and immutable**.

---

## Reporting a Vulnerability

If you believe you have found a security vulnerability involving:

- GRAVE token logic  
- vesting and emission behaviour  
- ICRC-1 / ICRC-2 implementation  
- interactions with the ICP ledger  
- interactions with ICPSwap  

…please understand that **the token canister cannot be modified** and any vulnerabilities in its internal logic are effectively permanent.

However, it may still be useful to report issues which affect:

- the auto-staker canister
- surrounding ecosystem contracts
- user interfaces
- documentation
- operational practices

For such reports, please contact the maintainers privately (e.g. via email or a channel linked from the official website).  
Do **not** open a public GitHub issue for security-sensitive information.

---

## What Happens If a Vulnerability Exists?

If a vulnerability exists in the **token canister**, it can **no longer be fixed**.

The GRAVE token has been designed with this immutability in mind.  
Any future behaviour follows the code exactly as deployed at the time of blackholing.

---

## Areas of Concern

Even though the token cannot be modified, researchers may still find it valuable to study:

- economic design assumptions
- vesting schedule implications
- emission decay behaviour
- allowance / transfer_from edge cases
- ICPSwap interactions and liquidity strategy
- interactions with the blackhole principal (`aaaaa-aa`)
- economic attack surfaces

Such research may benefit users and future projects, even if fixes cannot be applied here.

---

## Responsible Disclosure Still Matters

Although no code changes can be made to the token canister, responsible disclosure of issues related to the broader ecosystem is still appreciated, especially where user funds or liquidity could be indirectly affected by:

- the auto-staker
- the pooling strategy
- third-party integrations

If you believe user assets might be at risk in a way that can still be mitigated operationally (for example in the auto-staker), please disclose privately.

---

## Final Note

GRAVE has chosen the strongest possible decentralisation path by intentionally blackholing its token canister.  
This places the system in a **fully autonomous and immutable state**.

Any remaining risks are an inherent part of the design, and cannot be changed at the protocol level.