// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {StERC721} from "../src/StERC721.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IDelegateRegistryV2} from "../src/interfaces/IDelegateRegistryV2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract StERC721Test is Test {
    using Strings for uint256;

    StERC721 public stERC721_A;
    StERC721 public stERC721_B;
    AssetVaultRegistry public registry;
    AssetVault public implementation;
    MintableERC721 public mockERC721_A;
    MintableERC721 public mockERC721_B;
    address public delegationRegistry;
    address public owner;
    address public user;
    address public delegate;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        delegationRegistry = makeAddr("delegationRegistry");
        delegate = makeAddr("delegate");
        vm.startPrank(owner);

        implementation = new AssetVault();
        registry = new AssetVaultRegistry();
        registry.initialize(address(implementation), delegationRegistry);

        mockERC721_A = new MintableERC721("TestERC721_A", "TST721A");
        mockERC721_B = new MintableERC721("TestERC721_B", "TST721B");
        stERC721_A = new StERC721();
        stERC721_A.initialize("eth", mockERC721_A, registry, "Staked ERC721", "stERC721_A");
        stERC721_B = new StERC721();
        stERC721_B.initialize("eth", mockERC721_B, registry, "Staked ERC721", "stERC721_B");
        registry.authorize(address(stERC721_A));
        registry.authorize(address(stERC721_B));

        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(address(stERC721_A.assetVaultRegistry()), address(registry));
        assertEq(stERC721_A.underlyingAsset(), address(mockERC721_A));
        assertEq(stERC721_A.owner(), owner);
    }

    function testMint() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);

        stERC721_A.mint(tokenIds);

        assertEq(stERC721_A.ownerOf(tokenId), user);
        assertEq(mockERC721_A.ownerOf(tokenId), address(registry.get(user)));
        vm.stopPrank();
    }

    function testTransferFrom() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        stERC721_A.mint(tokenIds);
        stERC721_A.safeTransferFrom(user, owner, tokenId);
        vm.stopPrank();

        address assetVault = address(registry.get(owner));
        assertEq(stERC721_A.ownerOf(tokenId), owner);
        assertEq(mockERC721_A.ownerOf(tokenId), assetVault);
    }

    function testBurn() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);

        stERC721_A.mint(tokenIds);
        stERC721_A.burn(tokenIds);

        assertEq(mockERC721_A.ownerOf(tokenId), user);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));
        stERC721_A.ownerOf(tokenId);
        vm.stopPrank();
    }

    function testSetDelegateCashV2() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        bytes32 rights = bytes32("SOME_RIGHTS");

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);

        stERC721_A.mint(tokenIds);
        bytes32 expectedDelegationHash = bytes32("DELEGATION_HASH");

        vm.mockCall(
            address(delegationRegistry),
            abi.encodeWithSelector(IDelegateRegistryV2.delegateERC721.selector),
            abi.encode(expectedDelegationHash)
        );
        bytes32[] memory delegationHashes = stERC721_A.setDelegateCashV2(delegate, tokenIds, rights, true);
        for (uint256 i = 0; i < delegationHashes.length; i++) {
            assertEq(delegationHashes[i], expectedDelegationHash);
        }
        vm.stopPrank();
    }

    function testTokenURI() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        stERC721_A.mint(tokenIds);
        vm.stopPrank();

        assertEq(stERC721_A.tokenURI(tokenId), mockERC721_A.tokenURI(tokenId));

        vm.prank(owner);
        stERC721_A.setBaseURI("https://api.example.com/");
        assertEq(stERC721_A.tokenURI(tokenId), string.concat("https://api.example.com/", tokenId.toString()));
    }

    function testContractURI() public view {
        string memory expectedURI = string(
            abi.encodePacked(
                "https://metadata.bitty.io/eth/", Strings.toHexString(uint256(uint160(address(stERC721_A))), 20)
            )
        );
        assertEq(stERC721_A.contractURI(), expectedURI);
    }

    function testTwoUsersMintThenBurn() public {
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;
        address user1 = address(0x1111);
        address user2 = address(0x2222);

        vm.startPrank(user1);
        mockERC721_A.mint(user1, tokenId1);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        uint256[] memory tokenIds1 = new uint256[](1);
        tokenIds1[0] = tokenId1;
        stERC721_A.mint(tokenIds1);
        vm.stopPrank();

        vm.startPrank(user2);
        mockERC721_A.mint(user2, tokenId2);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = tokenId2;
        stERC721_A.mint(tokenIds2);
        vm.stopPrank();

        assertEq(stERC721_A.ownerOf(tokenId1), user1);
        assertEq(stERC721_A.ownerOf(tokenId2), user2);

        vm.startPrank(user1);
        tokenIds1[0] = tokenId1;
        stERC721_A.burn(tokenIds1);
        vm.stopPrank();

        vm.expectRevert();
        stERC721_A.ownerOf(tokenId1);
        assertEq(stERC721_A.ownerOf(tokenId2), user2);

        vm.startPrank(user2);
        tokenIds2[0] = tokenId2;
        stERC721_A.burn(tokenIds2);
        vm.stopPrank();

        vm.expectRevert();
        stERC721_A.ownerOf(tokenId2);
    }

    function testMintAndBurnDifferentERC721() public {
        uint256 tokenIdA = 10;
        uint256 tokenIdB = 20;

        // 用户地址
        address testUser = address(0x3333);

        // mint mockERC721_A
        vm.startPrank(testUser);
        mockERC721_A.mint(testUser, tokenIdA);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        uint256[] memory tokenIdsA = new uint256[](1);
        tokenIdsA[0] = tokenIdA;
        stERC721_A.mint(tokenIdsA);
        assertEq(stERC721_A.ownerOf(tokenIdA), testUser);
        assertEq(mockERC721_A.ownerOf(tokenIdA), address(registry.get(testUser)));
        vm.stopPrank();

        // mint mockERC721_B
        vm.startPrank(testUser);
        mockERC721_B.mint(testUser, tokenIdB);
        mockERC721_B.setApprovalForAll(address(stERC721_B), true);
        uint256[] memory tokenIdsB = new uint256[](1);
        tokenIdsB[0] = tokenIdB;
        stERC721_B.mint(tokenIdsB);
        assertEq(stERC721_B.ownerOf(tokenIdB), testUser);
        assertEq(mockERC721_B.ownerOf(tokenIdB), address(registry.get(testUser)));
        vm.stopPrank();

        // burn mockERC721_A
        vm.startPrank(testUser);
        stERC721_A.burn(tokenIdsA);
        vm.stopPrank();
        vm.expectRevert();
        stERC721_A.ownerOf(tokenIdA);

        // burn mockERC721_B
        vm.startPrank(testUser);
        stERC721_B.burn(tokenIdsB);
        vm.stopPrank();
        vm.expectRevert();
        stERC721_B.ownerOf(tokenIdB);
    }
}
