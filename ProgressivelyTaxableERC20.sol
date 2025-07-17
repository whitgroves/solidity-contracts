// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {TaxableERC20} from "./TaxableERC20.sol";

abstract contract ProgressivelyTaxableERC20 is TaxableERC20 {
    
    uint[] private _brackets;
    uint8[] private _taxRates;
    uint8 private _topTaxRate;
    
    event TaxBracketChanged(uint bracket, uint8 taxRate);

    constructor(address initialOwner) TaxableERC20(initialOwner) {
        // initialize arrays so setTaxRate works properly; otherwise, loop is skipped and no rates can be added
        _brackets.push(0);
        _taxRates.push(0);
    }

    function setTaxRate(uint bracket_, uint8 taxRate_) public virtual onlyDelegate {
        if (taxRate_ > taxCap()) revert("Tax rate cannot exceed max rate.");
        for (uint i = _brackets.length; i > 0; i--) {
            uint _bracket = _brackets[i-1];
            if (_bracket == bracket_) {
                _taxRates[i-1] = taxRate_;
                break;
            }
            if (_bracket < bracket_) {
                if (i == _brackets.length) {
                    _brackets.push(bracket_);
                    _taxRates.push(taxRate_);
                } else {
                    _brackets[i] = bracket_;
                    _taxRates[i] = taxRate_;
                }
                break;
            }
            if (i == _brackets.length) {
                _brackets.push(_bracket);
                _taxRates.push(_taxRates[i-1]);
            } else {
                _brackets[i] = _bracket;
                _taxRates[i] = _taxRates[i-1];
            }
        }
        if (taxRate_ > _topTaxRate) _topTaxRate = taxRate_;
        emit TaxBracketChanged(bracket_, taxRate_);
    }

    function bracket(uint bracketIndex) public virtual view returns (uint) {
        if (bracketIndex >= _brackets.length) revert("Tax bracket index out of bounds.");
        return _brackets[bracketIndex];
    }

    function taxRate(uint bracketIndex) public virtual view returns (uint8) {
        if (bracketIndex >= _taxRates.length) revert("Tax rate index out of bounds.");
        return _taxRates[bracketIndex];
    }

    // Since tax rates are per-bracket, this is overriden to apply a clamp on any rates above the new one.
    // Emits TaxBracketChanged here instead of going through setTaxRate to avoid nested loops.
    function setTaxRate(uint8 taxRate_) public virtual override onlyDelegate {
        if (taxRate_ > taxCap()) revert("Tax cap cannot exceed max tax rate.");
        for (uint i = 0; i < _taxRates.length; i++) {
            if (_taxRates[i] > taxRate_) {
                _taxRates[i] = taxRate_;
                emit TaxBracketChanged(_brackets[i], taxRate_);
            }
        }
        if (taxRate_ > _topTaxRate) _topTaxRate = taxRate_;
    }

    // Override of TaxableERC20.taxRate() to return the highest tax rate (instead of 0) for internal checks.
    function taxRate() public virtual override view returns (uint8) {
        return _topTaxRate;
    }

    // Override of TaxableERC20._collectTax() to justify this class' existence.
    function _collectTax(address account, uint256 value) internal virtual override returns (uint256) {
        uint tax = 0;
        uint remainder = value;
        for (uint i = 1; i < _brackets.length; i++) { // first bracket is 0 so we start at index = 1
            uint _bracket = _brackets[i];
            uint _margin = _bracket > value ? remainder : i > 0 ? _bracket - _brackets[i-1] : _bracket;
            uint _marginTax = (_margin * _taxRates[i]) / 100;
            tax += _marginTax;
            remainder -= _margin;
            if (remainder == 0) break;
        }
        if (remainder > 0) tax += (remainder * _taxRates[_brackets.length-1]) / 100;
        _transfer(account, payable(taxAddress()), tax);
        remainder = value - tax; 
        return remainder;
    }
}