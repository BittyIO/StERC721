// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAssetVault} from "./IAssetVault.sol";

interface IAssetVaultRegistry {
    function disableInitializers() external;
    function authorize(address authorizedAddress_) external;
    function isAuthorized(address authorizedAddress_) external view returns (bool);
    function create(address owner_) external returns (address assetVault);
    function get(address owner_) external view returns (address assetVault);
    function setDelegateCashV2(
        address owner_,
        address delegate_,
        address erc721_,
        uint256 tokenId_,
        bytes32 rights_,
        bool value_
    ) external returns (bytes32 delegationHash);
    function withdrawERC721(address owner_, address to_, address erc721_, uint256 tokenId_) external;
}
