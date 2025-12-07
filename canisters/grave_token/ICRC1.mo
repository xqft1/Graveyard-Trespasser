// Minimal ICRC-1 type definitions for Motoko tokens.
// This file contains only types — no logic — and is intended
// for import by token canisters that implement the standard.

import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";

module {

  // -----------------------------
  // Account
  // -----------------------------
  public type Account = {
    owner : Principal;
    subaccount : ?Blob;
  };

  // -----------------------------
  // Metadata Values (canonical)
  // -----------------------------
  public type MetadataValue = {
    #Nat : Nat;
    #Int : Int;
    #Text : Text;
    #Blob : Blob;
  };

  public type Metadata = (Text, MetadataValue);

  // -----------------------------
  // Transfer arguments
  // -----------------------------
  public type TransferArgs = {
    from_subaccount : ?Blob;
    to : Account;
    amount : Nat;
    fee : ?Nat;
    memo : ?Blob;
    created_at_time : ?Nat64;
  };

  // -----------------------------
  // Transfer result
  // -----------------------------
  public type TransferResult = {
    #Ok : Nat;          // block height
    #Err : TransferError;
  };

  // -----------------------------
  // Transfer errors
  // -----------------------------
  public type TransferError = {
    #BadFee : { expected_fee : Nat };
    #BadBurn : { min_burn_amount : Nat };
    #InsufficientFunds : { balance : Nat };
    #TooOld;
    #CreatedInFuture : { ledger_time : Nat64 };
    #Duplicate : { duplicate_of : Nat };
    #TemporarilyUnavailable;
    #GenericError : { error_code : Nat; message : Text };
  };

  // -----------------------------
  // Supported Standards
  // -----------------------------
  public type Standard = {
    name : Text;
    url : Text;
  };

}
