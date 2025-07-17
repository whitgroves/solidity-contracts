// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {TaxableERC20} from "./TaxableERC20.sol";

/* 
 * An extension of TradeableERC20 which implements an automatic burn rate and restricted minting 
 * determined by the token's current supply.
 */
abstract contract ManagedSupplyERC20 is TaxableERC20 {
    
    uint256 private _targetSupply;
    uint private _lastTargetSupplyUpdate;
    uint private _targetSupplyUpdateBuffer;

    event SupplyTargetChanged(uint256 previousTarget, uint256 newTarget, uint256 currentSupply);

    constructor(address initialOwner, uint256 targetSupply_) TaxableERC20(initialOwner) {
        setTargetSupply(targetSupply_);
    }

    // Wrapper for setTargetSupplyUpdateBuffer() to set update buffer on a daily timescale.
    function setTargetSupplyUpdateDays(uint bufferDays_) external virtual {
        setTargetSupplyUpdateBuffer(bufferDays_ * 1 days);
    }

    // Wrapper for setTargetSupplyUpdateBuffer() to set update buffer on an hourly timescale.
    function setTargetSupplyUpdateHours(uint bufferHours_) external virtual {
        setTargetSupplyUpdateBuffer(bufferHours_ * 1 hours);
    }

    // Wrapper for setTargetSupplyUpdateBuffer() to set update buffer on a minute timescale.
    function setTargetSupplyUpdateMinutes(uint bufferMinutes_) external virtual {
        setTargetSupplyUpdateBuffer(bufferMinutes_ * 1 minutes);
    }

    // Sets an optional buffer to prevent updates to the target supply for `targetSupplyUpdateBuffer_` seconds.
    // Note that setting the buffer > 0 makes `setTargetSupply()` delegated instead of onlyOwner.
    function setTargetSupplyUpdateBuffer(uint targetSupplyUpdateBuffer_) public virtual onlyOwner {
        _targetSupplyUpdateBuffer = targetSupplyUpdateBuffer_;
    }

    // Sets the target supply to `targetSupply_` tokens. If an update buffer has been set, the function will be treated
    // as delegated contingent on enough time passing since the last update. Otherwise, this function is onlyOwner.
    function setTargetSupply(uint256 targetSupply_) public virtual {
        require(targetSupply_ > 0, "The target supply must be at least 1.");
        if (_targetSupplyUpdateBuffer > 0) {
            _checkDelegate();
            if (block.timestamp < (lastTargetSupplyUpdate() + targetSupplyUpdateBuffer())) 
                revert("Target supply updates are buffered. Reduce buffer or wait until buffer time is reached.");
        }
        else _checkOwner();
        emit SupplyTargetChanged(_targetSupply, targetSupply_, totalSupply());
        _targetSupply = targetSupply_;
        _lastTargetSupplyUpdate = block.timestamp;
    }

    function targetSupply() public virtual view returns (uint256) {
        return _targetSupply;
    }

    function lastTargetSupplyUpdate() public virtual view returns (uint) {
        return _lastTargetSupplyUpdate;
    }

    function targetSupplyUpdateBuffer() public virtual view returns (uint) {
        return _targetSupplyUpdateBuffer;
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