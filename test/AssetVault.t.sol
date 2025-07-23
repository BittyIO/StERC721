// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IAssetVault} from "../src/interfaces/IAssetVault.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {MintableERC1155} from "./mock/MintableERC1155.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {MintableERC20} from "./mock/MintableERC20.sol";
import {IDelegateRegistryV2} from "../src/interfaces/IDelegateRegistryV2.sol";

import {console} from "forge-std/console.sol";

contract AssetVaultTest is Test {
    using Clones for address;

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

    function testCloneGas() public {
        uint256 gasBefore = gasleft();
        address(vault).clone();
        uint256 gasAfter = gasleft();
        console.log("Gas used:", gasBefore - gasAfter);
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

    function testDisableInitializers() public {
        vm.startPrank(owner);
        vault.disableInitializers();
        vm.expectRevert();
        vault.initialize(owner, delegate);
        vm.stopPrank();
    }

    function testSupportsInterface() public view {
        // IAssetVault interfaceId
        bytes4 iAssetVaultInterfaceId = type(IAssetVault).interfaceId;
        // IERC721Receiver interfaceId
        bytes4 iERC721ReceiverInterfaceId = type(IERC721Receiver).interfaceId;
        // IERC1155Receiver interfaceId
        bytes4 iERC1155ReceiverInterfaceId = type(IERC1155Receiver).interfaceId;
        // Random unsupported interfaceId
        bytes4 randomInterfaceId = 0x12345678;

        assertTrue(vault.supportsInterface(iAssetVaultInterfaceId), "should support IAssetVault interface");
        assertTrue(vault.supportsInterface(iERC721ReceiverInterfaceId), "should support IERC721Receiver interface");
        assertTrue(vault.supportsInterface(iERC1155ReceiverInterfaceId), "should support IERC1155Receiver interface");
        assertFalse(vault.supportsInterface(randomInterfaceId), "should not support unknown interface");
    }

    function testGetDelegateCashForTokenV2() public {
        address erc721 = address(mockERC721);
        uint256 tokenId = 1;

        address[] memory delegates = new address[](2);
        delegates[0] = makeAddr("delegate1");
        delegates[1] = makeAddr("delegate2");

        IDelegateRegistryV2.Delegation[] memory delegations = new IDelegateRegistryV2.Delegation[](2);
        delegations[0] = IDelegateRegistryV2.Delegation({
            type_: IDelegateRegistryV2.DelegationType.ERC721,
            contract_: erc721,
            tokenId: tokenId,
            to: delegates[0],
            from: address(vault),
            rights: bytes32(""),
            amount: 0
        });
        delegations[1] = IDelegateRegistryV2.Delegation({
            type_: IDelegateRegistryV2.DelegationType.ERC721,
            contract_: erc721,
            tokenId: tokenId,
            to: delegates[1],
            from: address(vault),
            rights: bytes32(""),
            amount: 0
        });

        bytes memory returnData = abi.encode(delegations);
        vm.mockCall(
            delegationRegistry,
            abi.encodeWithSelector(IDelegateRegistryV2.getOutgoingDelegations.selector, address(vault)),
            returnData
        );

        address[] memory result = vault.getDelegateCashForTokenV2(erc721, tokenId);

        assertEq(result.length, 2);
        assertEq(result[0], delegates[0]);
        assertEq(result[1], delegates[1]);
    }
}
