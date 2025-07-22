// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {IAssetVault} from "../src/interfaces/IAssetVault.sol";

contract AssetVaultRegistryTest is Test {
    AssetVaultRegistry public registry;
    AssetVault public implementation;
    address public delegationRegistry;
    address public owner;
    address public authorizedAddress;

    function setUp() public {
        owner = makeAddr("owner");
        authorizedAddress = makeAddr("authorizedAddress");
        delegationRegistry = makeAddr("delegationRegistry");
        vm.startPrank(owner);
        implementation = new AssetVault();
        registry = new AssetVaultRegistry();
        registry.initialize(address(implementation), delegationRegistry);
        registry.authorize(authorizedAddress);
        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(registry.assetVaultImpl(), address(implementation));
        assertEq(registry.delegationRegistryV2(), delegationRegistry);
        assertEq(registry.owner(), owner);
    }

    function testAuthorize() public view {
        assertEq(registry.isAuthorized(authorizedAddress), true);
    }

    function testAuthorizeNotOwner() public {
        vm.prank(authorizedAddress);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, authorizedAddress)
        );
        registry.authorize(authorizedAddress);
    }

    function testCreate() public {
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);
        assertEq(address(registry.get(owner)), address(vault));
        assertEq(IAssetVault(vault).owner(), address(registry));
    }

    function testCreateWithZeroAddress() public {
        vm.prank(authorizedAddress);
        vm.expectRevert("AssetVaultRegistry: owner is zero address");
        registry.create(address(0));
    }

    function testGet() public {
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);
        assertEq(address(registry.get(owner)), address(vault));
    }

    function testGetNonExistent() public view {
        assertEq(address(registry.get(owner)), address(0));
    }

    function testAuthorizeZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("AssetVaultRegistry: authorized address is zero address");
        registry.authorize(address(0));
    }
}
