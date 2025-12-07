// src/grave_auto_staker/icrc_types.mo

import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";

module {

  // ----------------------
  // ICRC-1 Types
  // ----------------------

  public type Account = {
    owner : Principal;
    subaccount : ?Blob;
  };

  public type TransferArgs = {
    from_subaccount : ?Blob;
    to : Account;
    amount : Nat;
    fee : ?Nat;
    memo : ?Blob;
    created_at_time : ?Nat;
  };

  public type TransferResult = {
    #Ok : Nat;
    #Err : {
      #BadFee : { expected_fee : Nat };
      #InsufficientFunds : { balance : Nat };
      #TxTooOld : { allowed_window_nanos : Nat };
      #TxTooLarge : {};
      #TxCreatedInFuture : {};
    };
  };

  public type ICRC1 = actor {
    icrc1_transfer : shared TransferArgs -> async TransferResult;
    icrc1_balance_of : shared Account -> async Nat;
  };


  // ----------------------
  // ICRC-2 Types
  // ----------------------

  public type ApproveArgs = {
    from_subaccount : ?Blob;
    spender : Account;
    amount : Nat;
    expected_allowance : ?Nat;
    expires_at : ?Nat;
    fee : ?Nat;
    memo : ?Blob;
    created_at_time : ?Nat;
  };

  public type ApproveResult = {
    #Ok : Nat;
    #Err : {
      #InsufficientFunds : { balance : Nat };
      #Expired : {};
      #AllowanceChanged : { current_allowance : Nat };
      #GenericError : { message : Text; error_code : Nat };
    };
  };

  public type ICRC2 = actor {
    icrc2_approve : shared ApproveArgs -> async ApproveResult;
  };
}


