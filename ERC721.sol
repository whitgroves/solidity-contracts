// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import "https://github.com/whitgroves/solidity-contracts/blob/main/Delegated.sol";

// Imported code license: MIT
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/introspection/IERC165.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";

abstract contract ERC721 is IERC721, IERC165, Delegated {

    constant bytes4 private RECEIVER_HANDSHAKE = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));

    mapping(address owner => uint amount) private _balances;
    mapping(uint tokenId => address owner) private _owners;
    mapping(uint tokenId => address proxy) _approvals;
    mapping(address owner => mapping(address proxy => bool approved)) private _operators;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    error ERC721NonZeroAddressRequired();
    error ERC721UnauthorizedAccess(uint tokenId);
    error ERC721InvalidRecipient(uint tokenId);

    constructor() {}

    // IERC721

    function balanceOf(address owner) external virtual view returns (uint256) {
        return _balances[_requireNonZeroAddress(owner)];
    }

    function ownerOf(uint256 tokenId) external virtual view returns (address) {
        return _requireNonZeroAddress(_owners[tokenId]);
    }

    function transferFrom(address from, address to, uint256 tokenId) external virtual {
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external virtual {
        _safeTransfer(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external virtual {
       _safeTransfer(from, to, tokenId, data);
    }

    function approve(address to, uint256 tokenId) external virtual {
        address owner = _requireApproved(tokenId);
        _approvals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external virtual view returns (address) {
        return _approvals[_requireNonZeroAddress(_owners[tokenId])];
    }

    function setApprovalForAll(address operator, bool _approved) external virtual {
        address owner = _requireOwnership();
        _operators[owner][operator] == _approved;
        emit ApprovalForAll(owner, operator, _approved);
    }

    function isApprovedForAll(address owner, address operator) external virtual view returns (bool) {
        return _operators[_requireNonZeroAddress(owner)][operator];
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes calldata data) internal virtual {
        _transfer(from, to, tokenId);
        if (IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) != RECEIVER_HANDSHAKE)
            revert ERC721InvalidRecipient(tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        _requireNonZeroAddress(to);
        if (from != _requireApproved(tokenId)) revert ERC721UnauthorizedAccess(tokenId);
        _balances[from] -= 1;
        _owners[tokenId] = to;
        _balances[to] += 1;
        _approvals[tokenId] = address(0);
        emit Transfer(from, to, tokenId);
    }

    function _requireNonZeroAddress(address owner) internal virtual pure returns (address) {
        if (owner == address(0)) revert ERC721NonZeroAddressRequired();
        return owner;
    }

    function _requireApproved(uint tokenId) internal virtual pure returns (address) {
        return _requireAuthorized(tokenId, false);
    }

    function _requireOwnership(uint tokenId) internal virtual pure returns (address) {
        return _requireAuthorized(tokenId, true);
    }

    function _requireAuthorized(uint tokenId, bool ownerOnly) internal virtual pure returns (address) {
        address sender = _msgSender();
        address owner = _requireNonZeroAddress(_owners[tokenId]);
        if (owner == sender) return owner;
        if (ownerOnly) revert ERC721UnauthorizedAccess(tokenId);
        if (sender != _approvals[tokenId] && _operators[owner][sender] == false) 
            revert ERC721UnauthorizedAccess(tokenId);
        return owner;
    }

    // IERC165

    function supportsInterface(bytes4 interfaceId) external virtual view returns (bool) {
        return (interfaceId == type(IERC721).interfaceId ||
                interfaceId == type(IERC165).interfaceId);
    }
}