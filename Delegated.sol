// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/* 
 * An extension of OpenZeppelin's Ownable contract to allow for delegated calls to contract functions.
 * In effect, this is a lightweight version of AccessControl that makes the onlyDelegates modifier available
 * to inherited contracts.
 */
contract Delegated is Ownable {

    mapping(address delegate => bool isActive) private _delegates;

    error DelegatedUnauthorizedAccount(address account);
    error DelegatedInvalidDelegate(address delegate);

    event DelegateAdded(address indexed delegate);
    event DelegateRemoved(address indexed delegate);

    /* @dev Initializes the contract according to Ownable then sets the owner and msg.sender as delegates. */
    constructor(address initialOwner) Ownable(initialOwner) {
        addDelegate(initialOwner);
        addDelegate(_msgSender());
    }

    function addDelegate(address delegate) public virtual onlyOwner {
        if (delegate == address(0)) revert DelegatedInvalidDelegate(delegate);
        _delegates[delegate] = true;
        emit DelegateAdded(delegate);   
    }

    function removeDelegate(address delegate) public virtual onlyOwner {
        if (delegate == address(0)) revert DelegatedInvalidDelegate(delegate);
        if (delegate == owner()) revert("Owner is always delegated");
        _delegates[delegate] = false;
        emit DelegateRemoved(delegate);
    }

    modifier onlyDelegate() {
        _checkDelegate();
        _;
    }

    function isDelegate(address delegate) public view virtual returns (bool) {
        return _delegates[delegate];
    }

    function _checkDelegate() internal view virtual {
        if (!isDelegate(_msgSender())) revert DelegatedUnauthorizedAccount(_msgSender());
    }

    function renounceDelegation() public virtual onlyDelegate {
        removeDelegate(_msgSender());
    }

}