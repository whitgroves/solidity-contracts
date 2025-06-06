// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

// Imported code license: MIT
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/* 
 * An extension of OpenZeppelin's Ownable contract that allows ownership access to be leased out in exchange for
 * ERC20 tokens at a price set by the contract owner. The contract supports prices in multiple tokens, although
 * payment must be made in a single currency. After the lease ends, ownership access will expire automatically.
 */
abstract contract Leasable is Ownable {

    uint256 public maxLeaseSeconds;
    mapping(address currency => uint256 amount) public pricePerSecond;
    
    address private _tenant;
    uint256 private _leaseEnd;
    address private _leaseCurrency;

    error LeasableUnauthorizedAccount(address account);

    event ContractLeased(address tenant, uint256 leaseEnd);
    event LeaseRevoked(address tenant, address owner);
    
    constructor(address initialOwner) Ownable(initialOwner) {
        _leaseEnd = block.timestamp;
    }

    // This can be set to any value, but 0 will allow for unlimited time.
    function setMaxLeaseSeconds(uint256 maxLeaseSeconds_) public virtual onlyOwner notWhileLeased {
        maxLeaseSeconds = maxLeaseSeconds_;
    }

    // Setting the price to 0 removes that currency as an option.
    function setLeasePrice(address currency, uint256 pricePerSecond_) public virtual onlyOwner notWhileLeased {
        require(IERC20(currency).totalSupply() > 0, "Price can only be set for a token with a supply.");
        pricePerSecond[currency] = pricePerSecond_;
    }

    function startLease(address tenant_, address currency, uint256 leaseSeconds) public virtual notWhileLeased {
        require(leaseSeconds > 0, "Must lease for a specified amount of time.");
        if (maxLeaseSeconds > 0 && leaseSeconds > maxLeaseSeconds) revert("Contract not leasable for requested time.");
        uint256 leasePrice = pricePerSecond[currency] * leaseSeconds;
        if (leasePrice == 0) revert("Contract not leasable in requested currency.");
        if (!IERC20(currency).transferFrom(tenant_, owner(), leasePrice))
            revert("Lease denied. Review sender balance and approvals.");
        _tenant = tenant_;
        _leaseEnd = block.timestamp + leaseSeconds;
        _leaseCurrency = currency;
        emit ContractLeased(_tenant, _leaseEnd);
    }

    function revokeLease() public virtual whileLeased onlyOriginalOwner {
        uint256 secondsRemaining = _leaseEnd - block.timestamp;
        uint256 refund = pricePerSecond[_leaseCurrency] * secondsRemaining;
        if (!IERC20(_leaseCurrency).transferFrom(owner(), _tenant, refund))
            revert("Revocation denied. Review sender balance and approvals.");
        _leaseEnd = block.timestamp;
        emit LeaseRevoked(_tenant, owner());
    }

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

    function isLeased() public view virtual returns (bool) {
        return (block.timestamp < _leaseEnd);
    }

    function tenant() public view virtual returns (address) {
        if (isLeased()) return _tenant;
        else return address(0);
    }

    // While leased, tenant is treated as the owner.
    function _checkOwner() internal view override {
        if (!isLeased()) super._checkOwner();
        else if (tenant() != _msgSender()) revert LeasableUnauthorizedAccount(_msgSender());
    }

    // Override to prevent ownership transfer or renouncement during an active lease.
    function _transferOwnership(address newOwner) internal override virtual notWhileLeased {
        super._transferOwnership(newOwner);
    }
}