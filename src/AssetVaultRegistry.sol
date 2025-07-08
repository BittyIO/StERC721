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
        require(authorized[msg.sender], "AssetVaultRegistry: not authorized");
        _;
    }

    function initialize(address assetVaultImpl_, address delegationRegistryV2_) external initializer {
        __Ownable_init(msg.sender);
        assetVaultImpl = assetVaultImpl_;
        delegationRegistryV2 = delegationRegistryV2_;
    }

    function authorize(address authorizedAddress_) external override onlyOwner {
        require(authorizedAddress_ != address(0), "AssetVaultRegistry: authorized address is zero address");
        authorized[authorizedAddress_] = true;
    }

    function create(address for_) external override onlyAuthorized returns (IAssetVault) {
        address owner_ = msg.sender;
        require(for_ != address(0), "AssetVaultRegistry: for is zero address");
        IAssetVault assetVault_ = assetVaults[for_];
        if (address(assetVault_) == address(0)) {
            assetVault_ = IAssetVault(assetVaultImpl.clone());
            assetVault_.initialize(owner_, delegationRegistryV2);
        }
        assetVaults[for_] = assetVault_;
        return assetVault_;
    }

    function get(address owner_) external view override returns (IAssetVault) {
        return assetVaults[owner_];
    }

    function isAuthorized(address authorizedAddress_) external view returns (bool) {
        return authorized[authorizedAddress_];
    }
}
