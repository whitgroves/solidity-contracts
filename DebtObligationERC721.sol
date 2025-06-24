// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {TradeableERC721} from "./TradeableERC721.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

struct LoanTerms {
    uint maxAmount;
    uint8 termDays;
    uint8 interestRate;
}

abstract contract DebtObligationERC721 is TradeableERC721 {
    
    mapping(address => mapping(address => LoanTerms)) private _offers;
    mapping(uint => address) private _borrower;
    mapping(uint => uint) private _maturity;
    mapping(uint => uint) private _balance;
    mapping(uint => address) private _currency;
    mapping(address => mapping(address => uint)) private _allowances;
    mapping(address => bool) private _hasBadDebt;
    uint private _loanId;

    event LoanGranted(uint loanId);
    event LoanRepaid(uint loanId);
    event LoanReleased(uint loanId);
    
    constructor(address initialOwner) TradeableERC721(initialOwner) {}

    function setOffer(address currency, uint maxAmount, uint8 termDays, uint8 interestRate) external virtual onlyAllowed {
        IERC20 currency_ = IERC20(currency);
        if (currency_.totalSupply() == 0) revert("Terms must be set in a currency with a supply.");
        if (currency_.balanceOf(_msgSender()) < maxAmount) revert("Sender balance not sufficient for loan.");
        if (!currency_.approve(address(this), maxAmount)) revert("Allowance for loan not granted by token.");
        _offers[_msgSender()][currency] = LoanTerms(maxAmount, termDays, interestRate);
    }

    // Allows the sender to borrow `amount` from `lender` in `currency`. Returns the loanId for their repayments.
    // Creates an allowance on the borrower's tokens for this contract to transfer the funds at collection.
    function borrow(address lender, address currency, uint amount) external virtual onlyAllowed returns (uint) {
        LoanTerms memory terms_ = getOffer(lender, currency);
        if (terms_.maxAmount == 0) revert("Lender does not support loans in this currency.");
        if (terms_.maxAmount < amount) revert("Loan request exceeds lender's max amount.");
        uint repayment_ = (amount * (100 + terms_.interestRate)) / 100;
        _allowances[_msgSender()][currency] += repayment_;
        IERC20 currency_ = IERC20(currency);
        if (!currency_.approve(address(this), _allowances[_msgSender()][currency])) 
            revert("Allowance for repayment not granted by token.");
        if (!currency_.transferFrom(lender, _msgSender(), amount)) 
            revert("Loan rejected. Review lender balance and approvals.");
        _update(address(0), lender, _loanId++);
        _borrower[_loanId] = _msgSender();
        _maturity[_loanId] = block.timestamp + (terms_.termDays * 1 days);
        _balance[_loanId] = repayment_;
        _currency[_loanId] = currency;
        emit LoanGranted(_loanId);
        return _loanId;
    }

    // Allows the lender to collect the balance of the loan at maturity. If the borrower has less than the balance
    // available, all tokens in that denomination will be transferred. Returns whether the full debt was collected.
    function collect(uint loanId) external virtual onlyAllowed returns (bool) {
        _requireApproved(loanId);
        if (block.timestamp < _maturity[loanId]) revert("Cannot make collection until maturity.");
        address borrower_ = _borrower[loanId];
        if (_makePayment(borrower_, IERC20(_currency[loanId]).balanceOf(_borrower[loanId]), loanId) > 0) {
            _hasBadDebt[borrower_] = true;
            return false;
        }
        return true;
    }

    // Allows anyone to make a payment on a given loan. Returns the amount of debt outstanding.
    function makePayment(uint loanId, uint amount) external virtual returns (uint) {
        if (_ownerOf(loanId) == address(0)) revert("Payment rejected. Loan has been released.");
        return _makePayment(_msgSender(), amount, loanId);
    }

    function getOffer(address lender, address currency) public virtual view returns (LoanTerms memory) {
        return _offers[lender][currency];
    }

    // Mask to disable public minting function.
    function mint(address to, uint tokenId) public override pure {
        revert("Tokens will be automatically minted as loans are made.");
    }

    // Makes a payment on the loan at `loanId` and returns the amount of debt outstanding.
    // If the loan is paid in full, burns the loan NFT and emits the LoanRepaid event.
    function _makePayment(address from, uint amount, uint loanId) internal virtual returns (uint) {
        uint payment_ = amount > _balance[loanId] ? _balance[loanId] : amount;
        if (!IERC20(_currency[loanId]).transferFrom(from, _ownerOf(loanId), payment_))
            revert("Payment rejected. Review sender balance and approvals.");
        _balance[loanId] -= payment_;
        uint remaining_ = _balance[loanId];
        if (remaining_ == 0) {
            burn(loanId);
            emit LoanRepaid(loanId);
        }
        return remaining_;
    }

    // Override to redefine how the onlyAllowed modifier works in your subclass.
    function _checkAllowed() internal override view {
        if (_hasBadDebt[_msgSender()]) revert ("Sender has bad debt and has been permanently banned.");
        super._checkAllowed();
    }

}