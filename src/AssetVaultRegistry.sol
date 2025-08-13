// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";
import {IAssetVault} from "./interfaces/IAssetVault.sol";
import {IClaimAirdropStrategy} from "./interfaces/IClaimAirdropStrategy.sol";
import {IExecuteAirdropStrategy} from "./interfaces/IExecuteAirdropStrategy.sol";
import {
    InvalidAddress,
    InvalidCaller,
    InvalidStrategy,
    AssetVaultNotFound,
    InvalidProofAsset
} from "./interfaces/IErrors.sol";

contract AssetVaultRegistry is OwnableUpgradeable, IAssetVaultRegistry {
    using Clones for address;
    using SafeERC20 for IERC20;
    using ERC165Checker for address;

    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => IAssetVault) private assetVaults;
    mapping(address => bool) public authorized;
    EnumerableSet.AddressSet private claimAirdropStrategies;
    EnumerableSet.AddressSet private executeAirdropStrategies;

    address public assetVaultImpl;
    address public delegationRegistryV2;

    modifier onlyAuthorized() {
        if (!authorized[msg.sender]) {
            revert InvalidCaller(msg.sender);
        }
        _;
    }

    modifier onlyClaimAirdropStrategy(address strategy_) {
        if (!claimAirdropStrategies.contains(strategy_)) {
            revert InvalidStrategy(strategy_);
        }
        _;
    }

    modifier onlyExecuteAirdropStrategy(address strategy_) {
        if (!executeAirdropStrategies.contains(strategy_)) {
            revert InvalidStrategy(strategy_);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address assetVaultImpl_, address delegationRegistryV2_) external override initializer {
        __Ownable_init(msg.sender);
        // disable initializers for asset vault impl, guard against implementation contract calling dangerous functions
        // through delegatecall, eg: selfdestruct
        IAssetVault(assetVaultImpl_).disableInitializers();
        assetVaultImpl = assetVaultImpl_;
        delegationRegistryV2 = delegationRegistryV2_;
    }

    function authorize(address authorizedAddress_) external override onlyOwner {
        if (authorizedAddress_ == address(0)) {
            revert InvalidAddress(authorizedAddress_);
        }
        authorized[authorizedAddress_] = true;
    }

    function revokeAuthorize(address authorizedAddress_) external override onlyOwner {
        delete authorized[authorizedAddress_];
    }

    function addClaimAirdropStrategy(address strategy_) external override onlyOwner {
        if (strategy_ == address(0)) {
            revert InvalidAddress(strategy_);
        }
        if (!strategy_.supportsInterface(type(IClaimAirdropStrategy).interfaceId)) {
            revert InvalidStrategy(strategy_);
        }
        claimAirdropStrategies.add(strategy_);
    }

    function removeClaimAirdropStrategy(address strategy_) external override onlyOwner {
        claimAirdropStrategies.remove(strategy_);
    }

    function addExecuteAirdropStrategy(address strategy_) external override onlyOwner {
        if (strategy_ == address(0)) {
            revert InvalidAddress(strategy_);
        }
        if (!strategy_.supportsInterface(type(IExecuteAirdropStrategy).interfaceId)) {
            revert InvalidStrategy(strategy_);
        }
        executeAirdropStrategies.add(strategy_);
    }

    function removeExecuteAirdropStrategy(address strategy_) external override onlyOwner {
        executeAirdropStrategies.remove(strategy_);
    }

    function create(address owner_) external override onlyAuthorized returns (address assetVault) {
        return _create(owner_);
    }

    function _create(address owner_) internal returns (address assetVault) {
        if (owner_ == address(0)) {
            revert InvalidAddress(owner_);
        }
        IAssetVault assetVault_ = assetVaults[owner_];
        if (address(assetVault_) == address(0)) {
            assetVault_ = IAssetVault(assetVaultImpl.clone());
            assetVault_.initialize(address(this), delegationRegistryV2);
        }
        assetVaults[owner_] = assetVault_;
        return address(assetVault_);
    }

    function isAuthorized(address authorizedAddress_) external view returns (bool) {
        return authorized[authorizedAddress_];
    }

    function getAssetVault(address owner_) external view override returns (address assetVault) {
        return address(_getAssetVault(owner_));
    }

    function _getAssetVault(address owner_) internal view returns (IAssetVault assetVault) {
        assetVault = assetVaults[owner_];
        if (address(assetVault) == address(0)) {
            revert AssetVaultNotFound(owner_);
        }
    }

    function setDelegateCashV2(
        address owner_,
        address delegate_,
        address erc721_,
        uint256 tokenId_,
        bytes32 rights_,
        bool value_
    ) external override onlyAuthorized returns (bytes32 delegationHash) {
        return _getAssetVault(owner_).setDelegateCashV2(delegate_, erc721_, tokenId_, rights_, value_);
    }

    function unstakeERC721(address owner_, address to_, address erc721_, uint256 tokenId_)
        external
        override
        onlyAuthorized
    {
        IAssetVault ownerAssetVault_ = _getAssetVault(owner_);
        ownerAssetVault_.transferERC721(to_, erc721_, tokenId_);
        ownerAssetVault_.unstakeERC721(erc721_, tokenId_);
    }

    // The ERC721 must be transferred in by the StERC721 contract
    function stakedERC721(address owner_, address erc721_, uint256 tokenId_) external override onlyAuthorized {
        IAssetVault ownerAssetVault_ = _getAssetVault(owner_);
        ownerAssetVault_.stakeERC721(erc721_, tokenId_);
    }

    function transferERC721(address from_, address to_, address erc721_, uint256 tokenId_)
        external
        override
        onlyAuthorized
    {
        IAssetVault fromAssetVault_ = _getAssetVault(from_);
        address assetVaultTo_ = _create(to_);
        fromAssetVault_.transferERC721(assetVaultTo_, erc721_, tokenId_);
        if (address(fromAssetVault_) != assetVaultTo_) {
            fromAssetVault_.unstakeERC721(erc721_, tokenId_);
            IAssetVault(assetVaultTo_).stakeERC721(erc721_, tokenId_);
        }
    }

    function claimERC20(address to_, address token_, uint256 amount_) external override {
        _getAssetVault(msg.sender).transferERC20(to_, token_, amount_);
    }

    function claimERC721(address to_, address erc721_, uint256 tokenId_) external override {
        _getAssetVault(msg.sender).transferNonStakedERC721(to_, erc721_, tokenId_);
    }

    function claimERC1155(address to_, address token_, uint256 id_, uint256 amount_, bytes calldata data_)
        external
        override
    {
        _getAssetVault(msg.sender).transferERC1155(to_, token_, id_, amount_, data_);
    }

    function claimAirdrop(address to_, address strategy_, ProofAsset memory proofAsset_, bytes memory data_)
        external
        override
        onlyClaimAirdropStrategy(strategy_)
    {
        address owner_ = msg.sender;
        IAssetVault ownerAssetVault_ = _getAssetVault(owner_);
        if (proofAsset_.erc20Tokens.length != proofAsset_.erc20Amounts.length) {
            revert InvalidProofAsset();
        }
        if (proofAsset_.erc721Tokens.length != proofAsset_.erc721TokenIds.length) {
            revert InvalidProofAsset();
        }
        if (
            proofAsset_.erc1155Tokens.length != proofAsset_.erc1155TokenIds.length
                || proofAsset_.erc1155Tokens.length != proofAsset_.erc1155TokenAmounts.length
        ) {
            revert InvalidProofAsset();
        }
        // Transfer assets to strategy
        for (uint256 i = 0; i < proofAsset_.erc20Tokens.length; i++) {
            ownerAssetVault_.transferERC20(strategy_, proofAsset_.erc20Tokens[i], proofAsset_.erc20Amounts[i]);
        }
        for (uint256 i = 0; i < proofAsset_.erc721Tokens.length; i++) {
            ownerAssetVault_.transferERC721(strategy_, proofAsset_.erc721Tokens[i], proofAsset_.erc721TokenIds[i]);
        }
        for (uint256 i = 0; i < proofAsset_.erc1155Tokens.length; i++) {
            ownerAssetVault_.transferERC1155(
                strategy_,
                proofAsset_.erc1155Tokens[i],
                proofAsset_.erc1155TokenIds[i],
                proofAsset_.erc1155TokenAmounts[i],
                data_
            );
        }
        IClaimAirdropStrategy(strategy_).claim(to_, data_);

        // Return assets to vault
        for (uint256 i = 0; i < proofAsset_.erc20Tokens.length; i++) {
            IERC20(proofAsset_.erc20Tokens[i]).safeTransferFrom(
                strategy_, address(ownerAssetVault_), proofAsset_.erc20Amounts[i]
            );
        }
        for (uint256 i = 0; i < proofAsset_.erc721Tokens.length; i++) {
            IERC721(proofAsset_.erc721Tokens[i]).safeTransferFrom(
                strategy_, address(ownerAssetVault_), proofAsset_.erc721TokenIds[i]
            );
        }
        for (uint256 i = 0; i < proofAsset_.erc1155Tokens.length; i++) {
            IERC1155(proofAsset_.erc1155Tokens[i]).safeTransferFrom(
                strategy_,
                address(ownerAssetVault_),
                proofAsset_.erc1155TokenIds[i],
                proofAsset_.erc1155TokenAmounts[i],
                data_
            );
        }
    }

    // High risk: Only use when absolutely necessary to claim airdrops within the vault context, use claimAirdrop for common cases
    function executeAirdrop(address to_, address strategy_, bytes memory data_)
        external
        override
        onlyExecuteAirdropStrategy(strategy_)
    {
        address owner_ = msg.sender;
        _getAssetVault(owner_).delegateCall(
            strategy_, abi.encodeWithSelector(IExecuteAirdropStrategy.execute.selector, to_, data_)
        );
    }
}
