// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

// A standard interface for non-fungible tokens.
// ERC165 identifier: 0x80ac58cd
// See: https://eips.ethereum.org/EIPS/eip-721
interface IERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external payable;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);   
}

// A standard interface for receivers of ERC721 tokens.
// ERC165 identifier: 0x150b7a02
// See: https://eips.ethereum.org/EIPS/eip-721
interface IERC721Receiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external returns (bytes4);
}