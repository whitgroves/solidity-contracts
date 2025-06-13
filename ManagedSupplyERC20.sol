// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";

// Imported code license: MIT
import {Pausable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol";

/* 
 * An extension of ERC20 which implements a manually adjustable tax, automatic burn rate, pausable transactions, and a
 * restricted minting function determined by the token's current supply.
 */
abstract contract ManagedSupplyERC20 is ERC20, Pausable {
    
    uint8 constant TRANSACTION_CAP = 20;

    uint256 private _targetSupply;
    address private _taxAddress;
    uint8 private _taxRate;

    event SupplyTargetChanged(uint256 previousTarget, uint256 newTarget, uint256 currentSupply);
    event TaxAddressChanged(address previousAddress, address newAddress);
    event TaxRateChanged(uint8 previousRate, uint8 newRate);

    constructor(address initialOwner, uint256 targetSupply_) ERC20(initialOwner) {
        setTargetSupply(targetSupply_);
    }

    function setTaxAddress(address taxAddress_) external virtual onlyOwner {
        if (taxAddress_ == address(0)) revert("Tax address cannot be zero address.");
        emit TaxAddressChanged(_taxAddress, taxAddress_);
        _taxAddress = taxAddress_;        
    }

    function setTaxRate(uint8 taxRate_) external virtual onlyDelegate {
        if (taxRate_ > (TRANSACTION_CAP - burnRate())) revert("Tax + burn rates cannot exceed 20%.");
        emit TaxRateChanged(_taxRate, taxRate_);
        _taxRate = taxRate_;
    }

    function setTargetSupply(uint256 targetSupply_) public virtual onlyOwner {
        require (targetSupply_ > 0, "The target supply must be at least 1.");
        emit SupplyTargetChanged(_targetSupply, targetSupply_, totalSupply());
        _targetSupply = targetSupply_;
    }

    function targetSupply() public virtual view returns (uint256) {
        return _targetSupply;
    }

    function taxAddress() public virtual view returns (address) {
        return _taxAddress;
    }

    function taxRate() public virtual view returns (uint8) {
        return _taxRate;
    }

    function burnRate() public virtual view returns (uint) {
        uint targetRate = totalSupply() / targetSupply();
        if (targetRate > 0 && targetRate > (TRANSACTION_CAP - taxRate())) targetRate = (TRANSACTION_CAP - taxRate());
        return targetRate;
    }

    // Wrapper for ERC20._mint() so owner and delegates can mint tokens while enforcing the supply cap.
    function mint(address account, uint256 value) public virtual onlyDelegate {
        if (_isInflated()) revert("Cannot mint while token supply is inflated.");
        uint maxValue = targetSupply() - totalSupply();
        if (value > maxValue) revert("Minting requested value would exceed target supply.");
        _mint(account, value);
    }

    // Wrapper for ERC20._burn() so tokens can be burned from their owners (and only their owners) account.
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    // Override for ERC20._transfer() to allow pausing of transactions as a whole or for banned accounts.
    function _transfer(address _from, address _to, uint256 _value) internal virtual override whenNotPaused onlyAllowed {
        super._transfer(_from, _to, _adjust(_from, _value));
    }

    // Takes a payment value, deducts and transfers a % of it as tax and/or burn, and then returns the remainder.
    function _adjust(address account, uint256 value) internal virtual whenNotPaused returns (uint256) {
        uint remainder = value;
        if (taxRate() > 0 && taxAddress() != address(0)) {
            uint tax = (taxRate() * value) / 100;
            _transfer(account, payable(taxAddress()), tax);
            remainder -= tax;
        }
        if (_isInflated()) {
            uint burn_ = (burnRate() * value) / 100;
            _burn(account, burn_);
            remainder -= burn_;
        }
        return remainder;
    }

    function _isInflated() internal virtual view returns (bool) {
        return (totalSupply() > targetSupply());
    }

}