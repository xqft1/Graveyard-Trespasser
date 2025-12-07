// File: main.mo
// Updated ICRC-1 and ICRC-2 implementations for ICPswap & Kongswap compatibility.

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import ICRC1 "../icrc1/ICRC1";

persistent actor GraveToken {

  // NOTE: initial values are placeholders; real value is set in postupgrade
  stable var canisterPrincipal : Principal = Principal.fromText("w5t77-riaaa-aaaaj-a2mda-cai");
  stable var controllerPrincipal : Principal = Principal.fromText("sjbyb-bxxm4-q4vy6-5vtwt-qux3n-6mkhb-6a7ht-xodtd-do5hv-n7f3w-wqe");
  stable var icpLedgerId : Text = "ryjl3-tyaaa-aaaaa-aaaba-cai";
  stable var poolPrincipal : Principal = Principal.fromText("6n6dj-bqaaa-aaaar-qbzbq-cai");
  stable var reservePrincipal : Principal = Principal.fromText("i26cz-ju75q-3eg6u-ugw3b-h3x26-nrfhg-4wq5e-4pyzc-ctk36-2wumx-bqe");

  // LP operator wallet principal (your wallet)
  stable var lpRecipientPrincipal : Principal = let lpRecipientPrincipal : Principal = Principal.fromText(
    "nfmvu-baaaa-aaaab-acz3a-cai"
  );

  stable var tokenDecimals : Nat8 = 8;
  stable var tokenName : Text = "Graveyard Trespasser";
  stable var tokenSymbol : Text = "GRAVE";

  stable var totalSupply : Nat = 0;
  stable var logo : ?Text = null;
  stable var dailyMintAmount : Nat = 500_000_000_000;
  stable var totalICPContributed : Nat = 0;
  stable var lastDistributionTime : Time.Time = 0;

  public type Account = ICRC1.Account;

  // Persistent snapshots used during preupgrade/postupgrade
  stable var balances : [(Account, Nat)] = [];
  stable var contributions : [(Principal, Nat)] = [];
  stable var vestings : [(Principal, Nat)] = [];
  stable var vestingStarts : [(Principal, Time.Time)] = [];
  stable var currentCycleContributors : [Principal] = [];
  stable var distributionIndex : Nat = 0;
  stable var txIndex : Nat = 0;

  stable var DAY : Int = 86_400_000_000_000;
  stable var VESTING_PERIOD : Int = 30 * 86_400_000_000_000;
  stable var MIN_CONTRIB : Nat = 33_300_000;   // 0.333 ICP
  stable var MAX_USERS_PER_DAY : Nat = 5000;
  stable var FEE : Nat = 10_000;

  stable var lastSetLogoCaller : ?Principal = null;
  stable var mintingAccount : Account = { owner = canisterPrincipal; subaccount = null };

  // Internal routing safety fee (non-stable; does not affect stable layout)
  let ROUTING_FEE : Nat = 11_000;

  // Dedicated LP account-id for poolPrincipal with subaccount = 1
  // (will be overridden to correct value in postupgrade)
  stable var poolAccount : Blob = Blob.fromArray([
    0x5d,0x16,0x08,0xaf,0x88,0xce,0xb0,0xe3,
    0xa5,0xb3,0xa7,0x46,0xda,0x88,0xf4,0x83,
    0x15,0x6f,0x99,0x08,0x7d,0x89,0x2e,0xfb,
    0xf2,0xd0,0x7c,0xe1,0x26,0x57,0xa5,0x98
  ]);

  // ---------------------------------------------------------------------------
  // LOCAL TOKEN ERROR / RESULT TYPES
  // ---------------------------------------------------------------------------

  public type TransferErr = {
    #BadFee : { expected_fee : Nat };
    #BadBurn : { min_burn_amount : Nat };
    #InsufficientFunds : { balance : Nat };
    #TooOld;
    #CreatedInFuture : { ledger_time : Nat64 };
    #Duplicate : { duplicate_of : Nat };
    #TemporarilyUnavailable;
    #GenericError : { error_code : Nat; message : Text };
  };

  public type TransferResult = {
    #Ok : Nat;
    #Err : TransferErr;
  };

  // Frontend-facing result types (match JS IDL: variant { ok; err })
  public type SacrificeResult = { #ok : Nat; #err : Text };
  public type ClaimResult = { #ok : Nat; #err : Text };

  func accountId(p : Principal) : Blob { Principal.toLedgerAccount(p, null) };

  func accountEqual(a1 : Account, a2 : Account) : Bool {
    a1.owner == a2.owner and Option.equal<Blob>(a1.subaccount, a2.subaccount, Blob.equal)
  };

  func accountHash(a : Account) : Hash.Hash {
    let sub = switch (a.subaccount) {
      case (?s) s;
      case null Blob.fromArray(Array.tabulate<Nat8>(32, func (_) = 0));
    };
    Principal.hash(a.owner) ^ Blob.hash(sub)
  };

  // Allowances
  type AllowKey = { owner : Account; spender : Account };

  func allowEqual(k1 : AllowKey, k2 : AllowKey) : Bool {
    accountEqual(k1.owner, k2.owner) and accountEqual(k1.spender, k2.spender)
  };

  func allowHash(k : AllowKey) : Hash.Hash {
    accountHash(k.owner) ^ accountHash(k.spender)
  };

  // *** RUNTIME STATE (non-stable, must be transient for Motoko 0.29) ***
  transient var allowanceMap = HashMap.HashMap<AllowKey, Nat>(100, allowEqual, allowHash);
  transient var balanceMap = HashMap.HashMap<Account, Nat>(10, accountEqual, accountHash);
  transient var todayContrib = HashMap.HashMap<Principal, Nat>(10, Principal.equal, Principal.hash);
  transient var vestingMap = HashMap.HashMap<Principal, Nat>(100, Principal.equal, Principal.hash);
  transient var vestingStartMap = HashMap.HashMap<Principal, Time.Time>(100, Principal.equal, Principal.hash);
  transient var todayUsers : [Principal] = [];
  transient var processedIndex : Nat = 0;

  // ---------------------------------------------------------------------------
  // ICP LEDGER INTERFACE (ICRC-1 + ICRC-2) — MATCHES REAL CANDID
  // ---------------------------------------------------------------------------

  // ICRC-1 transfer error (full set)
  type LedgerTransferError = {
    #BadFee : { expected_fee : Nat64 };
    #BadBurn : { min_burn_amount : Nat64 };
    #InsufficientFunds : { balance : Nat64 };
    #TooOld;
    #CreatedInFuture : { ledger_time : Nat64 };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : Nat64 };
    #GenericError : { error_code : Nat64; message : Text };
  };

  type LedgerTransferResult = {
    #Ok : Nat64;
    #Err : LedgerTransferError;
  };

  // ICRC-2 transfer_from error (full-ish set, including InsufficientAllowance)
  type LedgerIcrc2TransferFromError = {
    #BadFee : { expected_fee : Nat };
    #BadBurn : { min_burn_amount : Nat };
    #InsufficientFunds : { balance : Nat };
    #TooOld;
    #CreatedInFuture : { ledger_time : Nat64 };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : Nat };
    #GenericError : { error_code : Nat; message : Text };
    #Expired : { ledger_time : Nat64 };
    #InsufficientAllowance : { allowance : Nat };
  };

  type LedgerIcrc2TransferFromResult = {
    #Ok : Nat;
    #Err : LedgerIcrc2TransferFromError;
  };

  // ICP Ledger interface - transient
  transient let icpLedger = actor (icpLedgerId) : actor {
    // Classic ICP transfer (ICRC-1-style)
    transfer : shared (args : {
      to : Blob;
      fee : { e8s : Nat64 };
      amount : { e8s : Nat64 };
      memo : Nat64;
      from_subaccount : ?Blob;
      created_at_time : ?Nat64;
    }) -> async LedgerTransferResult;

    // ICRC-2 transfer_from: Nat amounts, opt vec Nat8 subaccounts/memo
    icrc2_transfer_from : shared (args : {
      spender_subaccount : ?[Nat8];
      from : { owner : Principal; subaccount : ?[Nat8] };
      to : { owner : Principal; subaccount : ?[Nat8] };
      amount : Nat;
      fee : ?Nat;
      memo : ?[Nat8];
      created_at_time : ?Nat64;
    }) -> async LedgerIcrc2TransferFromResult;
  };

  // ---------------------------------------------------
  // INIT + UPGRADE LIFECYCLE (persistent: no init)
  // ---------------------------------------------------

  system func preupgrade() {
    balances := Iter.toArray(balanceMap.entries());
    contributions := Iter.toArray(todayContrib.entries());
    vestings := Iter.toArray(vestingMap.entries());
    vestingStarts := Iter.toArray(vestingStartMap.entries());
    currentCycleContributors := todayUsers;
    distributionIndex := processedIndex;
  };

  system func postupgrade() {

    // ensure canister principal + minting account always correct
    canisterPrincipal := Principal.fromActor(GraveToken);
    mintingAccount := { owner = canisterPrincipal; subaccount = null };

    balanceMap := HashMap.fromIter(Iter.fromArray(balances), 10, accountEqual, accountHash);
    todayContrib := HashMap.fromIter(Iter.fromArray(contributions), 10, Principal.equal, Principal.hash);
    vestingMap := HashMap.fromIter(Iter.fromArray(vestings), 100, Principal.equal, Principal.hash);
    vestingStartMap := HashMap.fromIter(Iter.fromArray(vestingStarts), 100, Principal.equal, Principal.hash);

    todayUsers := currentCycleContributors;
    processedIndex := distributionIndex;

    if (lastDistributionTime == 0) {
      lastDistributionTime := Time.now();
    };

    // ✅ FORCE UPDATE YOUR RESERVE PRINCIPAL HERE
    reservePrincipal := Principal.fromText("i26cz-ju75q-3eg6u-ugw3b-h3x26-nrfhg-4wq5e-4pyzc-ctk36-2wumx-bqe");

    // 🔥 FORCE-SET THE POOL PRINCIPAL ON EVERY UPGRADE (kept, but no longer used for routing)
    poolPrincipal := Principal.fromText("6n6dj-bqaaa-aaaar-qbzbq-cai");

    // NEW — force-update LP recipient principal every upgrade
    lpRecipientPrincipal := Principal.fromText("nfmvu-baaaa-aaaab-acz3a-cai");

    // Recompute the LP account-id for poolPrincipal, subaccount = 1
    let sub1 : Blob = Blob.fromArray(
      Array.tabulate<Nat8>(32, func (i : Nat) : Nat8 {
        if (i == 31) 1 else 0
      })
    );
    poolAccount := Principal.toLedgerAccount(poolPrincipal, ?sub1);
  };

  // ---------------------------------------------------
  // HEARTBEAT MINTING / VESTING
  // ---------------------------------------------------

  system func heartbeat() : async () {
    let now = Time.now();
    if (now < lastDistributionTime + DAY) return;

    if (totalICPContributed > 0 and processedIndex < todayUsers.size()) {
      let batch = 200;
      let end = Nat.min(processedIndex + batch, todayUsers.size());
      var i = processedIndex;

      while (i < end) {
        let user = todayUsers[i];
        let contrib = switch (todayContrib.get(user)) { case (?c) c; case null 0 };

        if (contrib > 0) {
          let share = contrib * dailyMintAmount / totalICPContributed;

          if (share > 0) {
            let current = switch (vestingMap.get(user)) { case (?v) v; case null 0 };
            let oldStart = switch (vestingStartMap.get(user)) { case (?t) t; case null now };

            vestingMap.put(user, current + share);
            vestingStartMap.put(user, Int.min(oldStart, now));
          };
        };

        i += 1;
      };

      processedIndex := end;
      return;
    };

    totalSupply += dailyMintAmount;

    if (totalICPContributed > 0) {
      let ca : Account = { owner = canisterPrincipal; subaccount = null };
      let bal = switch (balanceMap.get(ca)) { case (?b) b; case null 0 };
      balanceMap.put(ca, bal + dailyMintAmount);
    } else {
      let ra : Account = { owner = reservePrincipal; subaccount = null };
      let bal = switch (balanceMap.get(ra)) { case (?b) b; case null 0 };
      balanceMap.put(ra, bal + dailyMintAmount);
    };

    dailyMintAmount := dailyMintAmount * 99 / 100;
    processedIndex := 0;
    todayUsers := [];
    totalICPContributed := 0;
    todayContrib := HashMap.HashMap<Principal, Nat>(10, Principal.equal, Principal.hash);
    lastDistributionTime := now;
  };

  // ---------------------------------------------------
  // ICRC-1
  // ---------------------------------------------------

  public query func icrc1_name() : async Text { tokenName };
  public query func icrc1_symbol() : async Text { tokenSymbol };
  public query func icrc1_decimals() : async Nat8 { tokenDecimals };
  public query func icrc1_total_supply() : async Nat { totalSupply };
  public query func icrc1_fee() : async Nat { 0 };

  public query func icrc1_minting_account() : async ?Account { ?mintingAccount };

  public query func icrc1_metadata() : async [ICRC1.Metadata] {
    var base : [ICRC1.Metadata] = [
      ("icrc1:name", #Text(tokenName)),
      ("icrc1:symbol", #Text(tokenSymbol)),
      ("icrc1:decimals", #Nat(Nat8.toNat(tokenDecimals))),
      ("icrc1:fee", #Nat(0)),
      ("icrc1:minting_account", #Text(Principal.toText(mintingAccount.owner))),
    ];

    switch (logo) {
      case (?u) {
        base := Array.append(base, [("icrc1:logo", #Text(u))]);
      };
      case null {};
    };

    base
  };

  public query func icrc1_supported_standards() : async [{ name : Text; url : Text }] {
    [
      { name = "ICRC-1"; url = "https://github.com/dfinity/ICRC-1" },
      { name = "ICRC-2"; url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-2" }
    ]
  };

  public query func icrc1_balance_of(account : Account) : async Nat {
    switch (balanceMap.get(account)) { case (?b) b; case null 0 }
  };

  public shared(msg) func icrc1_transfer(
    args : {
      from_subaccount : ?Blob;
      to : Account;
      amount : Nat;
      fee : ?Nat;
      memo : ?Blob;
      created_at_time : ?Nat64;
    }
  ) : async TransferResult {
    let fee = switch (args.fee) { case (?f) f; case null 0 };
    if (fee != 0) return #Err(#BadFee { expected_fee = 0 });

    let from : Account = { owner = msg.caller; subaccount = args.from_subaccount };
    let bal = switch (balanceMap.get(from)) { case (?b) b; case null 0 };
    if (bal < args.amount) return #Err(#InsufficientFunds { balance = bal });

    balanceMap.put(from, bal - args.amount);
    let toBal = switch (balanceMap.get(args.to)) { case (?b) b; case null 0 };
    balanceMap.put(args.to, toBal + args.amount);

    txIndex += 1;
    #Ok(txIndex - 1)
  };

  // ---------------------------------------------------
  // ICRC-2 (local GRAVE token)
  // ---------------------------------------------------

  public type ICRC2ApproveArgs = {
    from_subaccount : ?Blob;
    spender : Account;
    amount : Nat;
    expected_allowance : ?Nat;
    expires_at : ?Nat64;
    fee : ?Nat;
    memo : ?Blob;
    created_at_time : ?Nat64;
  };

  public type ICRC2TransferFromArgs = {
    spender_subaccount : ?Blob;
    from : Account;
    to : Account;
    amount : Nat;
    fee : ?Nat;
    memo : ?Blob;
    created_at_time : ?Nat64;
  };

  public shared(msg) func icrc2_approve(
    args : ICRC2ApproveArgs
  ) : async Result.Result<Nat, TransferErr> {

    let ownerAcc : Account = { owner = msg.caller; subaccount = args.from_subaccount };
    let key : AllowKey = { owner = ownerAcc; spender = args.spender };

    let current = switch (allowanceMap.get(key)) { case (?v) v; case null 0 };

    // expected_allowance mismatch → return GenericError (ICPSwap expects this)
    switch (args.expected_allowance) {
      case (?exp) {
        if (exp != current) {
          return #err(#GenericError({
            error_code = 1;
            message = "Allowance changed";
          }));
        };
      };
      case null {};
    };

    // fee must be zero
    switch (args.fee) {
      case (?f) {
        if (f != 0) return #err(#BadFee { expected_fee = 0 });
      };
      case null {};
    };

    allowanceMap.put(key, args.amount);

    txIndex += 1;
    #ok(txIndex - 1)
  };

  public query func icrc2_allowance(
    args : { account : Account; spender : Account }
  ) : async { allowance : Nat; expires_at : ?Nat64 } {
    let key : AllowKey = { owner = args.account; spender = args.spender };
    let a = switch (allowanceMap.get(key)) { case (?v) v; case null 0 };
    { allowance = a; expires_at = null }
  };

  public shared(msg) func icrc2_transfer_from(
    args : ICRC2TransferFromArgs
  ) : async TransferResult {

    let fee = switch (args.fee) { case (?f) f; case null 0 };
    if (fee != 0) return #Err(#BadFee { expected_fee = 0 });

    let fromAcc = args.from;
    let toAcc = args.to;

    // If caller *is the owner*, bypass allowance
    if (msg.caller == fromAcc.owner) {
      let bal = switch (balanceMap.get(fromAcc)) { case (?b) b; case null 0 };
      if (bal < args.amount) return #Err(#InsufficientFunds { balance = bal });

      balanceMap.put(fromAcc, bal - args.amount);
      let toBal = switch (balanceMap.get(toAcc)) { case (?b) b; case null 0 };
      balanceMap.put(toAcc, toBal + args.amount);

      txIndex += 1;
      return #Ok(txIndex - 1);
    };

    // Otherwise, treat caller as spender
    let spenderAcc : Account = {
      owner = msg.caller;
      subaccount = args.spender_subaccount;
    };

    let key : AllowKey = {
      owner = fromAcc;
      spender = spenderAcc;
    };

    let allowance = switch (allowanceMap.get(key)) { case (?a) a; case null 0 };

    // Insufficient allowance → InsufficientFunds (ICRC-1 compatible)
    if (allowance < args.amount) {
      return #Err(#InsufficientFunds { balance = allowance });
    };

    // Check balance
    let bal2 = switch (balanceMap.get(fromAcc)) { case (?b) b; case null 0 };
    if (bal2 < args.amount) {
      return #Err(#InsufficientFunds { balance = bal2 });
    };

    // Deduct allowance
    allowanceMap.put(key, allowance - args.amount);

    // Transfer
    balanceMap.put(fromAcc, bal2 - args.amount);
    let toBal2 = switch (balanceMap.get(toAcc)) { case (?b) b; case null 0 };
    balanceMap.put(toAcc, toBal2 + args.amount);

    txIndex += 1;
    return #Ok(txIndex - 1);
  };

  // ---------------------------------------------------
  // CONTRIBUTIONS + VESTING (updated routing)
  // ---------------------------------------------------

  // Legacy entrypoint – hard disabled
  public shared(msg) func contributeICP(amount : Nat) : async SacrificeResult {
    return #err("This function is disabled. Please use contributeAndLockLiquidity.");
  };

  // ---------------------------------------------------------------------------
  // Contribute ICP → pull from user, 10% to reservePrincipal, 90% to your LP wallet
  // NO ICPSWAP CALLS. You manually add LP + burn it.
  // ---------------------------------------------------------------------------
  public shared(msg) func contributeAndLockLiquidity(amountE8s : Nat) : async SacrificeResult {
    let caller = msg.caller;

    if (amountE8s < 25_000_000) return #err("Min 0.25 ICP for contribution");
    if (todayUsers.size() >= MAX_USERS_PER_DAY) return #err("Daily cap reached");

    // 1. Pull ICP from user → canister (ledger charges the user FEE)
    let pull = await icpLedger.icrc2_transfer_from({
      spender_subaccount = null;
      from = { owner = caller; subaccount = null };
      to = { owner = canisterPrincipal; subaccount = null };
      amount = amountE8s;
      fee = ?FEE;
      memo = null;
      created_at_time = null;
    });

    switch (pull) {
      case (#Err(_)) return #err("ICP pull failed");
      case (#Ok(_)) {};
    };

    // 2. Ensure enough to pay routing fees (2 ledger transfers from the canister)
    if (amountE8s <= 2 * FEE) {
      return #err("Amount too small for routing fees");
    };

    let usable : Nat = amountE8s - (2 * FEE);

    // 3. Split 90% → LP wallet, 10% → reserve
    let toLp : Nat = usable * 90 / 100;
    let toReserve : Nat = usable - toLp;

    // 4. Send 10% to reservePrincipal
    if (toReserve > 0) {
      let teamSend = await icpLedger.transfer({
        to = accountId(reservePrincipal);
        amount = { e8s = Nat64.fromNat(toReserve) };
        fee = { e8s = Nat64.fromNat(FEE) };
        memo = 0;
        from_subaccount = null;
        created_at_time = null;
      });
      switch (teamSend) {
        case (#Err(_)) return #err("Reserve transfer failed");
        case (#Ok(_)) {};
      };
    };

    // 5. Send 90% to your LP operator wallet
    if (toLp > 0) {
      let lpSend = await icpLedger.transfer({
        to = accountId(lpRecipientPrincipal);
        amount = { e8s = Nat64.fromNat(toLp) };
        fee = { e8s = Nat64.fromNat(FEE) };
        memo = 0;
        from_subaccount = null;
        created_at_time = null;
      });
      switch (lpSend) {
        case (#Err(_)) return #err("LP wallet transfer failed");
        case (#Ok(_)) {};
      };
    };

    // 6. Track contribution for GRAVE reward distribution
    let prev = switch (todayContrib.get(caller)) { case (?v) v; case null 0 };
    if (prev == 0) {
      let buf = Buffer.fromArray<Principal>(todayUsers);
      buf.add(caller);
      todayUsers := Buffer.toArray(buf);
    };

    todayContrib.put(caller, prev + amountE8s);
    totalICPContributed += amountE8s;

    #ok(amountE8s)
  };

  public shared(msg) func claimVestedGrave() : async ClaimResult {
    let user = msg.caller;
    let locked = switch (vestingMap.get(user)) { case (?v) v; case null 0 };
    if (locked == 0) return #ok(0);

    let start = switch (vestingStartMap.get(user)) { case (?t) t; case null Time.now() };
    let elapsed = Time.now() - start;

    let unlocked =
      if (elapsed >= VESTING_PERIOD)
        locked
      else
        (locked * Nat64.toNat(Nat64.fromIntWrap(Int.abs(elapsed)))) /
        Nat64.toNat(Nat64.fromIntWrap(VESTING_PERIOD));

    if (unlocked == 0) return #ok(0);

    let ca : Account = { owner = canisterPrincipal; subaccount = null };
    let caBal = switch (balanceMap.get(ca)) { case (?b) b; case null 0 };
    if (caBal < unlocked) return #err("Not enough tokens");

    balanceMap.put(ca, caBal - unlocked);

    let ua : Account = { owner = user; subaccount = null };
    let uBal = switch (balanceMap.get(ua)) { case (?b) b; case null 0 };
    balanceMap.put(ua, uBal + unlocked);

    let remaining = locked - unlocked;

    if (remaining == 0) {
      vestingMap.delete(user);
      vestingStartMap.delete(user);
    } else {
      vestingMap.put(user, remaining);
      // RESET vesting start so new vesting begins from now
      vestingStartMap.put(user, Time.now());
    };

    #ok(unlocked)
  };

  // ---------------------------------------------------
  // ADMIN / VIEW
  // ---------------------------------------------------

  public query func getLogo() : async ?Text { logo };
  public query func getNextMintTime() : async Time.Time { lastDistributionTime + DAY };

  public query func getVestedAmount(p : Principal) : async Nat {
    switch (vestingMap.get(p)) { case (?v) v; case null 0 }
  };

  public query func getUnlockedAmount(p : Principal) : async Nat {
    let locked = switch (vestingMap.get(p)) { case (?v) v; case null 0 };
    if (locked == 0) return 0;
    let start = switch (vestingStartMap.get(p)) { case (?t) t; case null Time.now() };
    let elapsed = Time.now() - start;
    if (elapsed >= VESTING_PERIOD) return locked;
    (locked * Nat64.toNat(Nat64.fromIntWrap(Int.abs(elapsed)))) /
    Nat64.toNat(Nat64.fromIntWrap(VESTING_PERIOD))
  };

  public shared(msg) func setPoolPrincipal(p : Principal) : async Result.Result<(), Text> {
    // Permanently disabled in final, trustless version.
    #err("setPoolPrincipal disabled after blackhole")
  };


  public shared(msg) func setLogo(uri : Text) : async Result.Result<(), Text> {
    // Permanently disabled in final, trustless version.
    #err("setLogo disabled after blackhole")
  };

  public shared(msg) func adminMint(to : Principal, quantity : Nat) : async Result.Result<Nat, Text> {
    // Permanently disabled in final, trustless version.
    #err("adminMint disabled after blackhole")
  };

  public query func getPoolAccount() : async Blob {
    poolAccount
  };

  public query func getUserContribution(p : Principal) : async Nat {
    switch (todayContrib.get(p)) { case (?v) v; case null 0 }
  };

  public query func getTotalICPContributed() : async Nat { totalICPContributed };
}
