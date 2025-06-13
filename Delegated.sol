// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {InputValidated} from "https://github.com/whitgroves/solidity-contracts/blob/main/InputValidated.sol";

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

    modifier onlyDelegate() {
        _checkDelegate();
        _;
    }

    // @dev By default, the message sender is added as a delegate on construction.
    //      If this isn't desired, call renounceDelegation(_msgSender()) in the subclass constructor.
    constructor(address initialOwner) Ownable(initialOwner) {
        addDelegate(_requireNonZeroAddress(_msgSender()));
    }

    function addDelegate(address delegate) public virtual nonZeroAddress(delegate) onlyOwner {
        _delegates[delegate] = true;
        emit DelegateAdded(delegate);
    }

    function removeDelegate(address delegate) public virtual nonZeroAddress(delegate) onlyOwner {
        _delegates[delegate] = false;
        emit DelegateRemoved(delegate);
    }

    function renounceDelegation() public virtual onlyDelegate {
        removeDelegate(_msgSender());
    }

    function isDelegate(address delegate) public virtual view returns (bool) {
        return _delegates[delegate] || (delegate == owner());
    }

    // Override to redefine how the onlyDelegate modifier works in your subclass.
    function _checkDelegate() internal virtual view {
        if (!isDelegate(_msgSender())) revert UnauthorizedAccessRequest(_msgSender());
    }

}