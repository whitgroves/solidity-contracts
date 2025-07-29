// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {PaymentSplitter} from "./PaymentSplitter.sol";
import {AccessControlledERC721} from "./AccessControlledERC721.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";

// An extension of AccessControlledERC721 that implements the functionality of ProfitSplitter.sol
abstract contract PaymentSplitterERC721 is AccessControlledERC721 {

    // address private immutable _membershipToken;
    address[] private _payees;
    uint private _totalBalance;
    mapping(address => uint) private _totalAllocated;
    mapping(address => mapping(address => uint)) private _pendingWithdrawals;
    mapping(address => bool) private _everPaid;

    event PayeeEnrolled(address indexed payee);
    event PayrollRun(address indexed currency, uint totalPayout);

    constructor(address initialOwner) AccessControlledERC721(initialOwner) {}

    // ProfitSplitter functions

    function withdraw(address currency) external virtual nonZeroAddress(currency) returns (uint) {
        uint withdrawal_ = pendingWithdrawals(_msgSender(), currency);
        if (withdrawal_ == 0) revert("No pending withdrawals in selected currency.");
        if (!IERC20(currency).transfer(_msgSender(), withdrawal_)) revert("Funds transfer failed.");
        _pendingWithdrawals[_msgSender()][currency] = 0;
        _totalAllocated[currency] -= withdrawal_;
        return withdrawal_;
    }

    // Allows the owner to tranfer unallocated funds in the specified currency to a different address.
    function transferUnallocated(address currency, address to) external virtual 
        nonZeroAddress(currency) nonZeroAddress(to) onlyOwner returns (bool)
    {
        return IERC20(currency).transfer(to, unallocatedFunds(currency));
    }

    function reallocate(address currency) public virtual whenNotPaused onlyDelegate returns (uint) {
        uint unallocated_ = unallocatedFunds(currency);
        if (unallocated_ == 0) revert("No unallocated funds in selected currency.");
        uint totalPayout_ = 0;
        for (uint i = 0; i < _payees.length; i++) {
            address payee_ = _payees[i];
            uint payscale_ = payscaleOf(payee_);
            if (payscale_ == 0) continue;
            uint scale_ = ((payscale_ * 1e18) / totalPayscale());
            uint payout_ = (unallocated_ * scale_) / 1e18;
            _pendingWithdrawals[payee_][currency] += payout_;
            totalPayout_ += payout_;
        }
        _totalAllocated[currency] += totalPayout_;
        emit PayrollRun(currency, totalPayout_);
        return totalPayout_;
    }

    function isEnrolled(address payee) public virtual view returns (bool) {
        return (_balanceOf(payee) > 0);
    }

    function payscaleOf(address payee) public virtual view returns (uint) {
        return _balanceOf(payee);
    }

    function totalPayscale() public virtual view returns (uint) {
        return _totalBalance;
    }

    function totalAllocated(address currency) public virtual view nonZeroAddress(currency) returns (uint) {
        return _totalAllocated[currency];
    }

    function pendingWithdrawals(address payee, address currency) public virtual view 
        nonZeroAddress(payee) nonZeroAddress(currency) returns (uint) 
    {
        return _pendingWithdrawals[payee][currency];
    }

    function unallocatedFunds(address currency) public virtual view returns (uint) {
        return (IERC20(currency).balanceOf(address(this)) - totalAllocated(currency));
    }

    // ERC721 overrides

    function mint(address to, uint tokenId) public override {
        if (!_everPaid[to]) {
            _everPaid[to] = true;
            _payees.push(to);
            emit PayeeEnrolled(to);
        }
        super.mint(to, tokenId);
        _totalBalance++;
    }

    function burn(uint tokenId) public override {
        super.burn(tokenId);
        _totalBalance--;
    }

    // The owner of the entire contract is treated like an authorized party 
    function _requireAuthorized(uint tokenId, bool ownerOnly) internal override returns (address) {
        if (!ownerOnly && _msgSender() == owner()) return _ownerOf(tokenId);
        return super._requireAuthorized(tokenId, ownerOnly);
    }
    
}