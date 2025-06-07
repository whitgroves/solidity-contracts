// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {Delegated} from "https://github.com/whitgroves/solidity-contracts/blob/main/Delegated.sol";

// Imported code license: MIT
import {Pausable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol";
import {ERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

/* 
 * An extension of OpenZeppelin's ERC20 which implements a manually adjustable tax, automatic burn rate,
 * and restricted minting function, determined by the token's current supply.
 */
abstract contract ManagedSupplyERC20 is ERC20, Delegated, Pausable {

    address public taxAddress;
    uint8 public taxRate;
    uint256 public targetSupply;

    event SupplyTargetChanged(uint256 previousTarget, uint256 newTarget, uint256 currentSupply);
    event TaxAddressChanged(address previousAddress, address newAddress);

    constructor(string memory name_, string memory symbol_, address initialOwner, uint256 targetSupply_) 
        ERC20(name_, symbol_) 
        Delegated(initialOwner) 
    {
        setTargetSupply(targetSupply_);
    }

    function setTargetSupply(uint256 targetSupply_) public virtual onlyOwner {
        require (targetSupply_ > 0, "The target supply must be at least 1.");
        uint256 previousTarget = targetSupply;
        targetSupply = targetSupply_;
        emit SupplyTargetChanged(previousTarget, targetSupply, totalSupply());
    }

    function setTaxAddress(address taxAddress_) public virtual onlyOwner {
        if (taxAddress_ == address(0)) revert("Tax address cannot be zero address.");
        address previousAddress = taxAddress;
        taxAddress = taxAddress_;
        emit TaxAddressChanged(previousAddress, taxAddress);
    }

    function setTaxRate(uint8 taxRate_) external virtual onlyDelegate {
        if (taxRate_ > (20 - burnRate())) revert("Tax + burn rates cannot exceed 20%.");
        taxRate = taxRate_;
    }

    function burnRate() public virtual view returns (uint) {
        uint targetRate = totalSupply() / targetSupply;
        if (targetRate > 0 && targetRate > (20 - taxRate)) targetRate = (20 - taxRate);
        return targetRate;
    }

    function _inflated() internal virtual view returns (bool) {
        return totalSupply() > targetSupply;
    }

    // Takes a payment value, deducts and transfers a % of it as tax and/or burn, and then returns the remainder.
    function _adjust(address account, uint256 value) internal virtual whenNotPaused returns (uint256) {
        uint remainder = value;
        if (taxRate > 0 && taxAddress != address(0)) {
            uint tax = (taxRate * value) / 100;
            _transfer(account, payable(taxAddress), tax);
            remainder -= tax;
        }
        if (_inflated()) {
            uint burn = (burnRate() * value) / 100;
            _burn(account, burn);
            remainder -= burn;
        }
        return remainder;
    }

    // Override of ERC20.transfer() to tax and burn each transaction, when applicable.
    function transfer(address to, uint256 value) public virtual override returns (bool) {
        address sender = _msgSender();
        _transfer(sender, to, _adjust(sender, value));
        return true;
    }

    // Override of ERC20.transferFrom() to tax and burn each transaction, when applicable.
    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, _adjust(spender, value));
        return true;
    }

    // Public wrapper for ERC20._mint() so owner and delegates can mint tokens while enforcing the supply cap.
    function mint(address account, uint256 value) public virtual onlyDelegate {
        if (_inflated()) revert("Cannot mint while token supply is inflated.");
        uint maxValue = targetSupply - totalSupply();
        if (value > maxValue) revert("Minting requested value would exceed target supply.");
        _mint(account, value);
    }
}