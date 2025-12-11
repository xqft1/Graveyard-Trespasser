// @inline wasm_memory_persistence

import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Timer "mo:base/Timer";

import ICRC "icrc_types";
import Pool "icpswap_pool";

// Persistent because we use stable vars and async calls
persistent actor GraveAutoStaker {

  // Combined ICRC-1 + ICRC-2 interface
  type ICRC = ICRC.ICRC1 and ICRC.ICRC2;

  // ------------------------------------------------------------------
  // External canisters (MUST be transient)
  // ------------------------------------------------------------------
  transient let icp : ICRC =
    actor ("ryjl3-tyaaa-aaaaa-aaaba-cai");

  transient let _grave : ICRC =
    actor ("w5t77-riaaa-aaaaj-a2mda-cai");

  transient let pool : Pool.SwapPool =
    actor ("6n6dj-bqaaa-aaaar-qbzbq-cai");

  // ------------------------------------------------------------------
  // Configuration
  // ------------------------------------------------------------------

  // ICP ledger transfer fee (0.0001 ICP)
  transient let ICP_FEE_E8S : Nat = 10_000;

  // ICPSwap pool fee from metadata() = 3000
  let POOL_FEE : Nat = 3000;

  // Tick spacing for fee tier 3000 (Uniswap V3 / ICPSwap standard)
  let TICK_SPACING : Int = 60;

  // Extremely wide, effectively "zero → infinity" safe bounds for this pool.
  // These are well inside the theoretical ±887272 limits, and spaced by 60.
  let GLOBAL_MIN_TICK : Int = -887_220;
  let GLOBAL_MAX_TICK : Int =  887_220;

  // Keep 0.1 ICP untouched in this canister
  stable var icpReserveE8s : Nat = 10_000_000;

  // Legacy variable required for upgrade compatibility (unused in logic)
  stable var minStakeE8s : Nat = 0;

  // Logging only
  stable var lastProcessedAvailableE8s : Nat = 0;

  // Time of the last successful buyback/LP
  stable var lastStakeTimeNanos : Int = 0;

  // Logging
  stable var lastRunNanos : Int = 0;

  // Track how much ICP was used last time
  stable var lastBuybackAmountE8s : Nat = 0;

  // Last ticks actually used for mint (for status/debug)
  stable var minTick : Int = GLOBAL_MIN_TICK;
  stable var maxTick : Int = GLOBAL_MAX_TICK;

  // Limit to once per 24 hours
  let ONE_DAY_NANOS : Int = 24 * 60 * 60 * 1_000_000_000;

  // ICPSwap token identifiers (metadata: token0 = ICP, token1 = GRAVE)
  let ICP_TOKEN_TEXT : Text = "ryjl3-tyaaa-aaaaa-aaaba-cai";
  let GRAVE_TOKEN_TEXT : Text = "w5t77-riaaa-aaaaj-a2mda-cai";

  // Blackhole principal for LP ownership
  let BLACKHOLE : Principal = Principal.fromText("aaaaa-aa");

  // ------------------------------------------------------------------
  // Helper: the ICRC account of THIS canister
  // ------------------------------------------------------------------
  func icpAccount() : ICRC.Account {
    {
      owner = Principal.fromActor(GraveAutoStaker);
      subaccount = null;
    }
  };

  // Align a tick to the grid (multiple of TICK_SPACING) and clamp to global range
  func alignAndClampTick(t : Int) : Int {
    let r = t % TICK_SPACING;
    var x = t - r; // round toward lower multiple
    if (x < GLOBAL_MIN_TICK) x := GLOBAL_MIN_TICK;
    if (x > GLOBAL_MAX_TICK) x := GLOBAL_MAX_TICK;
    x
  };

  // ------------------------------------------------------------------
  // 50% Daily Buyback & Full-Range LP Function
  // ------------------------------------------------------------------
  func buybackAndProvideFullRange(amountE8s : Nat) : async Bool {
    Debug.print("buybackAndProvideFullRange: amountE8s=" # Nat.toText(amountE8s));

    if (amountE8s <= ICP_FEE_E8S) {
      Debug.print("reject: amountE8s <= ICP_FEE_E8S");
      return false;
    };

    let acct = icpAccount();

    // Amount actually usable inside pool after paying ledger fee
    let depositAmount = amountE8s - ICP_FEE_E8S;
    Debug.print("depositAmount=" # Nat.toText(depositAmount));
    if (depositAmount == 0) return false;

    // Swap half of depositAmount into GRAVE
    let swapAmount : Nat = depositAmount / 2;
    Debug.print("swapAmount=" # Nat.toText(swapAmount));
    if (swapAmount == 0) return false;

    // ---- 1. Approve ICP for pool ----
    let approveRes = await icp.icrc2_approve({
      from_subaccount = acct.subaccount;
      spender = { owner = Principal.fromActor(pool); subaccount = null };
      amount = amountE8s;
      expected_allowance = null;
      expires_at = null;
      fee = null;
      memo = null;
      created_at_time = null;
    });

    Debug.print("approveRes=" # debug_show(approveRes));

    switch (approveRes) {
      case (#Err(e)) {
        Debug.print("approve error: " # debug_show(e));
        return false;
      };
      case (#Ok(_)) {};
    };

    // ---- 2. DepositFrom ICP into pool ----
    let depositRes = await pool.depositFrom({
      fee = ICP_FEE_E8S;
      token = ICP_TOKEN_TEXT;
      amount = depositAmount;
    });

    Debug.print("depositFromRes=" # debug_show(depositRes));

    switch (depositRes) {
      case (#err(e)) {
        Debug.print("depositFrom error: " # debug_show(e));
        return false;
      };
      case (#ok(_)) {};
    };

    // ---- 3. Swap half ICP -> GRAVE ----
    let swapRes = await pool.swap({
      amountIn = Nat.toText(swapAmount);
      zeroForOne = true;           // ICP -> GRAVE
      amountOutMinimum = "0";      // unlimited slippage
    });

    Debug.print("swapRes=" # debug_show(swapRes));

    switch (swapRes) {
      case (#err(e)) {
        Debug.print("swap error: " # debug_show(e));
        return false;
      };
      case (#ok(_)) {};
    };

    // ---- 4. Check our internal pool balances ----
    let selfPrincipal = Principal.fromActor(GraveAutoStaker);
    let unusedRes = await pool.getUserUnusedBalance(selfPrincipal);

    Debug.print("getUserUnusedBalance=" # debug_show(unusedRes));

    let balances = switch (unusedRes) {
      case (#err(e)) {
        Debug.print("getUserUnusedBalance error: " # debug_show(e));
        return false;
      };
      case (#ok(bals)) bals;
    };

    let bal0 = balances.balance0;  // ICP
    let bal1 = balances.balance1;  // GRAVE

    Debug.print(
      "internal balances: ICP=" # Nat.toText(bal0)
      # " GRAVE=" # Nat.toText(bal1)
    );

    if (bal0 == 0 or bal1 == 0) {
      Debug.print("cannot mint: one of balances is zero");
      return false;
    };

    // ---- 5. Build huge range around current tick ----
    var tickLower : Int = GLOBAL_MIN_TICK;
    var tickUpper : Int = GLOBAL_MAX_TICK;

    let metaRes = await pool.metadata();
    Debug.print("metadataRes=" # debug_show(metaRes));

    switch (metaRes) {
      case (#ok(meta)) {
        let curTick : Int = meta.tick;
        Debug.print("currentTick=" # Int.toText(curTick));

        let span : Int = 400_000;
        let rawLower : Int = curTick - span;
        let rawUpper : Int = curTick + span;

        tickLower := alignAndClampTick(rawLower);
        tickUpper := alignAndClampTick(rawUpper);

        if (tickLower >= tickUpper) {
          tickLower := alignAndClampTick(curTick - TICK_SPACING);
          tickUpper := alignAndClampTick(curTick + TICK_SPACING);
        };

        Debug.print(
          "using dynamic ticks: lower="
          # Int.toText(tickLower)
          # " upper=" # Int.toText(tickUpper)
        );
      };
      case (#err(e)) {
        Debug.print("metadata error, using stored ticks: " # debug_show(e));
        tickLower := minTick;
        tickUpper := maxTick;
      };
    };

    minTick := tickLower;
    maxTick := tickUpper;

    // ---- 6. Mint LP ----
    let mintRes = await pool.mint({
      fee = POOL_FEE;
      tickUpper = tickUpper;
      token0 = ICP_TOKEN_TEXT;
      token1 = GRAVE_TOKEN_TEXT;
      amount0Desired = Nat.toText(bal0);
      amount1Desired = Nat.toText(bal1);
      tickLower = tickLower;
    });

    Debug.print("mintRes=" # debug_show(mintRes));

    switch (mintRes) {
      case (#err(e)) {
        Debug.print("mint error: " # debug_show(e));
        return false;
      };

      case (#ok(positionId)) {
        Debug.print("mint ok, positionId=" # Nat.toText(positionId));

        // ---- 7. Immediately send LP position to blackhole principal ----
        let transferRes = await pool.transferPosition({
          positionId = positionId;
          to = BLACKHOLE;
        });

        Debug.print("transferPositionRes=" # debug_show(transferRes));

        switch (transferRes) {
          case (#err(e2)) {
            Debug.print("transferPosition error: " # debug_show(e2));
            // Position stays owned by this canister if this fails.
            // Return false so you notice in logs.
            return false;
          };
          case (#ok(_)) {
            Debug.print("position transferred to blackhole (aaaaa-aa)");
            return true;
          };
        };
      };
    };
  };

  // ------------------------------------------------------------------
  // Daily execution logic
  // ------------------------------------------------------------------
  func checkAndStake() : async () {
    let now = Time.now();
    lastRunNanos := now;

    if (lastStakeTimeNanos != 0 and (now - lastStakeTimeNanos) < ONE_DAY_NANOS) {
      Debug.print("checkAndStake: skip (cooldown)");
      return;
    };

    let acct = icpAccount();
    let currentBalance = await icp.icrc1_balance_of(acct);

    Debug.print("checkAndStake: currentBalance=" # Nat.toText(currentBalance));

    if (currentBalance <= icpReserveE8s) {
      Debug.print("checkAndStake: skip (<= reserve)");
      return;
    };

    let available = currentBalance - icpReserveE8s;
    Debug.print("checkAndStake: available=" # Nat.toText(available));
    if (available == 0) return;

    let amountToUse : Nat = available / 2;
    Debug.print("checkAndStake: amountToUse=" # Nat.toText(amountToUse));
    if (amountToUse <= ICP_FEE_E8S) {
      Debug.print("checkAndStake: skip (amountToUse <= fee)");
      return;
    };

    let ok = await buybackAndProvideFullRange(amountToUse);

    if (ok) {
      lastProcessedAvailableE8s := available;
      lastStakeTimeNanos := now;
      lastBuybackAmountE8s := amountToUse;
      Debug.print("checkAndStake: success, used=" # Nat.toText(amountToUse));
    } else {
      Debug.print("checkAndStake: buybackAndProvideFullRange returned false");
    };
  };

  // ------------------------------------------------------------------
  // Public update calls
  // ------------------------------------------------------------------
  public shared func manual_run() : async () {
    await checkAndStake();
  };

  public shared func get_status() : async {
    icp_balance_e8s : Nat;
    last_processed_available_e8s : Nat;
    icp_reserve_e8s : Nat;
    last_run_nanos : Int;
    last_stake_time_nanos : Int;
    last_buyback_amount_e8s : Nat;
    min_tick : Int;
    max_tick : Int;
    one_day_nanos : Int;
  } {

    await checkAndStake();

    {
      icp_balance_e8s = await icp.icrc1_balance_of(icpAccount());
      last_processed_available_e8s = lastProcessedAvailableE8s;
      icp_reserve_e8s = icpReserveE8s;
      last_run_nanos = lastRunNanos;
      last_stake_time_nanos = lastStakeTimeNanos;
      last_buyback_amount_e8s = lastBuybackAmountE8s;
      min_tick = minTick;
      max_tick = maxTick;
      one_day_nanos = ONE_DAY_NANOS;
    }
  };

  // ------------------------------------------------------------------
  // Update config
  // ------------------------------------------------------------------
  public shared func update_config(
    newReserve : ?Nat,
    newMinTick_ : ?Int,
    newMaxTick_ : ?Int
  ) : async () {

    await checkAndStake();

    switch (newReserve)  { case (?v) icpReserveE8s := v; case null {} };
    switch (newMinTick_) { case (?v) minTick := v;        case null {} };
    switch (newMaxTick_) { case (?v) maxTick := v;        case null {} };
  };

  // ------------------------------------------------------------------
  // AUTOMATION: run checkAndStake every 24 hours
  // ------------------------------------------------------------------

  // This sets up a recurring timer that calls checkAndStake() every 24 hours.
  ignore Timer.recurringTimer(#seconds(24 * 60 * 60), checkAndStake);
}
