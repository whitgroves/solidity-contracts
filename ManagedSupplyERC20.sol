// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {TaxableERC20} from "./TaxableERC20.sol";

/* 
 * An extension of TradeableERC20 which implements an automatic burn rate and restricted minting 
 * determined by the token's current supply.
 */
abstract contract ManagedSupplyERC20 is TaxableERC20 {
    
    uint256 private _targetSupply;

    event SupplyTargetChanged(uint256 previousTarget, uint256 newTarget, uint256 currentSupply);

    constructor(address initialOwner, uint256 targetSupply_, uint8 maxTaxRate_) 
        TaxableERC20(initialOwner, maxTaxRate_)
    {
        setTargetSupply(targetSupply_);
    }

    function setTargetSupply(uint256 targetSupply_) public virtual onlyOwner {
        require (targetSupply_ > 0, "The target supply must be at least 1.");
        emit SupplyTargetChanged(_targetSupply, targetSupply_, totalSupply());
        _targetSupply = targetSupply_;
    }

    function targetSupply() public virtual view returns (uint256) {
        return _targetSupply;
    }

    function burnRate() public virtual view returns (uint) {
        uint targetRate = totalSupply() / targetSupply();
        uint maxBurnRate = maxTaxRate() - taxRate();
        if (targetRate > 0 && targetRate > maxBurnRate) return maxBurnRate;
        return targetRate;
    }

    // Wrapper for ERC20._mint() so owner and delegates can mint tokens while enforcing the supply cap.
    function mint(address account, uint256 value) public virtual onlyDelegate {
        if (_isInflated()) revert("Cannot mint while token supply is inflated.");
        uint maxValue = targetSupply() - totalSupply();
        if (value > maxValue) revert("Minting requested value would exceed target supply.");
        _mint(account, value);
    }

    // Wrapper for ERC20._burn() so tokens can be burned from their owners' (and only their owners') account.
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    // Takes a payment value, deducts and transfers a % of it as tax and/or burn, and then returns the remainder.
    function _collectTax(address account, uint256 value) internal override returns (uint256) {
        uint remainder = super._collectTax(account, value);
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