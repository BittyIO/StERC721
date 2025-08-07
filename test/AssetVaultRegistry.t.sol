// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {IAssetVault} from "../src/interfaces/IAssetVault.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {MintableERC20} from "./mock/MintableERC20.sol";
import {MintableERC1155} from "./mock/MintableERC1155.sol";
import {IDelegateRegistryV2} from "../src/interfaces/IDelegateRegistryV2.sol";
import {MockAirdropContractForCurrentOwner} from "./mock/MockAirdropContract.sol";
import {MockClaimAirdropStrategy} from "./mock/MockClaimAirdropStrategy.sol";
import {MockExecuteAirdropStrategy} from "./mock/MockExecuteAirdropStrategy.sol";
import {MockAirdropContractForFixedOwner} from "./mock/MockAirdropContract.sol";
import {MissingStakedERC721} from "../src/interfaces/IErrors.sol";

import {
    InvalidAddress,
    InvalidCaller,
    InvalidStrategy,
    AssetVaultNotFound,
    InvalidProofAsset
} from "../src/interfaces/IErrors.sol";

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

    function testRevokeAuthorization() public {
        vm.prank(owner);
        registry.revokeAuthorize(authorizedAddress);
        assertEq(registry.isAuthorized(authorizedAddress), false);
    }

    function testCreate() public {
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);
        assertEq(address(registry.getAssetVault(owner)), address(vault));
        assertEq(IAssetVault(vault).owner(), address(registry));
    }

    function testCreateWithZeroAddress() public {
        vm.prank(authorizedAddress);
        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
        registry.create(address(0));
    }

    function testCreateWithNonAuthorizedOwner() public {
        address nonAuthorized = address(0x1234);
        vm.prank(nonAuthorized);
        vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, nonAuthorized));
        registry.create(owner);
    }

    function testGetAssetVault() public {
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);
        assertEq(address(registry.getAssetVault(owner)), address(vault));
    }

    function testGetNonExistentAssetVault() public {
        vm.expectRevert(abi.encodeWithSelector(AssetVaultNotFound.selector, owner));
        registry.getAssetVault(owner);
    }

    function testAuthorizeZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
        registry.authorize(address(0));
    }

    function testTransferERC721ByRegistry() public {
        // Create two owners and their asset vaults
        address owner1 = owner;
        address owner2 = address(0xBEEF);
        vm.prank(authorizedAddress);
        address vault1 = registry.create(owner1);

        // Mint an ERC721 NFT to owner1
        uint256 tokenId = 42;
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        mockERC721.mint(owner1, tokenId);

        // Owner1 approves vault1 to receive the NFT and transfers it in
        vm.startPrank(owner1);
        mockERC721.approve(vault1, tokenId);
        mockERC721.transferFrom(owner1, vault1, tokenId);
        vm.stopPrank();

        // Stake the NFT in vault1 via registry (only authorized can call)
        vm.prank(authorizedAddress);
        registry.stakedERC721(owner1, address(mockERC721), tokenId);

        // Check that the NFT is staked in vault1
        assertTrue(IAssetVault(vault1).isERC721Staked(address(mockERC721), tokenId));

        // Transfer the NFT from owner1's vault to owner2's vault via registry
        vm.prank(authorizedAddress);
        registry.transferERC721(owner1, owner2, address(mockERC721), tokenId);

        address vault2 = registry.getAssetVault(owner2);
        // After transfer, NFT should be owned by vault2
        assertEq(mockERC721.ownerOf(tokenId), vault2);

        // The NFT should be marked as staked in vault2
        assertTrue(IAssetVault(vault2).isERC721Staked(address(mockERC721), tokenId));

        // The NFT should no longer be marked as staked in vault1
        assertFalse(IAssetVault(vault1).isERC721Staked(address(mockERC721), tokenId));
    }

    function testTransferERC721ByRegistry_RevertNotAuthorized() public {
        // Create two owners and their asset vaults
        address owner1 = owner;
        address owner2 = address(0xBEEF);
        vm.prank(authorizedAddress);
        address vault1 = registry.create(owner1);

        // Mint an ERC721 NFT to owner1
        uint256 tokenId = 99;
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        mockERC721.mint(owner1, tokenId);

        // Owner1 approves vault1 to receive the NFT and transfers it in
        vm.startPrank(owner1);
        mockERC721.approve(vault1, tokenId);
        mockERC721.transferFrom(owner1, vault1, tokenId);
        vm.stopPrank();

        // Stake the NFT in vault1 via registry (only authorized can call)
        vm.prank(authorizedAddress);
        registry.stakedERC721(owner1, address(mockERC721), tokenId);

        // Try to transfer the NFT from owner1's vault to owner2's vault via a non-authorized address
        address nonAuthorized = address(0x1234);
        vm.prank(nonAuthorized);
        vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, nonAuthorized));
        registry.transferERC721(owner1, owner2, address(mockERC721), tokenId);
    }

    function testStakedERC721WithOnlyAuthorizedOwner() public {
        // Create an asset vault by the authorized address
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);

        // Mint an ERC721 NFT to the owner
        uint256 tokenId = 1;
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        mockERC721.mint(owner, tokenId);

        // Owner approves the asset vault to receive the NFT
        vm.startPrank(owner);
        mockERC721.approve(vault, tokenId);
        // Transfer the NFT to the asset vault
        mockERC721.transferFrom(owner, vault, tokenId);
        vm.stopPrank();

        // Check the NFT is in the asset vault
        assertEq(mockERC721.ownerOf(tokenId), vault);

        // Non-authorized address cannot call stakedERC721
        address nonAuthorized = address(0x1234);
        vm.prank(nonAuthorized);
        vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, nonAuthorized));
        registry.stakedERC721(owner, address(mockERC721), tokenId);

        // The authorized address calls stakedERC721, staking the NFT
        vm.prank(authorizedAddress);
        registry.stakedERC721(owner, address(mockERC721), tokenId);

        // Check that the NFT is marked as staked in the asset vault
        assertTrue(IAssetVault(vault).isERC721Staked(address(mockERC721), tokenId));
    }

    function testUnstakeERC721WithOnlyAuthorizedOwner() public {
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
        vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, nonAuthorized));
        registry.unstakeERC721(owner, owner, address(mockERC721), tokenId);

        // the authorized address call withdrawERC721, transfer the NFT back to owner
        vm.prank(authorizedAddress);
        registry.unstakeERC721(owner, owner, address(mockERC721), tokenId);

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
        vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, nonAuthorized));
        registry.setDelegateCashV2(owner, delegate, address(mockERC721), tokenId, rights, true);
    }

    function testClaimERC20() public {
        // Create an asset vault by the authorized address
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);

        // Mint ERC20 tokens to the vault
        uint256 amount = 1000;
        MintableERC20 mockERC20 = new MintableERC20("TestERC20", "T20", 18);
        mockERC20.mint(vault, amount);

        // The owner claims ERC20 tokens from the vault
        address recipient = makeAddr("recipient");
        vm.prank(owner);
        registry.claimERC20(recipient, address(mockERC20), amount);

        // Check the recipient received the tokens
        assertEq(mockERC20.balanceOf(recipient), amount);
    }

    function testClaimERC721_StakedAndNonStaked() public {
        // Create an asset vault by the authorized address
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);

        // Mint two ERC721 tokens to the vault
        uint256 tokenIdNonStaked = 1;
        uint256 tokenIdStaked = 2;
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        mockERC721.mint(vault, tokenIdNonStaked);
        mockERC721.mint(vault, tokenIdStaked);

        // Stake tokenIdStaked in the vault via registry (only authorized can call)
        vm.prank(authorizedAddress);
        registry.stakedERC721(owner, address(mockERC721), tokenIdStaked);

        // The owner claims the non-staked ERC721 token from the vault
        address recipient = makeAddr("recipient");
        vm.prank(owner);
        registry.claimERC721(recipient, address(mockERC721), tokenIdNonStaked);

        // Check the recipient received the non-staked NFT
        assertEq(mockERC721.ownerOf(tokenIdNonStaked), recipient);

        // The owner tries to claim the staked ERC721 token from the vault, should revert
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MissingStakedERC721.selector, address(mockERC721)));
        registry.claimERC721(recipient, address(mockERC721), tokenIdStaked);
    }

    function testClaimERC1155() public {
        // Create an asset vault by the authorized address
        vm.prank(authorizedAddress);
        address vault = registry.create(owner);

        // Mint ERC1155 tokens to the vault
        uint256 tokenId = 1;
        uint256 amount = 100;
        MintableERC1155 mockERC1155 = new MintableERC1155("https://test.uri/");
        mockERC1155.mint(vault, tokenId, amount, "");
        assertEq(mockERC1155.balanceOf(vault, tokenId), amount);

        // The owner claims ERC1155 tokens from the vault
        address recipient = makeAddr("recipient");
        bytes memory data = "";
        vm.prank(owner);
        registry.claimERC1155(recipient, address(mockERC1155), tokenId, amount, data);

        // Check the recipient received the tokens
        assertEq(mockERC1155.balanceOf(recipient, tokenId), amount);
    }

    function testAddClaimAirdropStrategy() public {
        // Test that only the owner can add a claim airdrop strategy
        address strategy = makeAddr("strategy");
        // Non-owner should revert
        vm.prank(address(0x1234));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(0x1234)));
        registry.addClaimAirdropStrategy(strategy);

        // Zero address should revert
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
        registry.addClaimAirdropStrategy(address(0));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidStrategy.selector, strategy));
        registry.addClaimAirdropStrategy(strategy);

        // Deploy a valid mock strategy
        MintableERC20 mockERC20 = new MintableERC20("TestToken", "TT", 18);
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        MintableERC1155 mockERC1155 = new MintableERC1155("https://test.uri/");
        MockAirdropContractForCurrentOwner airdropContract = new MockAirdropContractForCurrentOwner(
            address(mockERC721), address(mockERC20), address(mockERC1155), address(mockERC721)
        );
        address[] memory erc20ProofTokens = new address[](1);
        erc20ProofTokens[0] = address(mockERC20);
        address[] memory erc721ProofTokens = new address[](1);
        erc721ProofTokens[0] = address(mockERC721);
        address[] memory erc1155ProofTokens = new address[](1);
        erc1155ProofTokens[0] = address(mockERC1155);

        MockClaimAirdropStrategy validStrategy = new MockClaimAirdropStrategy(
            airdropContract, address(registry), erc20ProofTokens, erc721ProofTokens, erc1155ProofTokens
        );

        // Owner can add valid strategy
        vm.prank(owner);
        registry.addClaimAirdropStrategy(address(validStrategy));
        // No revert means success
    }

    function testRemoveClaimAirdropStrategy() public {
        // Only owner can remove a claim airdrop strategy
        MintableERC20 mockERC20 = new MintableERC20("TestToken", "TT", 18);
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        MintableERC1155 mockERC1155 = new MintableERC1155("https://test.uri/");
        MockAirdropContractForCurrentOwner airdropContract = new MockAirdropContractForCurrentOwner(
            address(mockERC721), address(mockERC20), address(mockERC1155), address(mockERC721)
        );
        address[] memory erc20ProofTokens = new address[](1);
        erc20ProofTokens[0] = address(mockERC20);
        address[] memory erc721ProofTokens = new address[](1);
        erc721ProofTokens[0] = address(mockERC721);
        address[] memory erc1155ProofTokens = new address[](1);
        erc1155ProofTokens[0] = address(mockERC1155);

        MockClaimAirdropStrategy validStrategy = new MockClaimAirdropStrategy(
            airdropContract, address(registry), erc20ProofTokens, erc721ProofTokens, erc1155ProofTokens
        );

        vm.prank(owner);
        registry.addClaimAirdropStrategy(address(validStrategy));

        vm.prank(address(0x1234));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(0x1234)));
        registry.removeClaimAirdropStrategy(address(validStrategy));

        vm.prank(owner);
        registry.removeClaimAirdropStrategy(address(validStrategy));
    }

    function testClaimAirdropWithMockStrategy() public {
        // Create an asset vault by the authorized address
        address user = makeAddr("user");
        vm.prank(authorizedAddress);
        address vault = registry.create(user);

        address recipient = makeAddr("recipient");

        // Deploy a mock ERC20, ERC721, and ERC1155 token
        MintableERC20 mockERC20 = new MintableERC20("TestToken", "TT", 18);
        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        MintableERC1155 mockERC1155 = new MintableERC1155("https://test.uri/");
        MintableERC721 mockERC721Airdrop = new MintableERC721("TestAirdrop", "TA");

        // Mint assets to the vault
        uint256 erc20Amount = 1000;
        uint256 erc721TokenId = 1;
        uint256 erc1155TokenId = 1;
        uint256 erc721AirdropTokenId = 1;
        uint256 erc1155Amount = 10;

        mockERC20.mint(vault, erc20Amount);
        mockERC721.mint(vault, erc721TokenId);
        mockERC1155.mint(vault, erc1155TokenId, erc1155Amount, "");

        // Deploy a mock airdrop contract and strategy
        MockAirdropContractForCurrentOwner airdropContract = new MockAirdropContractForCurrentOwner(
            address(mockERC721), address(mockERC20), address(mockERC1155), address(mockERC721Airdrop)
        );

        address[] memory erc20ProofTokens = new address[](1);
        erc20ProofTokens[0] = address(mockERC20);
        address[] memory erc721ProofTokens = new address[](1);
        erc721ProofTokens[0] = address(mockERC721);
        address[] memory erc1155ProofTokens = new address[](1);
        erc1155ProofTokens[0] = address(mockERC1155);

        MockClaimAirdropStrategy strategy = new MockClaimAirdropStrategy(
            airdropContract, address(registry), erc20ProofTokens, erc721ProofTokens, erc1155ProofTokens
        );

        vm.prank(owner);
        registry.addClaimAirdropStrategy(address(strategy));

        bytes memory data = abi.encode(erc721AirdropTokenId);

        // Prepare proofAsset struct
        AssetVaultRegistry.ProofAsset memory proofAsset;
        proofAsset.erc20Tokens = new address[](1);
        proofAsset.erc20Tokens[0] = address(mockERC20);

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(InvalidProofAsset.selector));
        registry.claimAirdrop(recipient, address(strategy), proofAsset, data);

        proofAsset.erc20Amounts = new uint256[](1);
        proofAsset.erc20Amounts[0] = erc20Amount;

        proofAsset.erc721Tokens = new address[](1);
        proofAsset.erc721Tokens[0] = address(mockERC721);

        vm.expectRevert(abi.encodeWithSelector(InvalidProofAsset.selector));
        registry.claimAirdrop(recipient, address(strategy), proofAsset, data);
        proofAsset.erc721TokenIds = new uint256[](1);
        proofAsset.erc721TokenIds[0] = erc721TokenId;

        proofAsset.erc1155Tokens = new address[](1);
        proofAsset.erc1155Tokens[0] = address(mockERC1155);

        vm.expectRevert(abi.encodeWithSelector(InvalidProofAsset.selector));
        registry.claimAirdrop(recipient, address(strategy), proofAsset, data);
        proofAsset.erc1155TokenIds = new uint256[](1);
        proofAsset.erc1155TokenIds[0] = erc1155TokenId;

        vm.expectRevert(abi.encodeWithSelector(InvalidProofAsset.selector));
        registry.claimAirdrop(recipient, address(strategy), proofAsset, data);
        proofAsset.erc1155TokenAmounts = new uint256[](1);
        proofAsset.erc1155TokenAmounts[0] = erc1155Amount;

        address invalidStrategy = makeAddr("invalidStrategy");
        vm.expectRevert(abi.encodeWithSelector(InvalidStrategy.selector, invalidStrategy));
        registry.claimAirdrop(recipient, invalidStrategy, proofAsset, data);

        registry.claimAirdrop(recipient, address(strategy), proofAsset, data);
        vm.stopPrank();

        // Check that the ERC20, ERC721, and ERC1155 assets are returned to the vault
        assertEq(mockERC20.balanceOf(vault), erc20Amount);
        assertEq(mockERC721.ownerOf(erc721TokenId), vault);
        assertEq(mockERC1155.balanceOf(vault, erc1155TokenId), erc1155Amount);

        // Check that the recipient received the airdropped NFT (from the mock strategy)
        assertEq(mockERC721Airdrop.ownerOf(erc721AirdropTokenId), recipient);
    }

    function testAddExecuteAirdropStrategy() public {
        // Test that only the owner can add a claim airdrop strategy
        address strategy = makeAddr("strategy");
        // Non-owner should revert
        vm.prank(address(0x1234));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(0x1234)));
        registry.addExecuteAirdropStrategy(strategy);

        // Zero address should revert
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
        registry.addExecuteAirdropStrategy(address(0));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidStrategy.selector, strategy));
        registry.addExecuteAirdropStrategy(strategy);

        MockExecuteAirdropStrategy validStrategy = new MockExecuteAirdropStrategy();

        // Owner can add valid strategy
        vm.prank(owner);
        registry.addExecuteAirdropStrategy(address(validStrategy));
        // No revert means success
    }

    function testRemoveExecuteAirdropStrategy() public {
        MockExecuteAirdropStrategy validStrategy = new MockExecuteAirdropStrategy();
        vm.prank(owner);
        registry.addExecuteAirdropStrategy(address(validStrategy));

        vm.prank(address(0x1234));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(0x1234)));
        registry.removeExecuteAirdropStrategy(address(validStrategy));

        vm.prank(owner);
        registry.removeExecuteAirdropStrategy(address(validStrategy));
    }

    function testExecuteAirdropWithMockStrategy() public {
        // Create an asset vault by the authorized address
        address user = makeAddr("user");
        vm.prank(authorizedAddress);
        address vault = registry.create(user);

        MintableERC721 mockERC721 = new MintableERC721("TestNFT", "TNFT");
        MintableERC721 mockERC721Airdrop = new MintableERC721("TestAirdrop", "TA");

        // Mint assets to the vault
        uint256 erc721TokenId = 1;
        uint256 erc721AirdropTokenId = 1;

        mockERC721.mint(vault, erc721TokenId);

        // only vault can claim the airdrop
        MockAirdropContractForFixedOwner airdropContract =
            new MockAirdropContractForFixedOwner(address(mockERC721), address(mockERC721Airdrop), address(vault));

        MockExecuteAirdropStrategy strategy = new MockExecuteAirdropStrategy();

        bytes memory data = abi.encode(airdropContract, mockERC721Airdrop, erc721AirdropTokenId);

        // The owner calls executeAirdrop
        address recipient = makeAddr("recipient");

        vm.prank(owner);
        registry.addExecuteAirdropStrategy(address(strategy));
        vm.startPrank(user);
        address invalidStrategy = makeAddr("invalidStrategy");
        vm.expectRevert(abi.encodeWithSelector(InvalidStrategy.selector, invalidStrategy));
        registry.executeAirdrop(recipient, invalidStrategy, data);
        registry.executeAirdrop(recipient, address(strategy), data);
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(erc721TokenId), vault);

        // Check that the recipient received the airdropped NFT (from the mock strategy)
        assertEq(mockERC721Airdrop.ownerOf(erc721AirdropTokenId), recipient);
    }
}
