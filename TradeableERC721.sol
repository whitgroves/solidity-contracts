// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {ERC721} from "./ERC721.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/* 
 * An extension of ERC721 which allows for the trading of NFTs in exchange for ERC20 tokens at a price set by the owner.
 * 
 * Note that this version of ERC721 inherits AccessControlled, which adds permission controls at the contract level.
 */
abstract contract TradeableERC721 is ERC721 {

    mapping(uint => bool) private _forSale;
    mapping(uint => mapping(address => uint)) private _prices;

    event ERC721TokenListedForSale(uint tokenId);
    event ERC721TokenSold(address currency, uint price, uint tokenId);

    constructor(address initialOwner) ERC721(initialOwner) {}

    function setPrice(address currency, uint amount, uint tokenId) external virtual {
        _requireOwnership(tokenId);
        if (IERC20(currency).totalSupply() == 0) revert("Provided token must have a supply.");
        _prices[tokenId][currency] = amount;
    }

    function buy(address currency, uint tokenId) external virtual returns (bool) {
        if (!isForSale(tokenId)) revert("Trade rejected. Token has not been approved for sale.");
        uint price = priceFor(currency, tokenId);
        if (price == 0) revert("Trade rejected. Owner has not set a price in the specified currency.");
        address owner = _ownerOf(tokenId);
        IERC20 token_ = IERC20(currency);
        if (!token_.transferFrom(_msgSender(), address(this), price) || !token_.transfer(owner, price)) 
            revert("Trade rejected. Review sender balance and approvals.");
        _update(owner, _msgSender(), tokenId);
        emit ERC721TokenSold(currency, price, tokenId);
        return true;
    }

    function setForSale(bool forSale_, uint tokenId) external virtual {
        _requireApproved(tokenId);
        _forSale[tokenId] = forSale_;
        if (forSale_) emit ERC721TokenListedForSale(tokenId);
    }

    function isForSale(uint tokenId) public virtual view returns (bool) {
        return _forSale[tokenId];
    }

    function priceFor(address currency, uint tokenId) public virtual view returns (uint) {
        return _prices[tokenId][currency];
    }

    // NFTs are taken off-market as soon as they are sold so the new owner can update prices before it's available for sale.
    function _update(address from, address to, uint256 tokenId) internal override {
        super._update(from, to, tokenId);
        _forSale[tokenId] = false;
    }

}