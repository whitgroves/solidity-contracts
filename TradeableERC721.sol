// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlledERC721} from "./AccessControlledERC721.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";

/* 
 * An extension of AccessControlledERC721 which allows for the trading of NFTs in exchange for ERC20 tokens at a price 
 * set by the owner, or for another NFT from this (or any) collection.
 * 
 * Note that this version of ERC721 inherits AccessControlled, which adds permission controls at the contract level.
 */
abstract contract TradeableERC721 is AccessControlledERC721 {

    mapping(uint => bool) private _canTrade;
    mapping(uint => mapping(address => uint)) private _prices;
    mapping(uint => mapping(address => uint[])) private _trades;

    event ERC721TokenListedForSale(address indexed currency, uint price, uint tokenId);
    event ERC721TokenSold(address indexed currency, uint price, uint tokenId);
    event ERC721TokenListedForTrade(address indexed collection, uint desiredTokenId, uint ownedTokenId);
    event ERC721TokenTraded(address indexed collection, uint offeredTokenId, uint tradedTokenId);

    constructor(address initialOwner) AccessControlledERC721(initialOwner) {}

    // Sets a price for the NFT (tokenId) in the specified currency. To reject trades in that currency, set price to 0.
    function setPrice(address currency, uint amount, uint tokenId) external virtual {
        _requireOwnership(tokenId);
        if (IERC20(currency).totalSupply() == 0) revert("Provided currency must have a supply.");
        _prices[tokenId][currency] = amount;
        if (amount > 0) emit ERC721TokenListedForSale(currency, amount, tokenId);
    }

    // Sets an NFT (ownedTokenId) for trade in exchange for another NFT (desiredTokenId) from a specific collection.
    function setTrade(address collection, uint desiredTokenId, uint ownedTokenId) external virtual {
        _requireOwnership(ownedTokenId);
        if (!IERC721(collection).supportsInterface(type(IERC721).interfaceId))
            revert("Provided collection is not supported.");
        uint[] tradesInCollection_ = _trades[ownedTokenId][collection];
        for (uint i = 0; i < tradesInCollection_.length; i++) {
            if (tradesInCollection_[i] == desiredTokenId) 
                revert("Desired token is already listed as an acceptable trade.");
        }
        _trades[ownedTokenId][collection].push(desiredTokenId);
        emit ERC721TokenListedForTrade(collection, desiredTokenId, ownedTokenId);
    }

    // Removes an NFT from another collection (undesiredTokenId) as a trade option for specified NFT (ownedTokenId).
    function removeTrade(address collection, uint undesiredTokenId, uint ownedTokenId) external virtual {
        _requireOwnership(ownedTokenId);
        if (!IERC721(collection).supportsInterface(type(IERC721).interfaceId))
            revert("Provided collection is not supported.");
        uint[] tradesInCollection_ = _trades[ownedTokenId][collection];
        bool indexFound;
        for (uint i = 0; i < tradesInCollection_.length - 1; i++) {
            if (tradesInCollection_[i] == undesiredTokenId) indexFound = true;
            if (indexFound) tradesInCollection_[i] = tradesInCollection_[i+1];
        }
        if (tradesInCollection_.pop() != undesiredTokenId && !indexFound) 
            revert("Undesired token ID was not listed for trade.");
        _trades[ownedTokenId][collection] = tradesInCollection_;
    }

    // Allows the sender to purchase a tradeable NFT in exchange for a specified currency. Returns true on success.
    function buy(address currency, uint tokenId) external virtual returns (bool) {
        if (!canTrade(tokenId)) revert("Trade rejected. Token has not been approved for exchange.");
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

    // Allows the sender to trade an NFT from the specified collection for an exchangeable one listed here.
    function trade(address collection, uint offeredTokenId, uint tradeableTokenId) external virtual returns (bool) {
        if (!canTrade(tradeableTokenId)) revert("Trade rejected. Token has not been approved for exchange.");
        IERC721 collection_ = IERC721(collection);
        if (!collection_.supportsInterface(type(IERC721).interfaceId)) revert("Provided collection is not supported.");
        if (!collection_.ownerOf(offeredTokenId) != _msgSender()) revert("Sender is not owner of the offered token.");
        uint[] tradesInCollection_ = _trades[tradeableTokenId][collection];
        for (uint i = 0; i < tradesInCollection_.length; i++) {
            if (tradesInCollection_[i] == offeredTokenId) {
                address owner = ownerOf(tradeableTokenId);
                collection_.transferFrom(_msgSender(), owner, offeredTokenId);
                _update(owner, _msgSender(), tradeableTokenId);
                emit ERC721TokenTraded(collection, offeredTokenId, tradeableTokenId);
                return true;
            }
        }
        return false;
    }

    // Toggles tradability for a given NFT to prevent unintentional exchanges immediately after the last one.
    function setCanTrade(bool canTrade_, uint tokenId) external virtual {
        _requireApproved(tokenId);
        _canTrade[tokenId] = canTrade_;
    }

    // Returns true if the token owner has enabled that NFT for exchange.
    function canTrade(uint tokenId) public virtual view returns (bool) {
        return _canTrade[tokenId];
    }

    // Returns the listed price for an NFT in a given currency, but not whether it's been enabled for trading.
    function priceFor(address currency, uint tokenId) public virtual view returns (uint) {
        return _prices[tokenId][currency];
    }

    // Returns whether an NFT from this collection can be traded for the offered one in the specified collection.
    function isTradeFor(address collection, uint offeredTokenId, uint desiredTokenId) public virtual view returns (bool) {
        uint[] tradesInCollection_ = _trades[desiredTokenId][collection];
        for (uint i = 0; i < tradesInCollection_.length; i++) {
            if (tradesInCollection_[i] == offeredTokenId) return true;
        }
        return false;
    }

    // NFTs are taken off-market as soon as they are sold so the new owner can update prices before it's available for sale.
    function _update(address from, address to, uint256 tokenId) internal override {
        super._update(from, to, tokenId);
        _canTrade[tokenId] = false;
    }

}