// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {IAssetVault} from "../src/interfaces/IAssetVault.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {IDelegateRegistryV2} from "../src/interfaces/IDelegateRegistryV2.sol";

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

    function testDisableInitializers() public {
        vm.prank(owner);
        AssetVaultRegistry registry1 = new AssetVaultRegistry();
        registry1.disableInitializers();
        vm.expectRevert();
        registry1.initialize(address(implementation), delegationRegistry);
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

    function testCreateWithNonAuthorizedOwner() public {
        address nonAuthorized = address(0x1234);
        vm.prank(nonAuthorized);
        vm.expectRevert("AssetVaultRegistry: caller is not authorized");
        registry.create(owner);
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

    function testWithdrawERC721WithOnlyAuthorizedOwner() public {
        // First, create an asset vault by the authorized address
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);

        // owner mint an NFT and transfer it to the asset vault
        uint256 tokenId = 1;
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        mockERC721.mint(owner, tokenId);

        // owner approve the asset vault to transfer the NFT
        vm.startPrank(owner);
        mockERC721.approve(vault, tokenId);
        // the asset vault receive the NFT
        mockERC721.transferFrom(owner, vault, tokenId);
        vm.stopPrank();

        // check the NFT is in the asset vault
        assertEq(mockERC721.ownerOf(tokenId), vault);

        // check a non-authorized address cannot call withdrawERC721
        address nonAuthorized = address(0x1234);
        vm.prank(nonAuthorized);
        vm.expectRevert("AssetVaultRegistry: caller is not authorized");
        registry.withdrawERC721(owner, owner, address(mockERC721), tokenId);

        // the authorized address call withdrawERC721, transfer the NFT back to owner
        vm.prank(authorizedAddress);
        registry.withdrawERC721(owner, owner, address(mockERC721), tokenId);

        // check the NFT is back to owner
        assertEq(mockERC721.ownerOf(tokenId), owner);
    }

    function testSetDelegateCashV2WithOnlyAuthorizedOwner() public {
        // Create an asset vault by the authorized address
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);

        // Prepare a MintableERC721 and mint a token to the vault
        uint256 tokenId = 1;
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        mockERC721.mint(vault, tokenId);

        // Prepare rights and expected delegation hash
        bytes32 rights = bytes32("SOME_RIGHTS");
        address delegate = makeAddr("delegate");

        // The authorized address calls setDelegateCashV2 on the registry

        bytes32 expectedDelegationHash = bytes32("DELEGATION_HASH");
        vm.mockCall(
            delegationRegistry,
            abi.encodeWithSelector(IDelegateRegistryV2.delegateERC721.selector),
            abi.encode(expectedDelegationHash)
        );
        vm.prank(authorizedAddress);
        registry.setDelegateCashV2(owner, delegate, address(mockERC721), tokenId, rights, true);

        // Check that a non-authorized address cannot call setDelegateCashV2
        address nonAuthorized = address(0x1234);
        vm.prank(nonAuthorized);
        vm.expectRevert("AssetVaultRegistry: caller is not authorized");
        registry.setDelegateCashV2(owner, delegate, address(mockERC721), tokenId, rights, true);
    }
}
