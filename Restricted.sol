// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

// Imported code license: MIT
import {Ownable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/* 
 * An extension of OpenZeppelin's Ownable contract that manages access by enforcing an account banlist via a modifier.
 */
abstract contract Restricted is Ownable {

    mapping(address => bool isBanned) private _banlist;

    error NonZeroAddressRequired();
    error UnauthorizedAccessRequest(address account);

    event AccountBanned(address indexed account);
    event AccountReinstated(address indexed account);
    
    constructor(address initialOwner) Ownable(initialOwner) {}

    function banAccount(address account) public virtual onlyOwner {
        _banlist[_requireNonZeroAddress(account)] = true;
        emit AccountBanned(account);
    }

    function reinstateAccount(address account) public virtual onlyOwner {
        _banlist[_requireNonZeroAddress(account)] = false;
        emit AccountReinstated(account);
    }

    modifier onlyAllowed() {
        address sender = _msgSender();
        if (isBanned(sender)) revert UnauthorizedAccessRequest(sender);
        _;
    }

    function isBanned(address account) public view virtual returns (bool) {
        return _banlist[_requireNonZeroAddress(account)];
    }

    function _requireNonZeroAddress(address account) internal virtual pure returns (address) {
        if (account == address(0)) revert NonZeroAddressRequired();
        return account;
    }
}