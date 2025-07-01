// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

// Minimal interface for getting the owned balance of ERC20 or ERC721 tokens for a given address.
// In theory, supports token of any standard, as long as it contains the balanceOf(address) method signature.
interface IERC20orERC721 {
    function balanceOf(address owner) external view returns (uint256);
}