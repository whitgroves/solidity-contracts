// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {Delegated} from "https://github.com/whitgroves/solidity-contracts/blob/main/Delegated.sol";
import {InputValidated} from "https://github.com/whitgroves/solidity-contracts/blob/main/InputValidated.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/* 
 * An extension of the Delegated contract that allows ownership access to be leased out on a daily basis
 * in exchange for ERC20 tokens at a price set by the contract owner. The contract supports prices in multiple tokens,
 * although payment must be made in a single currency. 
 * 
 * After the lease ends, ownership reverts automatically, but the lease can be revoked at any time by the owner in
 * exchange for a refund of the remaining time in the original currency.
 */
abstract contract Leasable is Delegated, InputValidated {

    uint public maxLeaseDays;
    mapping(address currency => uint amount) public pricePerDay;
    
    address private _tenant;
    uint private _leaseEnd;
    address private _leaseCurrency;

    event ContractLeased(address tenant, uint leaseEnd);
    event LeaseRevoked(address tenant, address owner);
    
    modifier onlyOriginalOwner() {
        if (owner() != _msgSender()) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    modifier whileLeased() {
        if (!isLeased()) revert("Cannot access outside active lease.");
        _;
    }

    modifier notWhileLeased() {
        if (isLeased()) revert("Cannot access during active lease.");
        _;
    }

    constructor(address initialOwner) Delegated(initialOwner) {
        _leaseEnd = block.timestamp;
    }

    // This can be set to any value, but 0 will allow for unlimited time.
    function setMaxLeaseDays(uint maxLeaseDays_) external virtual onlyDelegate notWhileLeased {
        maxLeaseDays = maxLeaseDays_;
    }

    // Setting the price to 0 removes that currency as an option.
    function setLeasePrice(address currency, uint pricePerDay_) external virtual onlyDelegate notWhileLeased nonZeroAddress(currency) {
        require(IERC20(currency).totalSupply() > 0, "Price can only be set for a token with a supply.");
        pricePerDay[currency] = pricePerDay_;
    }

    function startLease(address currency, uint leaseDays) external virtual {
        _lease(_msgSender(), currency, leaseDays);
    }

    function startLeaseFor(address tenant_, address currency, uint leaseDays) external virtual {
        _lease(tenant_, currency, leaseDays);
    }

    function revokeLease() external virtual onlyOriginalOwner {
        _revoke();
    }

    function terminateLease() external virtual onlyOwner {
        _revoke();
    }

    function isLeased() public virtual view returns (bool) {
        return (block.timestamp < _leaseEnd);
    }

    // public (vs external) so subclasses have access
    function tenant() public virtual view returns (address) {
        if (isLeased()) return _tenant;
        else return address(0);
    }

    function _lease(address tenant_, address currency, uint leaseDays) internal virtual notWhileLeased nonZeroAddress(tenant_) {
        require(leaseDays > 0, "Must lease for a specified amount of time.");
        if (maxLeaseDays > 0 && leaseDays > maxLeaseDays) revert("Contract not leasable for requested time.");
        uint leasePrice = pricePerDay[currency] * leaseDays;
        if (leasePrice == 0) revert("Contract not leasable in requested currency.");
        if (!IERC20(currency).transferFrom(tenant_, owner(), leasePrice))
            revert("Lease denied. Review sender balance and approvals.");
        _tenant = tenant_;
        _leaseEnd = block.timestamp + (leaseDays * 1 days);
        _leaseCurrency = currency;
        emit ContractLeased(_tenant, _leaseEnd);
    }

    function _revoke() internal virtual whileLeased {
        uint daysRemaining = (_leaseEnd - block.timestamp) / 1 days;
        uint refund = pricePerDay[_leaseCurrency] * daysRemaining;
        if (!IERC20(_leaseCurrency).transferFrom(owner(), _tenant, refund))
            revert("Revocation denied. Review sender balance and approvals.");
        _leaseEnd = block.timestamp;
        emit LeaseRevoked(_tenant, owner());
    }

    // While leased, tenant is treated as the owner for onlyOwner checks.
    function _checkOwner() internal override view {
        if (!isLeased()) super._checkOwner();
        else if (tenant() != _msgSender()) revert UnauthorizedAccessRequest(_msgSender());
    }

    // Override to prevent ownership transfer or renouncement during an active lease.
    function _transferOwnership(address newOwner) internal override notWhileLeased {
        super._transferOwnership(newOwner);
    }
}