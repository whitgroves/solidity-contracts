// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {InputValidated} from "./InputValidated.sol";

// Imported code license: MIT
import {Ownable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/* 
 * An extension of Ownable that implements both Delegated and Restricted permissions to allow inheritance of both
 * without overriding their shared methods from Ownable.
 */
abstract contract AccessControlled is Ownable, InputValidated {

    mapping(address => bool isActive) private _delegates;
    mapping(address => bool isBanned) private _banlist;

    event DelegateAdded(address indexed delegate);
    event DelegateRemoved(address indexed delegate);
    event AccountBanned(address indexed account);
    event AccountReinstated(address indexed account);

    modifier onlyDelegate() virtual {
        _checkDelegate();
        _;
    }

    modifier onlyAllowed() virtual {
        _checkAllowed();
        _;
    }

    // @dev By default, the message sender is added as a delegate on construction.
    //      If this isn't desired, call renounceDelegation(_msgSender()) in the subclass constructor.
    constructor(address initialOwner) Ownable(initialOwner) {
        addDelegate(_requireNonZeroAddress(_msgSender()));
    }

    function banAccount(address account) external virtual nonZeroAddress(account) onlyDelegate {
        if (account == owner()) revert("The owner cannot be banned.");
        _banlist[account] = true;
        emit AccountBanned(account);
        if (isDelegate(account)) removeDelegate(account);
    }

    function reinstateAccount(address account) external virtual nonZeroAddress(account) onlyOwner {
        _banlist[account] = false;
        emit AccountReinstated(account);
    }

    function renounceDelegation() external virtual onlyDelegate {
        removeDelegate(_msgSender());
    }

    function removeDelegate(address account) public virtual nonZeroAddress(account) onlyOwner {
        _delegates[account] = false;
        emit DelegateRemoved(account);
    }

    function addDelegate(address account) public virtual nonZeroAddress(account) onlyOwner {
        if (isBanned(account)) revert("Banned accounts cannot be delegates.");
        _delegates[account] = true;
        emit DelegateAdded(account);
    }

    function isDelegate(address account) public virtual view returns (bool) {
        return _delegates[account] || (account == owner());
    }

    function isBanned(address account) public virtual view returns (bool) {
        return _banlist[account];
    }

    // Override to redefine how the onlyDelegate modifier works in your subclass.
    function _checkDelegate() internal virtual view {
        if (!isDelegate(_msgSender())) revert UnauthorizedAccessRequest(_msgSender());
    }

    // Override to redefine how the onlyAllowed modifier works in your subclass.
    function _checkAllowed() internal virtual view {
        if (isBanned(_msgSender())) revert UnauthorizedAccessRequest(_msgSender());
    }

}