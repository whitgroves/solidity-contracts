// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

/* Provides basic input validation for subclassed contracts. */
abstract contract InputValidated {

    error NonZeroAddressRequired();

    modifier nonZeroAddress(address address_) {
        _requireNonZeroAddress(address_);
        _;
    }

    // Checks that `address_` is not the zero address, then returns it.
    function _requireNonZeroAddress(address address_) internal virtual pure returns (address) {
        if (address_ == address(0)) revert NonZeroAddressRequired();
        return address_;
    }

}