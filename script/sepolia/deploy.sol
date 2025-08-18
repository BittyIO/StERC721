// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "@openzeppelin-foundry-upgrades/Options.sol";

import {AssetVaultRegistry} from "../../src/AssetVaultRegistry.sol";
import {IAssetVaultRegistry} from "../../src/interfaces/IAssetVaultRegistry.sol";
import {WrappedERC721Registry} from "../../src/WrappedERC721Registry.sol";
import {IWrappedERC721Registry} from "../../src/interfaces/IWrappedERC721Registry.sol";
import {IWrappedERC721} from "../../src/interfaces/IWrappedERC721.sol";
import {IAssetVault} from "../../src/interfaces/IAssetVault.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract DeployScript is Script {
    address public constant INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN = 0x68e9f64887d634250B4Da6965b6802039Fe89934;
    address public constant DELEGATION_REGISTRY_V2 = 0x00000000000000447e69651d841bD8D104Bed493;

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
        Options memory opts;
        address assetVaultImpl = Upgrades.deployImplementation("AssetVault.sol", opts);
        address assetVaultRegistry = Upgrades.deployTransparentProxy(
            "AssetVaultRegistry.sol",
            INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            abi.encodeCall(IAssetVaultRegistry.initialize, (assetVaultImpl, DELEGATION_REGISTRY_V2))
        );
        address wrappedERC721Registry = Upgrades.deployTransparentProxy(
            "WrappedERC721Registry.sol",
            INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            abi.encodeCall(IWrappedERC721Registry.initialize, ("eth", IAssetVaultRegistry(assetVaultRegistry)))
        );
        OwnableUpgradeable(assetVaultRegistry).transferOwnership(wrappedERC721Registry);
        address wrappedERC721Impl = Upgrades.deployImplementation("WrappedERC721.sol", opts);
        vm.stopBroadcast();
        console2.log("assetVaultImpl", assetVaultImpl);
        console2.log("wrappedERC721Impl", wrappedERC721Impl);
        console2.log("assetVaultRegistry", assetVaultRegistry);
        console2.log("wrappedERC721Registry", wrappedERC721Registry);
    }
}
