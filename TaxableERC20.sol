// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";

// An extension of ERC20 which implements an adjustable transaction tax and optional tax cap of 0-99%.
abstract contract TaxableERC20 is ERC20 {

    uint8 private immutable MAX_TAX_RATE;
    address private _taxAddress;
    uint8 private _taxRate;
    uint8 private _taxCap;

    event TaxAddressChanged(address previousAddress, address newAddress);
    event TaxRateChanged(uint8 previousRate, uint8 newRate);

    constructor(address initialOwner, uint8 maxTaxRate_) ERC20(initialOwner) {
        MAX_TAX_RATE = maxTaxRate_ > 99 ? 99 : maxTaxRate_; // strongly enforced since >= 100% tax is pointless
        setTaxCap(MAX_TAX_RATE);
    }

    // public to allow calls on subclass construction
    function setTaxAddress(address taxAddress_) public virtual onlyOwner {
        emit TaxAddressChanged(_taxAddress, taxAddress_);
        _taxAddress = taxAddress_;        
    }

    function setTaxRate(uint8 taxRate_) public virtual onlyDelegate {
        uint8 taxCap_ = taxCap();
        if (taxCap_ > 0 && taxRate_ > taxCap_) revert("Tax rate cannot exceed tax cap.");
        emit TaxRateChanged(_taxRate, taxRate_);
        _taxRate = taxRate_;
    }

    function setTaxCap(uint8 taxCap_) public virtual onlyOwner {
        if (taxCap_ > MAX_TAX_RATE) revert("Tax cap cannot exceed max tax rate.");
        _taxCap = taxCap_;
        if (_taxCap < taxRate()) setTaxRate(taxCap_);
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

    // Override of ERC20.transfer() to collect the transaction tax, since overriding _transfer() recurses.
    function transfer(address _to, uint256 _value) public virtual override nonZeroAddress(_to) returns (bool success) {
        _transfer(_msgSender(), _to, _adjust(_msgSender(), _value));
        return true;
    }

    // Override of ERC20.transferFrom() to collect the transaction tax, since overriding _transfer() recurses.
    function transferFrom(address _from, address _to, uint256 _value) public virtual override nonZeroAddress(_to) 
        returns (bool success) 
    {
        if (_from != _msgSender() && (allowance(_from, _msgSender()) < _value)) 
            revert ERC20InsufficientAllowance(_from, _msgSender());
        _allowances[_from][_msgSender()] -= _value;
        _transfer(_from, _to, _adjust(_from, _value));
        return true;
    }

    // Takes a payment value, deducts and transfers a % of it as tax, and then returns the remainder to be transferred.
    // If overriding _transfer(), do not call to this function, as it will recurse.
    function _adjust(address account, uint256 value) internal virtual returns (uint256) {
        if (taxRate() == 0 || taxAddress() == address(0)) return value;
        uint tax = (taxRate() * value) / 100;
        _transfer(account, payable(taxAddress()), tax);
        uint remainder = value - tax;
        return remainder;
    }

}