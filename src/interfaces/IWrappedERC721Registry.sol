// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAssetVaultRegistry} from "./IAssetVaultRegistry.sol";

interface IWrappedERC721Registry {
    event Created(address indexed wrappedERC721, address indexed impl);
    event Upgraded(address indexed wrappedERC721, address indexed impl);

    function initialize(string memory chainName_, IAssetVaultRegistry assetVaultRegistry_) external;

    function createWrappedERC721(address erc721, address wrappedERC721Impl, address mintStrategy)
        external
        returns (address wrappedERC721);
    function batchCreateWrappedERC721(
        address[] calldata erc721s,
        address wrappedERC721Impl,
        address[] calldata mintStrategys
    ) external returns (address[] memory wrappedERC721s);
    function upgradeWrappedERC721(address wrappedERC721, address wrappedERC721Impl, bytes calldata encodedCallData)
        external;
    function batchUpgradeWrappedERC721(
        address[] calldata wrappedERC721s,
        address wrappedERC721Impl,
        bytes[] calldata encodedCallDatas
    ) external;

    function setBaseURI(address wrappedERC721, string memory baseURI_) external;

    function setMintStrategy(address wrappedERC721, address mintStrategy) external;

    function setSymbol(address wrappedERC721, string memory symbol) external;

    function addClaimAirdropStrategy(address strategy_) external;
    function removeClaimAirdropStrategy(address strategy_) external;
    function addExecuteAirdropStrategy(address strategy_) external;
    function removeExecuteAirdropStrategy(address strategy_) external;
}
