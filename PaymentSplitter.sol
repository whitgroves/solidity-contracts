// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlled} from "./AccessControlled.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

// A contract that can hold and redistribute ERC20 tokens to enrolled addresses according to a preset payscale.
abstract contract PaymentSplitter is AccessControlled {

    address[] private _payees;
    uint private _totalPayscale;
    mapping(address => bool) private _enrolled;
    mapping(address => uint) private _payscale;
    mapping(address => uint) private _totalAllocated;
    mapping(address => mapping(address => uint)) private _pendingWithdrawals;
    
    event PayeeEnrolled(address indexed payee);
    event PayrollRun(address indexed currency, uint totalPayout);

    constructor(address initialOwner) AccessControlled(initialOwner) {}

    function enroll(address payee, uint payscale_) external virtual {
        if (isEnrolled(payee)) revert("Payee is already enrolled. Call update() instead.");
        _enrolled[payee] = true;
        _payees.push(payee);
        update(payee, payscale_);
        emit PayeeEnrolled(payee);
    }

    function remove(address payee) external virtual {
        update(payee, 0);
    }

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
        return IERC20(currency).transfer(to, _unallocated(currency));
    }

    function update(address payee, uint payscale_) public virtual nonZeroAddress(payee) whenNotPaused onlyDelegate {
        if (!isEnrolled(payee)) revert("Payee is not enrolled. Call enroll() first.");
        _totalPayscale -= payscaleOf(payee);
        _payscale[payee] = payscale_;
        _totalPayscale += payscale_;
    }

    function reallocate(address currency) public virtual whenNotPaused onlyDelegate returns (uint) {
        uint unallocated_ = _unallocated(currency);
        if (unallocated_ == 0) revert("No unallocated funds in selected currency.");
        uint totalPayout_ = 0;
        for (uint i = 0; i < _payees.length; i++) {
            address payee_ = _payees[i];
            uint payscale_ = _payscale[payee_];
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
        return _enrolled[payee];
    }

    function payscaleOf(address payee) public virtual view onlyDelegate returns (uint) {
        return _payscale[payee];
    }

    function totalPayscale() public virtual view returns (uint) {
        return _totalPayscale;
    }

    function totalAllocated(address currency) public virtual view nonZeroAddress(currency) returns (uint) {
        return _totalAllocated[currency];
    }

    function pendingWithdrawals(address payee, address currency) public virtual view 
        nonZeroAddress(payee) nonZeroAddress(currency) returns (uint) 
    {
        return _pendingWithdrawals[payee][currency];
    }

    function _unallocated(address currency) internal virtual returns (uint) {
        return (IERC20(currency).balanceOf(address(this)) - totalAllocated(currency));
    }

}