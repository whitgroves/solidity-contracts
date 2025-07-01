// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlled} from "./AccessControlled.sol";
import {IERC20orERC721} from "./IERC20orERC721.sol";

// A smart contract where ownership is determined by the held balance of an underlying token set by the owner.
abstract contract MajorityOwned is AccessControlled {
    
    address private immutable _ownershipToken;

    constructor(address ownershipToken_, address initialOwner) AccessControlled(initialOwner) {
        if (IERC20orERC721(ownershipToken_).balanceOf(initialOwner) == 0)
            revert("Owner must hold a balance of the ownership token.");
        _ownershipToken = ownershipToken_;
    }

    // To avoid looped calls to `balanceOf`, any account can claim ownership by asserting it owns more of the underlying
    // token than the current owner. If true, ownership will be transferred immediately to the sender.
    // Note that if the balances are exactly the same, ownership will NOT transfer.
    function claimOwnership() external virtual onlyAllowed whenNotPaused returns (bool) {
        IERC20orERC721 ownershipToken_ = IERC20orERC721(ownershipToken());
        if (ownershipToken_.balanceOf(_msgSender()) > ownershipToken_.balanceOf(owner())) {
            _clearDelegates();
            _transferOwnership(_msgSender());
            return true;
        }
        return false;
    }

    function ownershipToken() public virtual view returns (address) {
        return _ownershipToken;
    }

}