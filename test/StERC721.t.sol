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

    StERC721 public stERC721;
    AssetVaultRegistry public registry;
    AssetVault public implementation;
    MintableERC721 public mockERC721;
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

        mockERC721 = new MintableERC721("TestERC721", "TST721");

        stERC721 = new StERC721();
        stERC721.initialize("eth", mockERC721, registry, "Staked ERC721", "stERC721");
        registry.authorize(address(stERC721));

        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(address(stERC721.assetVaultRegistry()), address(registry));
        assertEq(stERC721.underlyingAsset(), address(mockERC721));
        assertEq(stERC721.owner(), owner);
    }

    function testMint() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721.mint(user, tokenId);
        mockERC721.setApprovalForAll(address(stERC721), true);

        stERC721.mint(tokenIds);

        assertEq(stERC721.ownerOf(tokenId), user);
        assertEq(mockERC721.ownerOf(tokenId), address(registry.get(user)));
        vm.stopPrank();
    }

    function testTransferFrom() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721.mint(user, tokenId);
        mockERC721.setApprovalForAll(address(stERC721), true);
        stERC721.mint(tokenIds);
        stERC721.safeTransferFrom(user, owner, tokenId);
        vm.stopPrank();

        address assetVault = address(registry.get(owner));
        assertEq(stERC721.ownerOf(tokenId), owner);
        assertEq(mockERC721.ownerOf(tokenId), assetVault);
    }

    function testBurn() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721.mint(user, tokenId);
        mockERC721.setApprovalForAll(address(stERC721), true);

        stERC721.mint(tokenIds);
        stERC721.burn(tokenIds);

        assertEq(mockERC721.ownerOf(tokenId), user);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));
        stERC721.ownerOf(tokenId);
        vm.stopPrank();
    }

    function testSetDelegateCashV2() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        bytes32 rights = bytes32("SOME_RIGHTS");

        vm.startPrank(user);
        mockERC721.mint(user, tokenId);
        mockERC721.setApprovalForAll(address(stERC721), true);

        stERC721.mint(tokenIds);
        bytes32 expectedDelegationHash = bytes32("DELEGATION_HASH");

        vm.mockCall(
            address(delegationRegistry),
            abi.encodeWithSelector(IDelegateRegistryV2.delegateERC721.selector),
            abi.encode(expectedDelegationHash)
        );
        bytes32[] memory delegationHashes = stERC721.setDelegateCashV2(delegate, tokenIds, rights, true);
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
        mockERC721.mint(user, tokenId);
        mockERC721.setApprovalForAll(address(stERC721), true);
        stERC721.mint(tokenIds);
        vm.stopPrank();

        assertEq(stERC721.tokenURI(tokenId), mockERC721.tokenURI(tokenId));

        vm.prank(owner);
        stERC721.setBaseURI("https://api.example.com/");
        assertEq(stERC721.tokenURI(tokenId), string.concat("https://api.example.com/", tokenId.toString()));
    }

    function testContractURI() public view {
        string memory expectedURI = string(
            abi.encodePacked(
                "https://metadata.bitty.io/eth/", Strings.toHexString(uint256(uint160(address(stERC721))), 20)
            )
        );
        assertEq(stERC721.contractURI(), expectedURI);
    }
}
