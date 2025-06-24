// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {DemocraticallyOwned} from "./DemocraticallyOwned.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";

/* 
 * A smart contract that pools ERC20 and ERC721 tokens and authorizes them to be managed or spent by proxy.
 * As the contract is democratically owned, the pool itself is governed by an ERC20 or ERC721 token, and 
 * new authorizations may only occur outside of the nomination/election cycle.
 */
abstract contract TreasuryPool is DemocraticallyOwned, IERC721Receiver {
    
    mapping(address => bool) private _hasAuthorization;
    address[] private _authorizedTokens;

    event ERC20SpendingAuthorized(address indexed spender, address indexed currency, uint amount);
    event ERC721ManagementAuthorized(address indexed operator, address indexed collection);
    
    constructor(address tokenAddress_, address initialOwner) DemocraticallyOwned(tokenAddress_, initialOwner) {}

    // Allows the current owner to authorize spending of a held ERC20 token by themselves or a delegate.
    // Authorizations are limited by the total amount of `currency` in the pool, and cannot be updated during elections.
    function authorize(address spender, address currency, uint amount) external virtual onlyOwner whenNotPaused
        nonZeroAddress(spender) nonZeroAddress(currency) notDuringNomination notDuringElection returns (bool)
    {
        if (!isDelegate(spender)) revert("Authorized spenders must be active delegates.");
        IERC20 currency_ = IERC20(currency);
        if (currency_.balanceOf(address(this)) < amount)
            revert("Authorization would exceed treasury funds in that currency. Retry with a smaller amount.");
        if (!currency_.approve(spender, amount)) revert("Authorization failed. Review ERC20 contract.");
        if (!_hasAuthorization[currency]) {
            _hasAuthorization[currency] = true;
            _authorizedTokens.push(currency);
        } 
        emit ERC20SpendingAuthorized(spender, currency, amount);
        return true;
    }

    // Allows the current owner to authorize management over an NFT collection by themselves or a delegate.
    // Authorizations are for the entire collection, but will only apply to anything owned by this address.
    function authorize(address operator, address collection) external virtual onlyOwner whenNotPaused
        nonZeroAddress(operator) nonZeroAddress(collection) notDuringNomination notDuringElection returns (bool) 
    {
        if (!isDelegate(operator)) revert("Authorized operators must be active delegates.");
        IERC721 collection_ = IERC721(collection);
        collection_.setApprovalForAll(operator, true);
        if (!_hasAuthorization[collection]) {
            _hasAuthorization[collection] = true;
            _authorizedTokens.push(collection);
        }
        emit ERC721ManagementAuthorized(operator, collection);
        return true;
    }

    // IERC721Receiver
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external pure
        returns (bytes4) { return this.onERC721Received.selector; }

    // Override to ensure delegates lose spending/management authority when their delegation is removed.
    function _removeDelegate(address account) internal override {
        super._removeDelegate(account);
        for (uint i = 0; i < _authorizedTokens.length; i++) {
            address tokenAddress_ = _authorizedTokens[i];
            // Calling supportsInterface will fail for a standard token anyway, so fallback to try/catch.
            try IERC721(tokenAddress_).setApprovalForAll(account, false) { continue; }
            catch { IERC20(tokenAddress_).approve(account, 0); }
        }
    }

}