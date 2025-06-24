// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlledERC721} from "./AccessControlledERC721.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/* 
 * An extension of ERC721 which allows for the leasing of NFTs on a daily basis in exchange for ERC20 tokens.
 * Compare to extension with Leasable, which allows the entire smart contract to be leased out in the same manner.
 * 
 * Note that this version of ERC721 also inherits Delegated, which adds delegate permissions at the contract level.
 */
abstract contract LeasableERC721 is ERC721 {

    mapping(uint tokenId => uint) private _maxLeaseDays;
    mapping(uint tokenId => mapping(address currency => uint)) private _pricePerDay;
    mapping(uint tokenId => address) private _tenant;
    mapping(uint tokenId => uint) private _leaseEnd;
    mapping(uint tokenId => address) private _leaseCurrency;

    error ERC721TokenLeaseActive(uint tokenId);
    error ERC721TokenNotLeased(uint tokenId);

    event ERC721TokenLeased(address tenant, uint leaseEnd, uint tokenId);
    event ERC721TokenLeaseRevoked(address tenant, address owner, uint tokenId);

    constructor(address initialOwner) AccessControlledERC721(initialOwner) {}

    // Anyone authorized through IERC721 can update the lease terms on the token, assuming a lease is not active.
    // Setting max lease days to 0 permits an unlimited lease time.
    function setMaxLeaseDays(uint maxLeaseDays_, uint tokenId) external virtual {
        _requireApproved(tokenId);
        _requireNotLeased(tokenId);
        _maxLeaseDays[tokenId] = maxLeaseDays_;
    }

    // Setting the price to 0 for a currency makes it unavailable as an option.
    function setLeasePrice(address currency, uint pricePerDay_, uint tokenId) external virtual {
        _requireApproved(tokenId);
        _requireNotLeased(tokenId);
        require(IERC20(currency).totalSupply() > 0, "Price can only be set for a token with a supply.");
        _pricePerDay[tokenId][currency] = pricePerDay_;
    }

    function startLease(address currency, uint leaseDays, uint tokenId) external virtual {
        _lease(_msgSender(), currency, leaseDays, tokenId);
    }

    function startLeaseFor(address tenant_, address currency, uint leaseDays, uint tokenId) external virtual {
        _lease(tenant_, currency, leaseDays, tokenId);
    }

    function revokeLease(uint tokenId) external virtual {
        _requireOriginalOwnership(tokenId);
        _revoke(tokenId);
    }

    function terminateLease(uint tokenId) external virtual {
        _requireOwnership(tokenId);
        _revoke(tokenId);
    }

    function maxLeaseDays(uint tokenId) public virtual view returns (uint) {
        return _maxLeaseDays[tokenId];
    }

    function pricePerDay(uint tokenId, address currency) public virtual view returns (uint) {
        return _pricePerDay[tokenId][currency];
    }

    // overridden to update _leaseEnd for immediate leasability
    function mint(address to, uint tokenId) public virtual override {
        super.mint(to, tokenId);
        _leaseEnd[tokenId] = block.timestamp;
    }

    function isLeased(uint tokenId) public view virtual returns (bool) {
        return (block.timestamp < _leaseEnd[tokenId]);
    }

    function tenantOf(uint tokenId) public view virtual returns (address) {
        if (isLeased(tokenId)) return _tenant[tokenId];
        else return address(0);
    }

    function _lease(address tenant_, address currency, uint leaseDays, uint tokenId) internal virtual 
        whenNotPaused onlyAllowed 
    {
        _requireNotLeased(tokenId);
        require(leaseDays > 0, "Must lease for a specified amount of time.");
        uint maxLeaseDays_ = _maxLeaseDays[tokenId];
        if (maxLeaseDays_ > 0 && leaseDays > maxLeaseDays_) revert("NFT not leasable for requested time.");
        uint leasePrice = _pricePerDay[tokenId][currency] * leaseDays;
        if (leasePrice == 0) revert("NFT not leasable in requested currency.");
        if (!IERC20(currency).transferFrom(tenant_, owner(), leasePrice))
            revert("Lease denied. Review sender balance and approvals.");
        uint leaseEnd_ = block.timestamp + (leaseDays * 1 days);
        _tenant[tokenId] = tenant_;
        _leaseEnd[tokenId] = leaseEnd_;
        _leaseCurrency[tokenId] = currency;
        emit ERC721TokenLeased(tenant_, leaseEnd_, tokenId);
    }

    function _revoke(uint tokenId) internal virtual whenNotPaused onlyAllowed {
        _requireLeased(tokenId);
        uint daysRemaining = (_leaseEnd[tokenId] - block.timestamp) / 1 days;
        address currency = _leaseCurrency[tokenId];
        uint refund = _pricePerDay[tokenId][currency] * daysRemaining;
        address owner = _ownerOf(tokenId);
        address tenant = tenantOf(tokenId);
        if (!IERC20(currency).transferFrom(owner, tenant, refund))
            revert("Revocation denied. Review sender balance and approvals.");
        _leaseEnd[tokenId] = block.timestamp;
        emit ERC721TokenLeaseRevoked(tenant, owner, tokenId);
    }

    function _requireOriginalOwnership(uint tokenId) internal virtual returns (address) {
        address owner = _requireNonZeroAddress(_ownerOf(tokenId));
        if (_msgSender() != owner) revert ERC721UnauthorizedAccess(tokenId);
        return owner;
    }

    function _requireLeased(uint tokenId) internal virtual {
        if (!isLeased(tokenId)) revert ERC721TokenNotLeased(tokenId);
    }

    function _requireNotLeased(uint tokenId) internal virtual {
        if (isLeased(tokenId)) revert ERC721TokenLeaseActive(tokenId);
    }

    // override so tenant passes all authority checks wile leasing.
    // note that approved operators will still have authority to act in order to facilitate third-party services.
    function _requireOwnership(uint tokenId) internal virtual override returns (address) {
        address tenant = tenantOf(tokenId);
        if (tenant != address(0)) return tenant;
        return _requireAuthorized(tokenId, true);
    }

    // override so tokens aren't transferred while they're being rented
    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        _requireNotLeased(tokenId);
        super._transfer(from, to, tokenId);
    }

}