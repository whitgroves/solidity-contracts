// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {InputValidated} from "https://github.com/whitgroves/solidity-contracts/blob/main/InputValidated.sol";

// Imported code license: MIT
import {Ownable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/* 
 * An extension of OpenZeppelin's Ownable contract that manages access by enforcing an account banlist via a modifier.
 */
abstract contract Restricted is Ownable, InputValidated {

    mapping(address => bool isBanned) private _banlist;

    event AccountBanned(address indexed account);
    event AccountReinstated(address indexed account);

    modifier onlyAllowed() {
        _checkAllowed();
        _;
    }
    
    constructor(address initialOwner) Ownable(initialOwner) {}

    function banAccount(address account) public virtual nonZeroAddress(account) onlyOwner {
        if (account == owner()) revert("The owner cannot be banned.");
        _banlist[account] = true;
        emit AccountBanned(account);
    }

    function reinstateAccount(address account) public virtual nonZeroAddress(account) onlyOwner {
        _banlist[account] = false;
        emit AccountReinstated(account);
    }

    function isBanned(address account) public virtual view returns (bool) {
        return _banlist[account];
    }

    // Override to redefine how the onlyAllowed modifier works in your subclass.
    function _checkAllowed() internal virtual view {
        if (isBanned(_msgSender())) revert UnauthorizedAccessRequest(_msgSender());
    }
}