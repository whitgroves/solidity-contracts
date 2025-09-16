// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

// A standard method to publish and detect what interfaces a smart contract implements.
// ERC165 identifier: 0x01ffc9a7
// See: https://eips.ethereum.org/EIPS/eip-165
interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}