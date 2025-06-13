// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

/* Provides basic input validation and errors for subclassed contracts. */
abstract contract InputValidated {

    error UnauthorizedAccessRequest(address sender);
    error NonZeroAddressRequired();

    modifier nonZeroAddress(address address_) {
        _requireNonZeroAddress(address_);
        _;
    }

    // Makes non-zero validation available for addresses in the constructor or returned via function call.
    function _requireNonZeroAddress(address address_) internal virtual pure returns (address) {
        if (address_ == address(0)) revert NonZeroAddressRequired();
        return address_;
    }

}