// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";

// An extension of ERC20 which implements an adjustable transaction tax and optional tax cap of 0-99%.
abstract contract TaxableERC20 is ERC20 {

    uint8 private immutable MAX_TAX_RATE;
    address private _taxAddress;
    uint8 private _taxRate;
    uint8 private _taxCap;
    mapping(address => bool) _isTaxExempt;

    event TaxAddressChanged(address previousAddress, address newAddress);
    event TaxRateChanged(uint8 previousRate, uint8 newRate);
    event TaxExemptionGranted(address account);
    event TaxExemptionRemoved(address account);

    constructor(address initialOwner, uint8 maxTaxRate_) ERC20(initialOwner) {
        MAX_TAX_RATE = maxTaxRate_ > 99 ? 99 : maxTaxRate_; // strongly enforced since >= 100% tax is pointless
        setTaxCap(MAX_TAX_RATE);
        setTaxExempt(address(0), true); // no tax on mints
    }

    // public to allow calls on subclass construction
    function setTaxAddress(address taxAddress_) public virtual onlyOwner {
        emit TaxAddressChanged(_taxAddress, taxAddress_);
        setTaxExempt(_taxAddress, false);
        setTaxExempt(taxAddress_, true);
        _taxAddress = taxAddress_;        
    }

    function setTaxRate(uint8 taxRate_) public virtual onlyDelegate {
        if (taxRate_ > taxCap()) revert("Tax rate cannot exceed tax cap.");
        emit TaxRateChanged(_taxRate, taxRate_);
        _taxRate = taxRate_;
    }

    function setTaxCap(uint8 taxCap_) public virtual onlyOwner {
        if (taxCap_ > MAX_TAX_RATE) revert("Tax cap cannot exceed max tax rate.");
        _taxCap = taxCap_;
        if (_taxCap < taxRate()) setTaxRate(taxCap_);
    }

    function setTaxExempt(address account, bool isExempt) public virtual onlyDelegate {
        if (_msgSender() == account && account != owner()) revert("Delegates cannot make themselves tax exempt.");
        _isTaxExempt[account] = isExempt;
        if (isExempt) emit TaxExemptionGranted(account);
        else emit TaxExemptionRemoved(account);
    }

    function taxAddress() public virtual view returns (address) {
        return _taxAddress;
    }

    function taxRate() public virtual view returns (uint8) {
        return _taxRate;
    }

    function taxCap() public virtual view returns (uint8) {
        return _taxCap;
    }

    function maxTaxRate() public view returns (uint8) {
        return MAX_TAX_RATE;
    }

    function isTaxExempt(address account) public view returns (bool) {
        return _isTaxExempt[account];
    }

    // Override of ERC20.transfer() to collect the transaction tax. Done here instead of _transfer() to avoid recursion.
    function transfer(address _to, uint256 _value) public virtual override nonZeroAddress(_to) returns (bool success) {
        return _processTransfer(_msgSender(), _to, _value);
    }

    // Override of ERC20.transferFrom() to collect the transaction tax. Done here instead of _transfer() to avoid recursion.
    function transferFrom(address _from, address _to, uint256 _value) public virtual override nonZeroAddress(_to) 
        returns (bool success) 
    {
        if (_from != _msgSender() && (allowance(_from, _msgSender()) < _value)) 
            revert ERC20InsufficientAllowance(_from, _msgSender());
        _allowances[_from][_msgSender()] -= _value;
        return _processTransfer(_from, _to, _value);
    }

    // Determines if the spender or sender are tax exempt, then collects tax if applicable.
    // Separate from _transfer() since overriding _transfer() recurses in derived classes.
    function _processTransfer(address _from, address _to, uint256 _value) internal virtual returns (bool success) {
        if (taxRate() == 0 || isTaxExempt(_from) || isTaxExempt(_to)) return _transfer(_from, _to, _value);
        return _transfer(_from, _to, _collectTax(_from, _value));
    }

    // Takes a payment value, deducts and transfers a % of it as tax, and then returns the remainder to be transferred.
    function _collectTax(address account, uint256 value) internal virtual returns (uint256) {
        uint tax = (taxRate() * value) / 100;
        _transfer(account, payable(taxAddress()), tax);
        uint remainder = value - tax;
        return remainder;
    }

}