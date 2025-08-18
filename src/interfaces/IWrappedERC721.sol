// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAssetVaultRegistry} from "./IAssetVaultRegistry.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IMintStrategy} from "./IMintStrategy.sol";

interface IWrappedERC721 is IERC721Metadata, IERC721Receiver, IERC721Enumerable {
    event Minted(address indexed to, uint256[] tokenId);
    event Burned(address indexed from, address indexed to, uint256[] tokenId);

    function disableInitializers() external;

    function initialize(
        string memory chainName_,
        IERC721Metadata erc721_,
        IAssetVaultRegistry assetVaultRegistry_,
        string memory name_,
        string memory symbol_,
        IMintStrategy mintStrategy_
    ) external;
    function mint(uint256[] calldata tokenIds) external;

    function burn(uint256[] calldata tokenIds, address receiver) external;
    function burn(uint256[] calldata tokenIds) external;

    function underlyingAsset() external view returns (address);

    function setMintStrategy(IMintStrategy mintStrategy) external;

    function setDelegateCashV2(address delegate, uint256[] calldata tokenIds, bytes32 rights, bool value)
        external
        returns (bytes32[] memory);

    function getDelegateCashForTokenV2(uint256[] calldata tokenIds_) external view returns (address[][] memory);

    function contractURI() external view returns (string memory);

    function setBaseURI(string memory baseURI_) external;

    function setNameAndSymbol(string memory name_, string memory symbol_) external;
}
