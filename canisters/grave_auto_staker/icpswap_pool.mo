// src/grave_auto_staker/icpswap_pool.mo

import Nat "mo:base/Nat";
import Principal "mo:base/Principal";

module {

  // -----------------------------
  // Deposit
  // -----------------------------
  public type DepositArgs = {
    fee : Nat;
    token : Text;
    amount : Nat;
  };

  public type DepositResult = {
    #ok : Nat;
    #err : {
      #CommonError;
      #InternalError : Text;
      #UnsupportedToken : Text;
      #InsufficientFunds;
    };
  };

  // -----------------------------
  // DepositFrom
  // -----------------------------
  public type DepositFromArgs = {
    fee : Nat;
    token : Text;
    amount : Nat;
  };

  public type DepositFromResult = {
    #ok : Nat;
    #err : {
      #CommonError;
      #InternalError : Text;
      #UnsupportedToken : Text;
      #InsufficientFunds;
    };
  };

  // -----------------------------
  // Mint LP
  // -----------------------------
  public type MintArgs = {
    fee : Nat;
    tickUpper : Int;
    token0 : Text;
    token1 : Text;
    amount0Desired : Text;
    amount1Desired : Text;
    tickLower : Int;
  };

  public type MintResult = {
    // Usually this is the positionId / tokenId of the LP position
    #ok : Nat;
    #err : {
      #CommonError;
      #InternalError : Text;
      #UnsupportedToken : Text;
      #InsufficientFunds;
    };
  };

  // -----------------------------
  // Swap
  // -----------------------------
  public type SwapArgs = {
    amountIn : Text;
    zeroForOne : Bool;
    amountOutMinimum : Text;
  };

  public type SwapResult = {
    #ok : Nat;
    #err : {
      #CommonError;
      #InternalError : Text;
    };
  };

  // -----------------------------
  // User Internal Pool Balances
  // -----------------------------
  public type UnusedBalance = {
    balance0 : Nat;
    balance1 : Nat;
  };

  public type UserUnusedBalanceResult = {
    #ok : UnusedBalance;
    #err : {
      #CommonError;
      #InternalError : Text;
    };
  };

  // -----------------------------
  // Metadata (current tick, tokens, fee, etc.)
  // -----------------------------
  public type MetadataOk = {
    fee : Nat;
    key : Text;
    sqrtPriceX96 : Nat;
    tick : Int;
    liquidity : Nat;
    token0 : { address : Text; standard : Text };
    token1 : { address : Text; standard : Text };
    maxLiquidityPerTick : Nat;
    nextPositionId : Nat;
  };

  public type MetadataErr = {
    #CommonError;
    #InternalError : Text;
    #UnsupportedToken : Text;
    #InsufficientFunds;
  };

  public type MetadataResult = {
    #ok : MetadataOk;
    #err : MetadataErr;
  };

  // -----------------------------
  // Transfer LP Position (NFT-like)
  // -----------------------------
  public type TransferPositionArgs = {
    positionId : Nat;    // LP position ID returned by mint()
    to : Principal;      // recipient owner principal
  };

  public type TransferPositionResult = {
    #ok : Nat;
    #err : {
      #CommonError;
      #InternalError : Text;
      #UnsupportedToken : Text;
      #InsufficientFunds;
    };
  };

  // -----------------------------
  // COMPLETE ICPSwap Pool Interface
  // -----------------------------
  public type SwapPool = actor {
    deposit : shared DepositArgs -> async DepositResult;
    depositFrom : shared DepositFromArgs -> async DepositFromResult;
    mint : shared MintArgs -> async MintResult;
    swap : shared SwapArgs -> async SwapResult;
    getUserUnusedBalance : shared Principal -> async UserUnusedBalanceResult;
    metadata : shared () -> async MetadataResult;

    // New: move LP position ownership
    transferPosition : shared TransferPositionArgs -> async TransferPositionResult;
  };
}