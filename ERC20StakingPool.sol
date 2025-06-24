// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlled} from "./AccessControlled.sol";

// Imported code license: MIT
import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/* 
 * Establishes a pool to stake any ERC20 token and distribute deposits of that token according to stake size.
 * By default, distributions are allocated and withdrawable but do not increase stake size; however, this can be
 * enabled via setAutoStake().
 *
 * Calls to stake() must be pre-approved via IERC20.approve() on the original token. Other transfers will be 
 * treated as deposits to be distributed to stakeholders.
 */
abstract contract ERC20StakingPool is AccessControlled {
    
    bool private _retired;
    uint private _totalStaked;
    uint private _totalDistributions;
    address private _tokenAddress;
    address[] private _stakeholders;
    mapping(address => uint) private _stake;
    mapping(address => uint) private _distributions;
    mapping(address => bool) private _everStaked;
    mapping(address => bool) private _autoStake;

    constructor(address tokenAddress_, address initialOwner) AccessControlled(initialOwner) {
        require(IERC20(_requireNonZeroAddress(tokenAddress_)).totalSupply() > 0, "Token must have a supply to stake.");
        _tokenAddress = tokenAddress_;
    }

    // Allows the sender to transfer tokens into this contract until they choose to unstake them.
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
    
    // Allows the sender to unstake a specified amount, assuming it is less than their allocated stake size.
    function unstake(uint amount) external virtual {
        if (amount > stakeSize()) revert("Amount exceeds stake size.");
        if (!token().transfer(_msgSender(), amount)) revert("Unstaking transaction failed.");
        _stake[_msgSender()] -= amount;
        _totalStaked -= amount;
    }

    // Transfers all distributed but non-staked funds allocated to the sender's account to the sender's address.
    function withdrawDistributions() external virtual {
        uint distributions_ = distributions();
        if (distributions_ == 0) revert("No unstaked distributions to withdraw.");
        if (!token().transfer(_msgSender(), distributions_)) revert("Distribution withdrawal failed.");
        _distributions[_msgSender()] = 0;
        _totalDistributions -= distributions_;
    }

    // Allows the sender to set their account to automatically stake distributions as they are allocated to them.
    function setAutoStake(bool autoStake_) public virtual {
        _autoStake[_msgSender()] = autoStake_;
    }

    // Distributes unallocated tokens stored at this address to stakeholders, proportional to stake size, and returns
    // the total amount of tokens distributed. Users with autoStake set to true will automatically have their stake size
    // increased; otherwise, funds will be available for withdrawal via withdrawDistributions().
    function distribute() public virtual onlyDelegate whenNotPaused returns (uint) {
        uint unallocated = token().balanceOf(address(this)) - totalAllocated();
        if (unallocated == 0) revert("No unallocated tokens to distribute.");
        uint totalDistributed_ = 0;
        uint totalAutostaked_ = 0;
        for (uint i = 0; i < _stakeholders.length; i++) {
            address stakeholder = _stakeholders[i];
            uint stake_ = stakeSizeFor(stakeholder);
            if (stake_ == 0) continue;
            uint scale = ((stake_ * 1e18) / totalStaked());
            uint distribution = (unallocated * scale) / 1e18;
            if (isAutoStaked(stakeholder)) {
                _stake[stakeholder] += distribution;
                totalAutostaked_ += distribution;
            } else {
                _distributions[stakeholder] += distribution;
                totalDistributed_ += distribution;
            }
        }
        _totalStaked += totalAutostaked_;
        _totalDistributions += totalDistributed_;
        return totalAutostaked_ + totalDistributed_;
    }

    // Unstakes and transfers all allocated tokens to their respective owners, then permanently closes the pool.
    function retire() public virtual onlyOwner whenPaused {
        IERC20 token_ = token();
        for (uint i = 0; i < _stakeholders.length; i++) {
            address stakeholder = _stakeholders[i];
            uint allocation = stakeSizeFor(stakeholder) + distributionsFor(stakeholder);
            if (allocation == 0) continue;
            if (!token_.transfer(stakeholder, allocation)) revert("Destaking transaction failed.");
        }
        token_.approve(owner(), token_.balanceOf(address(this)));
        _retired = true;
    }

    function stakeSizeFor(address stakeholder) public virtual view onlyDelegate returns (uint) {
        return _stake[stakeholder];
    }

    function distributionsFor(address stakeholder) public virtual view onlyDelegate returns (uint) {
        return _distributions[stakeholder];
    }

    function stakeSize() public virtual view returns (uint) {
        return _stake[_msgSender()];
    }

    function distributions() public virtual view returns (uint) {
        return _distributions[_msgSender()];
    }

    function retired() public virtual view returns (bool) { return _retired; }
    
    function totalStaked() public virtual view returns (uint) { return _totalStaked; }

    function tokenAddress() public virtual view returns (address) { return _tokenAddress; }

    // Override to restrict unpause() to non-retired pools.
    function unpause() public override {
        require(retired() == false, "A retired pool cannot be unpaused. Redeploy a new contract instead.");
        super.unpause();
    }

    function token() internal virtual returns (IERC20) {
        return IERC20(tokenAddress());
    }

    function isAutoStaked(address stakeholder) internal virtual view returns (bool) {
        return _autoStake[stakeholder];
    }

    function totalDistributed() internal virtual view returns (uint) { return _totalDistributions; }

    function totalAllocated() internal virtual returns (uint) {
        return totalStaked() + totalDistributed();
    }

}