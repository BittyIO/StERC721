// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

error InvalidAddress(address address_);
error WrappedERC721NotExists(address erc721);
error MissingStakedERC721(address erc721);
error InvalidERC721Owner(address erc721, uint256 tokenId);
error InvalidERC721(address erc721);
error InvalidERC721Token(address erc721, uint256 tokenId);
error InvalidCaller(address caller);
error InvalidStrategy(address strategy);
error AssetVaultNotFound(address owner);
error InvalidProofAsset();
error InvalidParams();
