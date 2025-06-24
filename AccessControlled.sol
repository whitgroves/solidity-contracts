// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {InputValidated} from "./InputValidated.sol";

// Imported code license: MIT
import {Ownable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import {Pausable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol";

/* 
 * An extension of Ownable and Pausable that implements both Delegated and Restricted permissions to allow inheritance
 * from all four without overriding their shared methods.
 */
abstract contract AccessControlled is Ownable, Pausable, InputValidated {

    address[] private _delegates; // non-unique list of delegates so they can be cleared on ownership transfer
    mapping(address => bool) private _isDelegate;
    mapping(address => bool) private _isBanned;

    event DelegateAdded(address indexed delegate);
    event DelegateRemoved(address indexed delegate);
    event DelegatesCleared();
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
        _isBanned[account] = true;
        emit AccountBanned(account);
        if (isDelegate(account)) removeDelegate(account);
    }

    function reinstateAccount(address account) external virtual nonZeroAddress(account) onlyOwner {
        _isBanned[account] = false;
        emit AccountReinstated(account);
    }

    function renounceDelegation() external virtual onlyDelegate {
        _removeDelegate(_msgSender());
    }

    // Public wrapper for _removeDelegate() to restrict ad-hoc removal to the current owner
    function removeDelegate(address account) public virtual nonZeroAddress(account) onlyOwner {
        _removeDelegate(account);
    }

    function addDelegate(address account) public virtual nonZeroAddress(account) onlyOwner {
        if (isBanned(account)) revert("Banned accounts cannot be delegates.");
        _isDelegate[account] = true;
        _delegates.push(account); // see _clearDelegates()
        emit DelegateAdded(account);
    }

    function isDelegate(address account) public virtual view returns (bool) {
        return _isDelegate[account] || (account == owner());
    }

    function isBanned(address account) public virtual view returns (bool) {
        return _isBanned[account];
    }

    // Wrapper to make Pausable._unpause() available to the contract owner.
    // If this access should be extended, override without the modifier and make a direct call to _unpause().
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    // Wrapper to make Pausable._pause() available to the contract delegates.
    function pause() public virtual onlyDelegate {
        _pause();
    }

    // Override to redefine how the onlyDelegate modifier works in your subclass.
    function _checkDelegate() internal virtual view {
        if (!isDelegate(_msgSender())) revert UnauthorizedAccessRequest(_msgSender());
    }

    // Override to redefine how the onlyAllowed modifier works in your subclass.
    function _checkAllowed() internal virtual view {
        if (isBanned(_msgSender())) revert UnauthorizedAccessRequest(_msgSender());
    }

    // Internal function to allow delegates to be removed programmatically without checking for ownership first
    function _removeDelegate(address account) internal virtual {
        _isDelegate[account] = false;
        emit DelegateRemoved(account);
    }

    // Internal that allows all delegates to be cleared on conditions specified by the subclass.
    function _clearDelegates() internal virtual {
        for (uint i = 0; i < _delegates.length; i++) {
            address delegate_ = _delegates[i];
            if (!_isDelegate[delegate_]) continue;
            _removeDelegate(delegate_);
        }
        delete _delegates;
    }

}