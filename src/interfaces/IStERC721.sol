// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IAssetVaultRegistry} from "./IAssetVaultRegistry.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IStERC721 is IERC721Metadata, IERC721Receiver, IERC721Enumerable {
    event Minted(address indexed to, uint256[] tokenId);
    event Burned(address indexed from, uint256[] tokenId);

    function initialize(
        IERC721Metadata erc721_,
        IAssetVaultRegistry assetVaultRegistry_,
        string memory name_,
        string memory symbol_
    ) external;
    function mint(address to, uint256[] calldata tokenIds) external;

    function burn(uint256[] calldata tokenIds) external;

    function underlyingAsset() external view returns (address);

    function setDelegateCashV2(address delegate, uint256[] calldata tokenIds, bytes32 rights, bool value) external;

    function getDelegateCashForTokenV2(uint256[] calldata tokenIds_) external view returns (address[][] memory);

    function contractURI() external view returns (string memory);
}
