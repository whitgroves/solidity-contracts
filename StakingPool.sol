// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlled} from "./AccessControlled.sol";

// Imported code license: MIT
import {Pausable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol";
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/* 
 * Establishes a pool to stake any ERC20 token and distribute deposits of that token according to stake size.
 *
 * Calls to stake() must be pre-approved via IERC20.approve() on the original token. Other transfers will be 
 * treated as deposits to be distributed to stakeholders.
 *
 * The staking pool is paused by default, and can only be unpaused by the owner. A retired pool cannot be unpaused.
 */
abstract contract StakingPool is AccessControlled, Pausable {
    
    bool private _retired;
    uint private _totalStaked;
    address private _tokenAddress;
    address[] private _stakeholders;
    mapping(address stakeholder => uint tokens) private _stake;
    mapping(address stakeholder => bool everStaked) private _everStaked;

    constructor(address tokenAddress_, address initialOwner) AccessControlled(initialOwner) {
        require(IERC20(_requireNonZeroAddress(tokenAddress_)).totalSupply() > 0, "Token must have a supply to stake.");
        _tokenAddress = tokenAddress_;
    }

    function stake(uint amount) external virtual whenNotPaused onlyAllowed {
        if (!token().transferFrom(_msgSender(), address(this), amount))
            revert("Review sender balance and approvals.");
        if (_everStaked[_msgSender()] == false) {
            _everStaked[_msgSender()] = true;
            _stakeholders.push(_msgSender());
        }
        _stake[_msgSender()] += amount;
        _totalStaked += amount;
    }
    
    function unstake(uint amount) external virtual {
        require(amount <= stakeSize(), "Amount exceeds stake size.");
        if (!token().transfer(_msgSender(), amount)) revert("Unstaking transaction failed.");
        _stake[_msgSender()] -= amount;
        _totalStaked -= amount;
    }

    // @dev Distributes unallocated tokens stored at this address to stakeholders, proportional to stake size.
    // @return The total amount of tokens distributed.
    function distribute() external virtual onlyDelegate whenNotPaused returns (uint) {
        uint totalDistribution = token().balanceOf(address(this)) - totalStaked();
        if (totalDistribution == 0) revert("No funds to distribute");
        uint totalDistributed = 0;
        for (uint i = 0; i < _stakeholders.length; i++) {
            uint stake_ = _stake[_stakeholders[i]];
            if (stake_ == 0) continue;
            uint scale = ((stake_ * 1e18) / totalStaked());
            uint distribution = (totalDistribution * scale) / 1e18;
            _stake[_stakeholders[i]] += distribution;
            totalDistributed += distribution;
        }
        _totalStaked += totalDistributed;
        return totalDistributed;
    }

    // @dev Unstakes and transfers all staked tokens to their respective owners, then permanently closes the pool.
    function retire() external virtual onlyOwner whenPaused {
        IERC20 token_ = token();
        for (uint i = 0; i < _stakeholders.length; i++) {
            address stakeholder = _stakeholders[i];
            uint stake_ = _stake[stakeholder];
            if (stake_ == 0) continue;
            if (!token_.transfer(stakeholder, stake_)) revert("Destaking transaction failed.");
            _stake[stakeholder] = 0;
            _totalStaked -= stake_;
        }
        token_.approve(owner(), token_.balanceOf(address(this)));
        _retired = true;
    }

    function stakeSizeFor(address stakeholder) external virtual view onlyDelegate returns (uint) {
        return _stake[stakeholder];
    }

    function stakeSize() public virtual view returns (uint) {
        return _stake[_msgSender()];
    }

    function retired() public virtual view returns (bool) { return _retired; }
    
    function totalStaked() public virtual view returns (uint) { return _totalStaked; }

    function tokenAddress() public virtual view returns (address) { return _tokenAddress; }

    // @dev Wrapper to make Pausable._unpause() available to the contract owner, assuming the pool isn't retired.
    function unpause() public virtual onlyOwner {
        require(retired() == false, "A retired pool cannot be unpaused. Redeploy a new contract instead.");
        _unpause();
    }

    // @dev Wrapper to make Pausable._pause() available to the contract owner or their delegates.
    function pause() public virtual onlyDelegate {
        _pause();
    }

    function token() internal virtual returns (IERC20) {
        return IERC20(tokenAddress());
    }

}