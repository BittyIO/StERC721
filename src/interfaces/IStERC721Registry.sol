// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAssetVaultRegistry} from "./IAssetVaultRegistry.sol";

interface IStERC721Registry {
    event Created(address indexed stERC721, address indexed impl);
    event Upgraded(address indexed stERC721, address indexed impl);

    function disableInitializers() external;

    function initialize(string memory chainName_, IAssetVaultRegistry assetVaultRegistry_) external;

    function createStERC721(address erc721, address stERC721Impl, address mintStrategy)
        external
        returns (address stERC721);
    function batchCreateStERC721(address[] calldata erc721s, address stERC721Impl, address[] calldata mintStrategys)
        external
        returns (address[] memory stERC721s);
    function upgradeStERC721(address stERC721, address stERC721Impl, bytes calldata encodedCallData) external;
    function batchUpgradeStERC721(address[] calldata stERC721s, address stERC721Impl, bytes[] calldata encodedCallDatas)
        external;

    function setBaseURI(address stERC721, string memory baseURI_) external;

    function setMintStrategy(address stERC721, address mintStrategy) external;

    function setSymbol(address stERC721, string memory symbol) external;
}
