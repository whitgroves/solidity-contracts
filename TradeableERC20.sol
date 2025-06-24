// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlledERC20} from "./AccessControlledERC20.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

// An ERC20 token that can be traded for any other ERC20 token at a price set by the holder.
// Setting the exchange price to 0 disables trading in that currency, and all exchange rates are 0 by default.
abstract contract TradeableERC20 is AccessControlledERC20 {
    
    mapping(address => mapping(address => uint)) private _buyOffers;
    mapping(address => mapping(address => uint)) private _sellOffers;
    
    event ERC20TokensTraded(address currencyA, uint amountA, address currencyB, uint amountB);
    
    constructor(address initialOwner) ERC20(initialOwner) {}

    function makeTradeOffer(address currency, uint price) external virtual {
        makeBuyOffer(currency, price);
        makeSellOffer(currency, price);
    }

    function buy(address seller, address currency, uint amount) external virtual returns (bool) {
        _trade(_msgSender(), seller, currency, getSellOffer(seller, currency), amount);
        return true;
    }

    function sell(address buyer, address currency, uint amount) external virtual returns (bool) {
        _trade(buyer, _msgSender(), currency, getBuyOffer(buyer, currency), amount);
        return true;
    }

    function makeBuyOffer(address currency, uint price) public virtual nonZeroAddress(currency) {
        _buyOffers[_msgSender()][currency] = price;
    }

    function makeSellOffer(address currency, uint price) public virtual nonZeroAddress(currency) {
        _sellOffers[_msgSender()][currency] = price;
    }

    function getBuyOffer(address buyer, address currency) public virtual view
        nonZeroAddress(buyer) nonZeroAddress(currency) returns (uint)
    {
        return _buyOffers[buyer][currency];
    }

    function getSellOffer(address seller, address currency) public virtual view
        nonZeroAddress(seller) nonZeroAddress(currency) returns (uint) 
    {
        return _sellOffers[seller][currency];
    }

    function _trade(address buyer, address seller, address currency, uint offer, uint amount) internal virtual 
        whenNotPaused nonZeroAddress(seller)
    {
        if (offer == 0) revert("Trade rejected. Exchange not offered in selected currency.");
        uint price = offer * amount;
        IERC20 token_ = IERC20(currency);
        // 2-stage transfer incurs higher cost but makes it so this contract holds buyer's allowance and not the seller
        if (!token_.transferFrom(buyer, address(this), price) || !token_.transfer(seller, price)) 
            revert("Trade rejected. Funds transfer failed; check sender balance and approvals.");
        _transfer(seller, buyer, amount); // unsafe, done to skip allowance check for the contract to move its own token
        emit ERC20TokensTraded(address(this), amount, currency, price);
    }

}