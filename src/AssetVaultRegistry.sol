// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";
import {IAssetVault} from "./interfaces/IAssetVault.sol";

contract AssetVaultRegistry is OwnableUpgradeable, IAssetVaultRegistry {
    using Clones for address;

    mapping(address => IAssetVault) private assetVaults;
    mapping(address => bool) public authorized;
    address public assetVaultImpl;
    address public delegationRegistryV2;

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "AssetVaultRegistry: caller is not authorized");
        _;
    }

    function disableInitializers() external override {
        _disableInitializers();
    }

    function initialize(address assetVaultImpl_, address delegationRegistryV2_) external override initializer {
        __Ownable_init(msg.sender);
        assetVaultImpl = assetVaultImpl_;
        delegationRegistryV2 = delegationRegistryV2_;
    }

    function authorize(address authorizedAddress_) external override onlyOwner {
        require(authorizedAddress_ != address(0), "AssetVaultRegistry: authorized address is zero address");
        authorized[authorizedAddress_] = true;
    }

    function create(address owner_) external override onlyAuthorized returns (address assetVault) {
        require(owner_ != address(0), "AssetVaultRegistry: owner is zero address");
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

    function get(address owner_) external view override returns (address assetVault) {
        return address(assetVaults[owner_]);
    }

    function setDelegateCashV2(
        address owner_,
        address delegate_,
        address erc721_,
        uint256 tokenId_,
        bytes32 rights_,
        bool value_
    ) external override onlyAuthorized returns (bytes32 delegationHash) {
        return assetVaults[owner_].setDelegateCashV2(delegate_, erc721_, tokenId_, rights_, value_);
    }

    function withdrawERC721(address owner_, address to_, address erc721_, uint256 tokenId_)
        external
        override
        onlyAuthorized
    {
        assetVaults[owner_].withdrawERC721(to_, erc721_, tokenId_);
    }
}
