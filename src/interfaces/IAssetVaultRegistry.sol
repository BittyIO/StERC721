// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IAssetVault} from "./IAssetVault.sol";

interface IAssetVaultRegistry {
    struct ProofAsset {
        address[] erc20Tokens;
        uint256[] erc20Amounts;
        address[] erc721Tokens;
        uint256[] erc721TokenIds;
        address[] erc1155Tokens;
        uint256[] erc1155TokenIds;
        uint256[] erc1155TokenAmounts;
    }

    function initialize(address assetVaultImpl_, address delegationRegistryV2_) external;
    function authorize(address authorizedAddress_) external;
    function revokeAuthorize(address authorizedAddress_) external;
    function addClaimAirdropStrategy(address strategy_) external;
    function removeClaimAirdropStrategy(address strategy_) external;
    function addExecuteAirdropStrategy(address strategy_) external;
    function removeExecuteAirdropStrategy(address strategy_) external;
    function isAuthorized(address authorizedAddress_) external view returns (bool);
    function create(address owner_) external returns (address assetVault);
    function getAssetVault(address owner_) external view returns (address assetVault);
    function setDelegateCashV2(
        address owner_,
        address delegate_,
        address erc721_,
        uint256 tokenId_,
        bytes32 rights_,
        bool value_
    ) external returns (bytes32 delegationHash);
    function unstakeERC721(address owner_, address to_, address erc721_, uint256 tokenId_) external;
    function stakedERC721(address owner_, address erc721_, uint256 tokenId_) external;
    function transferERC721(address owner_, address to_, address erc721_, uint256 tokenId_) external;

    function claimERC20(address to_, address token_, uint256 amount_) external;
    function claimERC721(address to_, address erc721_, uint256 tokenId_) external;
    function claimERC1155(address to_, address token_, uint256 id_, uint256 amount_, bytes memory data_) external;

    function claimAirdrop(address to_, address strategy_, ProofAsset memory proofAsset_, bytes memory data_) external;
    function executeAirdrop(address to_, address strategy_, bytes memory data_) external;
}
