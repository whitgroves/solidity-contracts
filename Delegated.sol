// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {InputValidated} from "./InputValidated.sol";
import {ERC173} from "./ERC173.sol";

/* 
 * An extension of OpenZeppelin's Ownable contract to allow for delegated calls to contract functions.
 * In effect, this is a lightweight version of AccessControl that makes the onlyDelegates modifier available
 * to inherited contracts.
 */
abstract contract Delegated is ERC173, InputValidated {

    mapping(address => bool isActive) internal _delegates;

    event DelegateAdded(address indexed delegate);
    event DelegateRemoved(address indexed delegate);

    modifier onlyDelegate() virtual {
        _checkDelegate();
        _;
    }

    // @dev By default, the message sender is added as a delegate on construction.
    //      If this isn't desired, call renounceDelegation(msg.sender) in the subclass constructor.
    constructor(address initialOwner) ERC173(initialOwner) {
        if (msg.sender != initialOwner) addDelegate(msg.sender);
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

    // Returns whether or not `delegate` is a valid delegate or the owner. Override for more complex requirements.
    function isDelegate(address delegate) public virtual view returns (bool) {
        return _delegates[delegate] || (delegate == owner());
    }

    // Internal check for delegate status. Override to redefine how the onlyDelegate modifier works in your subclass.
    function _checkDelegate() internal virtual view {
        require(isDelegate(msg.sender), "Caller must be a delegate or the owner.");
    }

}