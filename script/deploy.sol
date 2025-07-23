// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {IAssetVaultRegistry} from "../src/interfaces/IAssetVaultRegistry.sol";
import {StERC721Registry} from "../src/StERC721Registry.sol";
import {IStERC721Registry} from "../src/interfaces/IStERC721Registry.sol";
import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "@openzeppelin-foundry-upgrades/Options.sol";

contract DeployScript is Script {
    address public constant INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN = 0x68e9f64887d634250B4Da6965b6802039Fe89934;
    address public constant DELEGATION_REGISTRY_V2 = 0x00000000000000447e69651d841bD8D104Bed493;

    function run() public {
        vm.startBroadcast();
        Options memory opts;
        address assetVaultImpl = Upgrades.deployImplementation("AssetVault.sol", opts);
        address assetVaultRegistry = Upgrades.deployTransparentProxy(
            "AssetVaultRegistry.sol",
            INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            abi.encodeCall(IAssetVaultRegistry.initialize, (assetVaultImpl, DELEGATION_REGISTRY_V2))
        );

        address stERC721Registry = Upgrades.deployTransparentProxy(
            "StERC721Registry.sol",
            INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            abi.encodeCall(IStERC721Registry.initialize, ("eth", IAssetVaultRegistry(assetVaultRegistry)))
        );
        console2.log("assetVaultImpl", assetVaultImpl);
        console2.log("assetVaultRegistry", assetVaultRegistry);
        console2.log("stERC721Registry", stERC721Registry);
        vm.stopBroadcast();
    }
}
