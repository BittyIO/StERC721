// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {AssetVault} from "../src/AssetVault.sol";
import {MintableERC1155} from "./mock/MintableERC1155.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {MintableERC20} from "./mock/MintableERC20.sol";
import {IDelegateRegistryV2} from "../src/interfaces/IDelegateRegistryV2.sol";

contract AssetVaultTest is Test {
    AssetVault public vault;
    MintableERC1155 public mockERC1155;
    MintableERC20 public mockERC20;
    MintableERC721 public mockERC721;
    address public delegationRegistry;
    address public owner;
    address public delegate;

    function setUp() public {
        owner = makeAddr("owner");
        delegate = makeAddr("delegate");
        delegationRegistry = makeAddr("delegationRegistry");

        vm.startPrank(owner);
        vault = new AssetVault();
        vault.initialize(owner, delegationRegistry);

        mockERC1155 = new MintableERC1155("https://test.uri/");
        mockERC20 = new MintableERC20("TestERC20", "TST20", 18);
        mockERC721 = new MintableERC721("TestERC721", "TST721");

        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(address(vault.delegationRegistryV2()), delegationRegistry);
        assertEq(vault.owner(), owner);
    }

    function testSetDelegateCashV2() public {
        vm.startPrank(owner);
        uint256 tokenId = 1;
        bytes32 rights = bytes32("SOME_RIGHTS");
        bytes32 expectedDelegationHash = bytes32("DELEGATION_HASH");

        vm.mockCall(
            delegationRegistry,
            abi.encodeWithSelector(IDelegateRegistryV2.delegateERC721.selector),
            abi.encode(expectedDelegationHash)
        );

        bytes32 delegationHash = vault.setDelegateCashV2(delegate, address(mockERC1155), tokenId, rights, true);

        assertEq(delegationHash, expectedDelegationHash);
        vm.stopPrank();
    }

    function testSetDelegateCashV2_RevertInvalidDelegate() public {
        vm.startPrank(owner);
        uint256 tokenId = 1;
        bytes32 rights = bytes32("SOME_RIGHTS");

        vm.expectRevert("AssetVault: invalid delegate");
        vault.setDelegateCashV2(address(0), address(mockERC1155), tokenId, rights, true);
        vm.stopPrank();
    }

    function testSetDelegateCashV2_RevertNotOwner() public {
        vm.startPrank(delegate);
        uint256 tokenId = 1;
        bytes32 rights = bytes32("SOME_RIGHTS");

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.setDelegateCashV2(delegate, address(mockERC1155), tokenId, rights, true);
        vm.stopPrank();
    }

    function testWithdrawERC721_RevertNotOwner() public {
        vm.startPrank(delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.withdrawERC721(delegate, address(mockERC1155), 1);
        vm.stopPrank();
    }

    function testWithdrawERC20_RevertNotOwner() public {
        vm.startPrank(delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.withdrawERC20(delegate, address(mockERC20), 100);
        vm.stopPrank();
    }

    function testWithdrawERC1155_RevertNotOwner() public {
        vm.startPrank(delegate);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 1;
        amounts[0] = 100;
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.withdrawERC1155(address(mockERC1155), delegate, ids, amounts, "");
        vm.stopPrank();
    }

    function testWithdrawERC721() public {
        uint256 tokenId = 1;
        mockERC721.mint(address(vault), tokenId);
        assertEq(mockERC721.ownerOf(tokenId), address(vault));

        vm.startPrank(owner);
        vault.withdrawERC721(delegate, address(mockERC721), tokenId);
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(tokenId), delegate);
    }

    function testWithdrawERC20() public {
        uint256 amount = 100 ether;
        mockERC20.mint(address(vault), amount);
        assertEq(mockERC20.balanceOf(address(vault)), amount);

        vm.startPrank(owner);
        vault.withdrawERC20(delegate, address(mockERC20), amount);
        vm.stopPrank();

        assertEq(mockERC20.balanceOf(delegate), amount);
        assertEq(mockERC20.balanceOf(address(vault)), 0);
    }

    function testWithdrawERC1155() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        mockERC1155.mintBatch(address(vault), ids, amounts, "");
        assertEq(mockERC1155.balanceOf(address(vault), ids[0]), amounts[0]);
        assertEq(mockERC1155.balanceOf(address(vault), ids[1]), amounts[1]);

        vm.startPrank(owner);
        vault.withdrawERC1155(address(mockERC1155), delegate, ids, amounts, "");
        vm.stopPrank();

        assertEq(mockERC1155.balanceOf(delegate, ids[0]), amounts[0]);
        assertEq(mockERC1155.balanceOf(delegate, ids[1]), amounts[1]);
        assertEq(mockERC1155.balanceOf(address(vault), ids[0]), 0);
        assertEq(mockERC1155.balanceOf(address(vault), ids[1]), 0);
    }
}
