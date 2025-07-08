// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAssetVault} from "./IAssetVault.sol";

interface IAssetVaultRegistry {
    function authorize(address authorizedAddress_) external;
    function isAuthorized(address authorizedAddress_) external view returns (bool);
    function create(address owner_) external returns (IAssetVault assetVault);
    function get(address owner_) external view returns (IAssetVault assetVault);
}
