// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import "https://github.com/whitgroves/solidity-contracts/blob/main/Delegated.sol";

// Imported code license: MIT
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/* 
 * Establishes a pool to stake any ERC20 token and distribute deposits of that token according to stake size.
 *
 * Calls to stake() must be pre-approved via IERC20.approve() on the original token. Other transfers will be 
 * treated as deposits to be distributed to stakeholders.
 *
 * The staking pool is paused by default, and can only be unpaused by the owner. 
 * A retired pool cannot be unpaused.
 */
contract StakingPool is Delegated, Pausable {
    
    bool public active;
    bool public retired;
    address public tokenAddress;
    uint public totalStaked;

    address[] private _stakeholders;
    mapping(address stakeholder => uint tokens) private _stake;

    constructor(address _tokenAddress) Delegated(_msgSender()) {
        require(IERC20(_tokenAddress).totalSupply() > 0, "Token must have a supply to stake.");
        tokenAddress = _tokenAddress;
    }

    function stake(uint amount) external virtual whenNotPaused {
        if (!IERC20(tokenAddress).transferFrom(_msgSender(), address(this), amount))
            revert("Review sender balance and approvals.");
        if (_stake[_msgSender()] == 0) _stakeholders.push(_msgSender());
        _stake[_msgSender()] += amount;
        totalStaked += amount;
    }
    
    function unstake(uint amount) external virtual {
        require(amount <= _stake[_msgSender()], "Amount exceeds stake size.");
        if (!IERC20(tokenAddress).transfer(_msgSender(), amount)) revert("Unstaking transaction failed.");
        _stake[_msgSender()] -= amount;
        totalStaked -= amount;
    }

    function stakeSize() external view returns (uint) {
        return _stake[_msgSender()];
    }

    function stakeSizeFor(address stakeholder) external view onlyDelegate returns (uint) {
        return _stake[stakeholder];
    }

    // @dev Distributes unallocated tokens stored at this address to stakeholders, proportional to stake size.
    // @return The total amount of tokens distributed.
    function distribute() external virtual onlyDelegate whenNotPaused returns (uint) {
        uint totalDistribution = IERC20(tokenAddress).balanceOf(address(this)) - totalStaked;
        if (totalDistribution == 0) revert("No funds to distribute");
        uint totalDistributed = 0;
        for (uint i = 0; i < _stakeholders.length; i++) {
            uint stake_ = _stake[_stakeholders[i]];
            if (stake_ == 0) continue;
            uint scale = (stake_ * 1e18) / totalStaked;
            uint distribution = (totalDistribution * scale) / 1e18;
            _stake[_stakeholders[i]] += distribution;
            totalDistributed += distribution;
        }
        totalStaked += totalDistributed;
        return totalDistributed;
    }

    // @dev Wrapper to make Pausable._unpause() available to the contract owner, assuming the pool isn't retired.
    function unpause() public virtual onlyOwner {
        require(retired == false, "A retired pool cannot be unpaused. Redeploy a new contract instead.");
        _unpause();
    }

    // @dev Wrapper to make Pausable._pause() available to the contract owner or their delegates.
    function pause() public virtual onlyDelegate {
        _pause();
    }

    // @dev Unstakes and transfers all staked tokens to their respective owners, then permanently closes the pool.
    function retire() external virtual onlyOwner whenPaused {
        IERC20 token = IERC20(tokenAddress);
        for (uint i = 0; i < _stakeholders.length; i++) {
            address stakeholder = _stakeholders[i];
            uint stake_ = _stake[stakeholder];
            if (stake_ == 0) continue;
            if (!token.transfer(stakeholder, stake_)) revert("Destaking transaction failed.");
            _stake[stakeholder] = 0;
            totalStaked -= stake_;
        }
        token.approve(owner(), token.balanceOf(address(this)));
        retired = true;
    }
    
}