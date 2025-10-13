// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {IERC173} from "./interfaces/IERC173.sol";

// An implementation of ERC173 based on OpenZeppelin's Ownable contract.
// _owner is internal instead of private to allow access by subclasses.
abstract contract ERC173 is IERC173 {

    address internal _owner;

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    constructor(address initialOwner) {
        transferOwnership(initialOwner);
    }

    function owner() public view virtual override returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        require(newOwner != address(0), "Can't transfer ownership to the zero address.");
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Caller must be the owner.");
    }
}