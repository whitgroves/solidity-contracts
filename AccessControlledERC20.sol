// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlled} from "./AccessControlled.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

abstract contract AccessControlledERC20 is IERC20, AccessControlled {

    uint private _totalSupply;
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) _allowances;

    error ERC20InsufficientFunds(address account);
    error ERC20InsufficientAllowance(address account, address spender);

    constructor(address initialOwner) AccessControlled(initialOwner) {}

    function totalSupply() public virtual view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) public virtual view nonZeroAddress(_owner) returns (uint256 balance) {
        return _balances[_owner];
    }

    function transfer(address _to, uint256 _value) public virtual nonZeroAddress(_to) returns (bool success) {
        return _transfer(_msgSender(), _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public virtual nonZeroAddress(_to) returns (bool success) {
        if (_from != _msgSender() && (allowance(_from, _msgSender()) < _value)) 
            revert ERC20InsufficientAllowance(_from, _msgSender());
        _allowances[_from][_msgSender()] -= _value;
        return _transfer(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public virtual nonZeroAddress(_spender) returns (bool success) {
        _allowances[_msgSender()][_spender] = _value;
        emit Approval(_msgSender(), _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public virtual view nonZeroAddress(_owner) returns (uint256 remaining) {
        return _allowances[_owner][_spender];
    }

    function _transfer(address _from, address _to, uint256 _value) internal virtual whenNotPaused onlyAllowed 
        returns (bool success) 
    {
        if ((_balances[_from] < _value) && (_from != address(0))) revert ERC20InsufficientFunds(_from);
        unchecked { // initial mint underflows the balance for the zero address, but we choose to ignore it
            _balances[_from] -= _value;
            _balances[_to] += _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

    function _mint(address _to, uint256 _value) internal virtual nonZeroAddress(_to) {
        _transfer(address(0), _to, _value);
        _totalSupply += _value;
    }

    function _burn(address _from, uint256 _value) internal virtual nonZeroAddress(_from) {
        _transfer(_from, address(0), _value);
        _totalSupply -= _value;
    }

}