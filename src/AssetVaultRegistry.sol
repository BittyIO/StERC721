// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";
import {IAssetVault} from "./interfaces/IAssetVault.sol";

contract AssetVaultRegistry is OwnableUpgradeable, ReentrancyGuardUpgradeable, IAssetVaultRegistry {
    using Clones for address;

    mapping(address => IAssetVault) private assetVaults;
    address public assetVaultImpl;
    address public delegationRegistryV2;

    function initialize(address assetVaultImpl_, address delegationRegistryV2_) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        assetVaultImpl = assetVaultImpl_;
        delegationRegistryV2 = delegationRegistryV2_;
    }

    function create(address for_) external override nonReentrant returns (IAssetVault) {
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
}
