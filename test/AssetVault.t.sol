// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IAssetVault} from "../src/interfaces/IAssetVault.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {MintableERC1155} from "./mock/MintableERC1155.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {MintableERC20} from "./mock/MintableERC20.sol";
import {IDelegateRegistryV2} from "../src/interfaces/IDelegateRegistryV2.sol";
import {InvalidAddress, InvalidERC721Owner, MissingStakedERC721} from "../src/interfaces/IErrors.sol";
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

        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
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

    function testTransferERC721_RevertNotOwner() public {
        vm.startPrank(delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.transferERC721(delegate, address(mockERC1155), 1);
        vm.stopPrank();
    }

    function testTransferERC20_RevertNotOwner() public {
        vm.startPrank(delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.transferERC20(delegate, address(mockERC20), 100);
        vm.stopPrank();
    }

    function testTransferERC1155_RevertNotOwner() public {
        vm.startPrank(delegate);
        uint256 id = 1;
        uint256 amount = 100;
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.transferERC1155(address(mockERC1155), delegate, id, amount, "");
        vm.stopPrank();
    }

    function testStakeERC721() public {
        uint256 tokenId = 1;
        // Mint the ERC721 NFT to the vault
        mockERC721.safeMint(address(vault), tokenId);
        assertEq(mockERC721.ownerOf(tokenId), address(vault));

        // Only owner can call stakeERC721
        vm.startPrank(owner);
        vault.stakeERC721(address(mockERC721), tokenId);
        vm.stopPrank();

        // Check that isERC721Staked returns true
        bool staked = vault.isERC721Staked(address(mockERC721), tokenId);
        assertTrue(staked);
    }

    function testStakeERC721_RevertNotOwner() public {
        uint256 tokenId = 1;
        mockERC721.safeMint(address(vault), tokenId);

        // Non-owner call should revert
        vm.startPrank(delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.stakeERC721(address(mockERC721), tokenId);
        vm.stopPrank();
    }

    function testStakeERC721_RevertNotOwnedByVault() public {
        uint256 tokenId = 1;
        // NFT not in vault
        mockERC721.mint(address(this), tokenId);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Owner.selector, address(mockERC721), tokenId));
        vault.stakeERC721(address(mockERC721), tokenId);
        vm.stopPrank();
    }

    function testUnstakeERC721() public {
        uint256 tokenId = 1;
        // First mint and stake
        mockERC721.safeMint(address(vault), tokenId);
        vm.startPrank(owner);
        vault.stakeERC721(address(mockERC721), tokenId);

        // First transfer out the NFT
        vault.transferERC721(owner, address(mockERC721), tokenId);
        assertEq(mockERC721.ownerOf(tokenId), owner);

        // Call unstakeERC721
        vault.unstakeERC721(address(mockERC721), tokenId);
        vm.stopPrank();

        // Check that isERC721Staked returns false
        bool staked = vault.isERC721Staked(address(mockERC721), tokenId);
        assertFalse(staked);
    }

    function testUnstakeERC721_RevertNotOwner() public {
        uint256 tokenId = 1;
        mockERC721.safeMint(address(vault), tokenId);
        vm.startPrank(owner);
        vault.stakeERC721(address(mockERC721), tokenId);
        vm.stopPrank();

        // Non-owner call should revert
        vm.startPrank(delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.unstakeERC721(address(mockERC721), tokenId);
        vm.stopPrank();
    }

    function testUnstakeERC721_RevertStillOwnedByVault() public {
        uint256 tokenId = 1;
        mockERC721.safeMint(address(vault), tokenId);
        vm.startPrank(owner);
        vault.stakeERC721(address(mockERC721), tokenId);

        // NFT still in vault, unstake should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Owner.selector, address(mockERC721), tokenId));
        vault.unstakeERC721(address(mockERC721), tokenId);
        vm.stopPrank();
    }

    function testTransferERC721() public {
        uint256 tokenId = 1;
        mockERC721.safeMint(address(vault), tokenId);
        assertEq(mockERC721.ownerOf(tokenId), address(vault));

        vm.startPrank(owner);
        vault.transferERC721(delegate, address(mockERC721), tokenId);
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(tokenId), delegate);
    }

    function testTransferERC20() public {
        uint256 amount = 100 ether;
        mockERC20.mint(address(vault), amount);
        assertEq(mockERC20.balanceOf(address(vault)), amount);

        vm.startPrank(owner);
        vault.transferERC20(delegate, address(mockERC20), amount);
        vm.stopPrank();

        assertEq(mockERC20.balanceOf(delegate), amount);
        assertEq(mockERC20.balanceOf(address(vault)), 0);
    }

    function testTransferERC1155() public {
        uint256 id = 1;
        uint256 amount = 100;

        mockERC1155.mint(address(vault), id, amount, "");
        assertEq(mockERC1155.balanceOf(address(vault), id), amount);

        vm.startPrank(owner);
        vault.transferERC1155(delegate, address(mockERC1155), id, amount, "");
        vm.stopPrank();

        assertEq(mockERC1155.balanceOf(delegate, id), amount);
        assertEq(mockERC1155.balanceOf(address(vault), id), 0);
    }

    function testDisableInitializers() public {
        vm.startPrank(owner);
        vault = new AssetVault();
        vault.disableInitializers();
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
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

    function testTransferNonStakedERC721() public {
        uint256 tokenId = 1;
        address recipient = makeAddr("recipient");

        // Mint ERC721 to vault
        mockERC721.safeMint(address(vault), tokenId);
        assertEq(mockERC721.ownerOf(tokenId), address(vault));

        // Only owner can call transferNonStakedERC721
        vm.startPrank(owner);
        vault.transferNonStakedERC721(recipient, address(mockERC721), tokenId);
        vm.stopPrank();

        // After transfer, recipient should own the token
        assertEq(mockERC721.ownerOf(tokenId), recipient);
    }

    function testTransferNonStakedERC721_RevertNotOwner() public {
        uint256 tokenId = 1;
        address recipient = makeAddr("recipient");

        mockERC721.safeMint(address(vault), tokenId);

        // Non-owner should revert
        vm.startPrank(delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.transferNonStakedERC721(recipient, address(mockERC721), tokenId);
        vm.stopPrank();
    }

    function testTransferNonStakedERC721_RevertIfStaked() public {
        uint256 tokenId = 1;
        address recipient = makeAddr("recipient");

        // Mint and stake the token
        mockERC721.safeMint(address(vault), tokenId);
        vm.startPrank(owner);
        vault.stakeERC721(address(mockERC721), tokenId);

        // Should revert due to keepStaked modifier
        vm.expectRevert(abi.encodeWithSelector(MissingStakedERC721.selector, address(mockERC721)));
        vault.transferNonStakedERC721(recipient, address(mockERC721), tokenId);
        vm.stopPrank();
    }

    function testDelegateCall_Success() public {
        address to = makeAddr("to");
        address mockDelegateCallContract = address(new MockDelegateCallContract());
        bytes memory data =
            abi.encodeWithSelector(MockDelegateCallContract.transferERC20.selector, to, address(mockERC20), 400);
        mockERC20.mint(address(vault), 1000);

        vm.startPrank(owner);
        vault.delegateCall(mockDelegateCallContract, data);
        assertEq(mockERC20.balanceOf(address(vault)), 600);
        assertEq(mockERC20.balanceOf(to), 400);
        vm.stopPrank();
    }

    function testDelegateCall_RevertNotOwner() public {
        address to = makeAddr("to");
        address mockDelegateCallContract = address(new MockDelegateCallContract());
        bytes memory data =
            abi.encodeWithSelector(MockDelegateCallContract.transferERC20.selector, to, address(mockERC20), 400);
        mockERC20.mint(address(vault), 1000);

        vm.startPrank(delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, delegate));
        vault.delegateCall(mockDelegateCallContract, data);
        vm.stopPrank();
    }

    function testDelegateCall_RevertKeepStaked() public {
        uint256 tokenId = 1;
        mockERC721.safeMint(address(vault), tokenId);
        vm.startPrank(owner);
        vault.stakeERC721(address(mockERC721), tokenId);

        MockDelegateCallFailContract failContract = new MockDelegateCallFailContract();
        bytes memory data = abi.encodeWithSelector(
            MockDelegateCallFailContract.transferStakedERC721.selector, address(this), address(mockERC721), tokenId
        );

        vm.expectRevert(abi.encodeWithSelector(MissingStakedERC721.selector, address(mockERC721)));
        vault.delegateCall(address(failContract), data);
        vm.stopPrank();
    }
}

contract MockDelegateCallContract {
    function transferERC20(address to, address token, uint256 amount) external {
        IERC20(token).transfer(to, amount);
    }
}

contract MockDelegateCallFailContract {
    function transferStakedERC721(address to, address token, uint256 tokenId) external {
        IERC721(token).transferFrom(address(this), to, tokenId);
    }
}
