// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {WrappedERC721} from "../src/WrappedERC721.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {MockMintStrategy} from "./mock/MockMintStrategy.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IDelegateRegistryV2} from "../src/interfaces/IDelegateRegistryV2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {IWrappedERC721} from "../src/interfaces/IWrappedERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {InvalidERC721, InvalidERC721Owner, InvalidERC721Token} from "../src/interfaces/IErrors.sol";
import {IMintStrategy} from "../src/interfaces/IMintStrategy.sol";
import {console2} from "forge-std/console2.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/src/Upgrades.sol";
import {Options} from "@openzeppelin/foundry-upgrades/src/Options.sol";

contract WrappedERC721Test is Test {
    using Strings for uint256;

    WrappedERC721 public wrappedERC721_A;
    WrappedERC721 public wrappedERC721_B;
    AssetVaultRegistry public registry;
    AssetVault public implementation;
    MintableERC721 public mockERC721_A;
    MintableERC721 public mockERC721_B;
    address public delegationRegistry;
    address public owner;
    address public user;
    address public delegate;
    MockMintStrategy public mockMintStrategy;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        delegationRegistry = makeAddr("delegationRegistry");
        delegate = makeAddr("delegate");
        vm.startPrank(owner);

        implementation = new AssetVault();
        Options memory opts;
        registry = AssetVaultRegistry(
            Upgrades.deployTransparentProxy(
                "AssetVaultRegistry.sol",
                owner,
                abi.encodeCall(AssetVaultRegistry.initialize, (address(implementation), delegationRegistry)),
                opts
            )
        );

        mockMintStrategy = new MockMintStrategy();
        mockERC721_A = new MintableERC721("TewrappedERC721_A", "TST721A");
        mockERC721_B = new MintableERC721("TewrappedERC721_B", "TST721B");

        wrappedERC721_A = new WrappedERC721();
        wrappedERC721_A.initialize("eth", mockERC721_A, registry, "Wrapped ERC721", "wrappedERC721_A", mockMintStrategy);
        wrappedERC721_B = new WrappedERC721();
        wrappedERC721_B.initialize("eth", mockERC721_B, registry, "Wrapped ERC721", "wrappedERC721_B", mockMintStrategy);
        registry.authorize(address(wrappedERC721_A));
        registry.authorize(address(wrappedERC721_B));

        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(address(wrappedERC721_A.assetVaultRegistry()), address(registry));
        assertEq(wrappedERC721_A.underlyingAsset(), address(mockERC721_A));
        assertEq(wrappedERC721_A.owner(), owner);
    }

    function testDisableInitializers() public {
        vm.startPrank(owner);
        WrappedERC721 wrappedERC721 = new WrappedERC721();
        wrappedERC721.disableInitializers();
        vm.expectRevert();
        wrappedERC721.initialize("eth", mockERC721_A, registry, "Wrapped ERC721", "wrappedERC721", mockMintStrategy);
        vm.stopPrank();
    }

    function testSupportsInterface() public view {
        // IWrappedERC721 interfaceId
        bytes4 iWrappedERC721InterfaceId = type(IWrappedERC721).interfaceId;
        assertTrue(wrappedERC721_A.supportsInterface(iWrappedERC721InterfaceId));
        // Random interfaceId should return false
        assertFalse(wrappedERC721_A.supportsInterface(0x12345678));
    }

    function testMint() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);

        wrappedERC721_A.mint(tokenIds);

        assertEq(wrappedERC721_A.ownerOf(tokenId), user);
        assertEq(mockERC721_A.ownerOf(tokenId), address(registry.getAssetVault(user)));
        vm.stopPrank();
    }

    function testTransferFrom() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        wrappedERC721_A.mint(tokenIds);
        wrappedERC721_A.safeTransferFrom(user, owner, tokenId);
        vm.stopPrank();

        address assetVault = address(registry.getAssetVault(owner));
        assertEq(wrappedERC721_A.ownerOf(tokenId), owner);
        assertEq(mockERC721_A.ownerOf(tokenId), assetVault);
    }

    function testBurn() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        wrappedERC721_A.mint(tokenIds);
        vm.stopPrank();

        address user2 = makeAddr("user2");
        vm.startPrank(user2);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Owner.selector, address(mockERC721_A), tokenId));
        wrappedERC721_A.burn(tokenIds);
        vm.stopPrank();

        vm.startPrank(user);
        wrappedERC721_A.burn(tokenIds);

        assertEq(mockERC721_A.ownerOf(tokenId), user);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));
        wrappedERC721_A.ownerOf(tokenId);
        vm.stopPrank();
    }

    function testBurnToDifferentReceiver() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        address receiver = address(0xBEEF);

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);

        wrappedERC721_A.mint(tokenIds);
        wrappedERC721_A.burn(tokenIds, receiver);

        assertEq(mockERC721_A.ownerOf(tokenId), receiver);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));
        wrappedERC721_A.ownerOf(tokenId);
        vm.stopPrank();
    }

    function testSetDelegateCashV2() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        bytes32 rights = bytes32("SOME_RIGHTS");

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        wrappedERC721_A.mint(tokenIds);
        vm.stopPrank();

        address user2 = makeAddr("user2");
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Owner.selector, address(mockERC721_A), tokenId));
        wrappedERC721_A.setDelegateCashV2(delegate, tokenIds, rights, true);
        vm.stopPrank();

        bytes32 expectedDelegationHash = bytes32("DELEGATION_HASH");
        vm.mockCall(
            address(delegationRegistry),
            abi.encodeWithSelector(IDelegateRegistryV2.delegateERC721.selector),
            abi.encode(expectedDelegationHash)
        );
        vm.startPrank(user);
        bytes32[] memory delegationHashes = wrappedERC721_A.setDelegateCashV2(delegate, tokenIds, rights, true);
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
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        wrappedERC721_A.mint(tokenIds);
        vm.stopPrank();

        assertEq(wrappedERC721_A.tokenURI(tokenId), mockERC721_A.tokenURI(tokenId));

        vm.prank(owner);
        wrappedERC721_A.setBaseURI("https://api.example.com/");
        assertEq(wrappedERC721_A.tokenURI(tokenId), string.concat("https://api.example.com/", tokenId.toString()));
    }

    function testContractURI() public view {
        string memory expectedURI = string(
            abi.encodePacked(
                "https://metadata.bitty.io/eth/", Strings.toHexString(uint256(uint160(address(wrappedERC721_A))), 20)
            )
        );
        assertEq(wrappedERC721_A.contractURI(), expectedURI);
    }

    function testTwoUsersMintThenBurn() public {
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;
        address user1 = address(0x1111);
        address user2 = address(0x2222);

        vm.startPrank(user1);
        mockERC721_A.mint(user1, tokenId1);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        uint256[] memory tokenIds1 = new uint256[](1);
        tokenIds1[0] = tokenId1;
        wrappedERC721_A.mint(tokenIds1);
        vm.stopPrank();

        vm.startPrank(user2);
        mockERC721_A.mint(user2, tokenId2);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = tokenId2;
        wrappedERC721_A.mint(tokenIds2);
        vm.stopPrank();

        assertEq(wrappedERC721_A.ownerOf(tokenId1), user1);
        assertEq(wrappedERC721_A.ownerOf(tokenId2), user2);

        vm.startPrank(user1);
        tokenIds1[0] = tokenId1;
        wrappedERC721_A.burn(tokenIds1);
        vm.stopPrank();

        vm.expectRevert();
        wrappedERC721_A.ownerOf(tokenId1);
        assertEq(wrappedERC721_A.ownerOf(tokenId2), user2);

        vm.startPrank(user2);
        tokenIds2[0] = tokenId2;
        wrappedERC721_A.burn(tokenIds2);
        vm.stopPrank();

        vm.expectRevert();
        wrappedERC721_A.ownerOf(tokenId2);
    }

    function testMintAndBurnDifferentERC721() public {
        uint256 tokenIdA = 10;
        uint256 tokenIdB = 20;

        address testUser = address(0x3333);

        // mint mockERC721_A
        vm.startPrank(testUser);
        mockERC721_A.mint(testUser, tokenIdA);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        uint256[] memory tokenIdsA = new uint256[](1);
        tokenIdsA[0] = tokenIdA;
        wrappedERC721_A.mint(tokenIdsA);
        assertEq(wrappedERC721_A.ownerOf(tokenIdA), testUser);
        assertEq(mockERC721_A.ownerOf(tokenIdA), address(registry.getAssetVault(testUser)));
        vm.stopPrank();

        // mint mockERC721_B
        vm.startPrank(testUser);
        mockERC721_B.mint(testUser, tokenIdB);
        mockERC721_B.setApprovalForAll(address(wrappedERC721_B), true);
        uint256[] memory tokenIdsB = new uint256[](1);
        tokenIdsB[0] = tokenIdB;
        wrappedERC721_B.mint(tokenIdsB);
        assertEq(wrappedERC721_B.ownerOf(tokenIdB), testUser);
        assertEq(mockERC721_B.ownerOf(tokenIdB), address(registry.getAssetVault(testUser)));
        vm.stopPrank();

        // burn mockERC721_A
        vm.startPrank(testUser);
        wrappedERC721_A.burn(tokenIdsA);
        vm.stopPrank();
        vm.expectRevert();
        wrappedERC721_A.ownerOf(tokenIdA);

        // burn mockERC721_B
        vm.startPrank(testUser);
        wrappedERC721_B.burn(tokenIdsB);
        vm.stopPrank();
        vm.expectRevert();
        wrappedERC721_B.ownerOf(tokenIdB);
    }

    function testGetDelegateCashForTokenV2() public {
        address erc721 = address(mockERC721_A);
        uint256 tokenId = 1;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        wrappedERC721_A.mint(tokenIds);
        vm.stopPrank();

        address vault = address(registry.getAssetVault(user));

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
        address[][] memory delegateCash = wrappedERC721_A.getDelegateCashForTokenV2(tokenIds);

        assertEq(delegateCash.length, 1);
        assertEq(delegateCash[0][0], delegates[0]);
        assertEq(delegateCash[0][1], delegates[1]);
    }

    function test_onERC721Received_acceptsFromUnderlying() public {
        address staker = user;
        uint256 tokenId = 42;

        // Mint token to staker
        vm.startPrank(staker);
        mockERC721_A.mint(staker, tokenId);
        vm.stopPrank();
        // Call onERC721Received from the underlying ERC721 contract
        vm.prank(address(mockERC721_A));
        bytes4 selector = wrappedERC721_A.onERC721Received(address(mockERC721_A), staker, tokenId, "");
        assertEq(selector, IERC721Receiver.onERC721Received.selector, "Should return correct selector");
        vm.stopPrank();
    }

    function test_onERC721Received_revertsIfNotFromUnderlying() public {
        uint256 tokenId = 43;
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721.selector, address(mockERC721_A)));
        mockERC721_A.safeMint(address(wrappedERC721_B), tokenId);
    }

    function testMint_RevertIfInvalidERC721Token() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        // Set mintStrategy to disallow this token
        mockMintStrategy.setMintable(address(mockERC721_A), tokenId, false);

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);

        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Token.selector, address(mockERC721_A), tokenId));
        wrappedERC721_A.mint(tokenIds);
        vm.stopPrank();
    }

    function testMint_RevertIfInvalidERC721TokenInBatch() public {
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        // Set mintStrategy to allow first token, disallow second token
        mockMintStrategy.setMintable(address(mockERC721_A), tokenId1, true);
        mockMintStrategy.setMintable(address(mockERC721_A), tokenId2, false);

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId1);
        mockERC721_A.mint(user, tokenId2);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);

        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Token.selector, address(mockERC721_A), tokenId2));
        wrappedERC721_A.mint(tokenIds);
        vm.stopPrank();
    }

    function testMint_SuccessWithZeroAddressMintStrategy() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        // Create a new WrappedERC721 with zero address as mintStrategy
        WrappedERC721 wrappedERC721ZeroStrategy = new WrappedERC721();
        vm.prank(owner);
        wrappedERC721ZeroStrategy.initialize(
            "eth", mockERC721_A, registry, "Wrapped ERC721 Zero", "wrappedERC721Zero", IMintStrategy(address(0))
        );
        vm.prank(owner);
        registry.authorize(address(wrappedERC721ZeroStrategy));

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721ZeroStrategy), true);

        // Even if mintStrategy is zero address, mint should succeed
        wrappedERC721ZeroStrategy.mint(tokenIds);

        assertEq(wrappedERC721ZeroStrategy.ownerOf(tokenId), user);
        assertEq(mockERC721_A.ownerOf(tokenId), address(registry.getAssetVault(user)));
        vm.stopPrank();
    }

    function testMint_RevertIfMintStrategyReturnsFalse() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        // Create a new MockMintStrategy, default returns false
        MockMintStrategy restrictiveMintStrategy = new MockMintStrategy();
        restrictiveMintStrategy.setMintable(address(mockERC721_A), tokenId, false);

        // Create a new WrappedERC721, using restrictive mintStrategy
        WrappedERC721 wrappedERC721Restrictive = new WrappedERC721();
        vm.prank(owner);
        wrappedERC721Restrictive.initialize(
            "eth",
            mockERC721_A,
            registry,
            "Wrapped ERC721 Restrictive",
            "wrappedERC721Restrictive",
            restrictiveMintStrategy
        );
        vm.prank(owner);
        registry.authorize(address(wrappedERC721Restrictive));

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721Restrictive), true);

        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Token.selector, address(mockERC721_A), tokenId));
        wrappedERC721Restrictive.mint(tokenIds);
        vm.stopPrank();
    }

    function testMint_SuccessAfterMintStrategyUpdate() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        // Initial set mintStrategy to disallow this token
        mockMintStrategy.setMintable(address(mockERC721_A), tokenId, false);

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);

        // First mint should fail
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Token.selector, address(mockERC721_A), tokenId));
        wrappedERC721_A.mint(tokenIds);

        // Update mintStrategy to allow this token
        vm.stopPrank();
        vm.prank(owner);
        wrappedERC721_A.setMintStrategy(mockMintStrategy);

        vm.startPrank(user);
        // Reset mintable state
        mockMintStrategy.setMintable(address(mockERC721_A), tokenId, true);

        // Now mint should succeed
        wrappedERC721_A.mint(tokenIds);

        assertEq(wrappedERC721_A.ownerOf(tokenId), user);
        assertEq(mockERC721_A.ownerOf(tokenId), address(registry.getAssetVault(user)));
        vm.stopPrank();
    }

    // SetNameAndSymbol tests
    function testSetNameAndSymbol_Owner() public {
        // Check initial name and symbol
        assertEq(wrappedERC721_A.name(), "Wrapped ERC721");
        assertEq(wrappedERC721_A.symbol(), "wrappedERC721_A");

        vm.startPrank(owner);
        string memory newName = "Custom Staked Token";
        string memory newSymbol = "CST";

        wrappedERC721_A.setNameAndSymbol(newName, newSymbol);

        // Check updated name and symbol
        assertEq(wrappedERC721_A.name(), newName);
        assertEq(wrappedERC721_A.symbol(), newSymbol);
        vm.stopPrank();
    }

    function testSetNameAndSymbol_RevertIfNotOwner() public {
        string memory newName = "Custom Staked Token";
        string memory newSymbol = "CST";

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        wrappedERC721_A.setNameAndSymbol(newName, newSymbol);
        vm.stopPrank();
    }

    function testSetNameAndSymbol_EmptyStrings() public {
        vm.startPrank(owner);
        string memory emptyName = "";
        string memory emptySymbol = "";

        wrappedERC721_A.setNameAndSymbol(emptyName, emptySymbol);

        // Check updated name and symbol - empty strings should be set correctly
        assertEq(wrappedERC721_A.name(), "");
        assertEq(wrappedERC721_A.symbol(), "");
        vm.stopPrank();
    }

    function testSetNameAndSymbol_LongStrings() public {
        vm.startPrank(owner);
        string memory longName = "This is a very long name for testing purposes with many characters";
        string memory longSymbol = "VERY_LONG_SYMBOL_FOR_TESTING";

        wrappedERC721_A.setNameAndSymbol(longName, longSymbol);

        // Check updated name and symbol
        assertEq(wrappedERC721_A.name(), longName);
        assertEq(wrappedERC721_A.symbol(), longSymbol);
        vm.stopPrank();
    }

    function testSetNameAndSymbol_SpecialCharacters() public {
        vm.startPrank(owner);
        string memory specialName = "Staked Token #123";
        string memory specialSymbol = "ST#123";

        wrappedERC721_A.setNameAndSymbol(specialName, specialSymbol);

        // Check updated name and symbol
        assertEq(wrappedERC721_A.name(), specialName);
        assertEq(wrappedERC721_A.symbol(), specialSymbol);
        vm.stopPrank();
    }

    function testSetNameAndSymbol_MultipleUpdates() public {
        vm.startPrank(owner);

        // First update
        wrappedERC721_A.setNameAndSymbol("First Name", "FIRST");
        assertEq(wrappedERC721_A.name(), "First Name");
        assertEq(wrappedERC721_A.symbol(), "FIRST");

        // Second update
        wrappedERC721_A.setNameAndSymbol("Second Name", "SECOND");
        assertEq(wrappedERC721_A.name(), "Second Name");
        assertEq(wrappedERC721_A.symbol(), "SECOND");

        // Third update
        wrappedERC721_A.setNameAndSymbol("Third Name", "THIRD");
        assertEq(wrappedERC721_A.name(), "Third Name");
        assertEq(wrappedERC721_A.symbol(), "THIRD");
        vm.stopPrank();
    }

    function testSetNameAndSymbol_DifferentWrappedERC721() public {
        // Test with wrappedERC721_B
        assertEq(wrappedERC721_B.name(), "Wrapped ERC721");
        assertEq(wrappedERC721_B.symbol(), "wrappedERC721_B");

        vm.startPrank(owner);
        string memory newName = "Different Staked Token";
        string memory newSymbol = "DST";

        wrappedERC721_B.setNameAndSymbol(newName, newSymbol);

        // Check updated name and symbol
        assertEq(wrappedERC721_B.name(), newName);
        assertEq(wrappedERC721_B.symbol(), newSymbol);

        // Verify wrappedERC721_A is unchanged
        assertEq(wrappedERC721_A.name(), "Wrapped ERC721");
        assertEq(wrappedERC721_A.symbol(), "wrappedERC721_A");
        vm.stopPrank();
    }

    function testSetNameAndSymbol_AfterMint() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(wrappedERC721_A), true);
        wrappedERC721_A.mint(tokenIds);
        vm.stopPrank();

        // Change name and symbol after minting
        vm.startPrank(owner);
        string memory newName = "Post Mint Name";
        string memory newSymbol = "PMN";

        wrappedERC721_A.setNameAndSymbol(newName, newSymbol);

        // Check updated name and symbol
        assertEq(wrappedERC721_A.name(), newName);
        assertEq(wrappedERC721_A.symbol(), newSymbol);

        // Verify token ownership is still correct
        assertEq(wrappedERC721_A.ownerOf(tokenId), user);
        vm.stopPrank();
    }
}
