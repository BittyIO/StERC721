// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {IAssetVault} from "../src/interfaces/IAssetVault.sol";

contract AssetVaultRegistryTest is Test {
    AssetVaultRegistry public registry;
    AssetVault public implementation;
    address public delegationRegistry;
    address public owner;
    address public caller;

    function setUp() public {
        owner = makeAddr("owner");
        caller = makeAddr("caller");
        delegationRegistry = makeAddr("delegationRegistry");

        vm.startPrank(owner);
        implementation = new AssetVault();
        registry = new AssetVaultRegistry();
        registry.initialize(address(implementation), delegationRegistry);
        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(registry.assetVaultImpl(), address(implementation));
        assertEq(registry.delegationRegistryV2(), delegationRegistry);
        assertEq(registry.owner(), owner);
    }

    function testCreate() public {
        vm.prank(caller);
        IAssetVault vault = registry.create(owner);
        assertEq(address(registry.get(owner)), address(vault));
        assertEq(vault.owner(), caller);
    }

    function testCreateWithZeroAddress() public {
        vm.expectRevert("AssetVaultRegistry: for is zero address");
        registry.create(address(0));
    }

    function testGet() public {
        IAssetVault vault = registry.create(owner);
        assertEq(address(registry.get(owner)), address(vault));
    }

    function testGetNonExistent() public view {
        assertEq(address(registry.get(owner)), address(0));
    }
}
