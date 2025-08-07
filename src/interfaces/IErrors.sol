// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

error InvalidAddress(address address_);
error StERC721AlreadyExists(address erc721);
error StERC721NotExists(address erc721);
error MissingStakedERC721(address erc721);
error InvalidERC721Owner(address erc721, uint256 tokenId);
error InvalidERC721(address erc721);
error InvalidCaller(address caller);
error InvalidStrategy(address strategy);
error AssetVaultNotFound(address owner);
error InvalidProofAsset();
