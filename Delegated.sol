// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {InputValidated} from "./InputValidated.sol";

// Imported code license: MIT
import {Ownable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/* 
 * An extension of OpenZeppelin's Ownable contract to allow for delegated calls to contract functions.
 * In effect, this is a lightweight version of AccessControl that makes the onlyDelegates modifier available
 * to inherited contracts.
 */
abstract contract Delegated is Ownable, InputValidated {

    mapping(address => bool isActive) private _delegates;

    event DelegateAdded(address indexed delegate);
    event DelegateRemoved(address indexed delegate);

    modifier onlyDelegate() virtual {
        _checkDelegate();
        _;
    }

    // @dev By default, the message sender is added as a delegate on construction.
    //      If this isn't desired, call renounceDelegation(_msgSender()) in the subclass constructor.
    constructor(address initialOwner) Ownable(initialOwner) {
        if (_msgSender() != initialOwner) addDelegate(_msgSender());
    }

    // Designates `delegate` as a valid delegate. Must be a non-zero address.
    function addDelegate(address delegate) public virtual nonZeroAddress(delegate) onlyOwner {
        _delegates[delegate] = true;
        emit DelegateAdded(delegate);
    }

    // Removes the delegate status of `delegate`. Must be a non-zero address.
    function removeDelegate(address delegate) public virtual nonZeroAddress(delegate) onlyOwner {
        _delegates[delegate] = false;
        emit DelegateRemoved(delegate);
    }

    // Allows a delegate to renounce their own status.
    function renounceDelegation() public virtual onlyDelegate {
        removeDelegate(_msgSender());
    }

    // Returns whether or not `delegate` is a valid delegate or the owner. Override for more complex requirements.
    function isDelegate(address delegate) public virtual view returns (bool) {
        return _delegates[delegate] || (delegate == owner());
    }

    // Internal check for delegate status. Override to redefine how the onlyDelegate modifier works in your subclass.
    function _checkDelegate() internal virtual view {
        if (!isDelegate(_msgSender())) revert UnauthorizedAccessRequest(_msgSender());
    }

}