// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {Delegated} from "./Delegated.sol";

/*
 * An extension of Delgated that allows for time-based delegation. Delgates are allowed to add other delegates to the
 * contract on a temporary basis, subject to max allotted days set by the owner. The owner is always exempt from this
 * restriction.
 * 
 * "Non-expiring" delegates added by the owner have an expiry of type(uint).max days, which is basically until 
 * the end of time, assuming that it does.
 */
abstract contract TimeDelegated is Delegated {
    
    mapping(address => uint) private _expiry;
    uint private _maxExpiryDays;

    constructor(address initialOwner, uint maxExpiryDays_) Delegated(initialOwner) {
        setMaxExpiryDays(maxExpiryDays_);
    }

    // Returns the number of days remaining on `delegate`'s delegation, with 0 meaning a same-day expiry.
    // If they aren't a delegate, the function will revert due to an overflow, which is cheaper than catching the error.
    function daysTillExpiry(address delegate) external virtual view returns (uint) {
        if (delegate == owner()) return type(uint).max; // owner is technically not a delegate, but functionally is.
        return (_expiry[delegate] - block.timestamp) / 1 days;
    }

    function maxExpiryDays() public virtual view returns (uint) {
        return _maxExpiryDays;
    }

    // Sets the max number of days a delegate can add another delegate to the contract.
    function setMaxExpiryDays(uint maxExpiryDays_) public virtual onlyOwner {
        _maxExpiryDays = maxExpiryDays_;
    }

    // Overload of Delegated.addDelegate() that sets delegation for a specified number of days.
    function addDelegate(address delegate, uint expiryDays) public virtual nonZeroAddress(delegate) onlyDelegate {
        if (expiryDays > maxExpiryDays() && _msgSender() != owner()) 
            revert("Delegates cannot add other delegates beyond time limit set by owner.");
        _expiry[delegate] = block.timestamp + (expiryDays * 1 days);
        emit DelegateAdded(delegate);
    }

    // Override of Delegated.addDelegate() that allows delegation for a virtually unlimited amount of time.
    function addDelegate(address delegate) public virtual override nonZeroAddress(delegate) onlyOwner {
        _expiry[delegate] = type(uint).max;
        emit DelegateAdded(delegate);
    }

    // Override of Delegated.removeDelegate() to reset expiry before removing delegation.
    function removeDelegate(address delegate) public virtual override onlyOwner {
        _expiry[delegate] = 0;
        emit DelegateRemoved(delegate);
    }

    // Override of Delegated.isDelegate() that checks against expiry date instead of the delegates map.
    function isDelegate(address delegate) public virtual override view returns (bool) {
        return (delegate == owner() || block.timestamp < _expiry[delegate]);
    }

}