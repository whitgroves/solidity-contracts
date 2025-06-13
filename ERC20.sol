// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {InputValidated} from "https://github.com/whitgroves/solidity-contracts/blob/main/InputValidated.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import {Context} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Context.sol";

abstract contract ERC20 is IERC20, Context, InputValidated {

    uint private _totalSupply;
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) _allowances;

    error ERC20InsufficientFunds(address account);
    error ERC20InsufficientAllowance(address account, address spender);

    function totalSupply() public virtual view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) public virtual view returns (uint256 balance) {
        return _balances[_owner];
    }

    function transfer(address _to, uint256 _value) public virtual nonZeroAddress(_to) returns (bool success) {
        _transfer(_msgSender(), _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public virtual returns (bool success) {
        address sender = _msgSender();
        if (_from != sender && (allowance(_from, sender) < _value)) revert ERC20InsufficientAllowance(_from, sender);
        _allowances[_from][sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public virtual nonZeroAddress(_spender) returns (bool success) {
        _allowances[_msgSender()][_spender] = _value;
        emit Approval(_msgSender(), _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public virtual view returns (uint256 remaining) {
        return _allowances[_owner][_spender];
    }

    function _transfer(address _from, address _to, uint256 _value) internal virtual {
        if (_balances[_from] < _value) revert ERC20InsufficientFunds(_from);
        _balances[_from] -= _value;
        _balances[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    function _mint(address _to, uint256 _value) internal virtual {
        _balances[_to] += _value;
        _totalSupply += _value;
        emit Transfer(address(0), _to, _value);
    }

    function _burn(address _from, uint256 _value) internal virtual {
        if (_balances[_from] < _value) revert ERC20InsufficientFunds(_from);
        _balances[_from] -= _value;
        _totalSupply -= _value;
        emit Transfer(_from, address(0), _value);
    }
}