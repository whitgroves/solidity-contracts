// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

// A standard interface for owning or controllng a contract.
// ERC165 identifier: 0x7f5828d0
// See: https://eips.ethereum.org/EIPS/eip-173
interface IERC173 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    function owner() external view returns (address);
    function transferOwnership(address _newOwner) external;
}