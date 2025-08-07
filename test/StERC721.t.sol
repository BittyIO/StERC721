// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {StERC721} from "../src/StERC721.sol";
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
import {IStERC721} from "../src/interfaces/IStERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {InvalidERC721, InvalidERC721Owner, InvalidERC721Token} from "../src/interfaces/IErrors.sol";
import {IMintStrategy} from "../src/interfaces/IMintStrategy.sol";
import {console2} from "forge-std/console2.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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
    MockMintStrategy public mockMintStrategy;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        delegationRegistry = makeAddr("delegationRegistry");
        delegate = makeAddr("delegate");
        vm.startPrank(owner);

        implementation = new AssetVault();
        registry = new AssetVaultRegistry();
        registry.initialize(address(implementation), delegationRegistry);

        mockMintStrategy = new MockMintStrategy();
        mockERC721_A = new MintableERC721("TestERC721_A", "TST721A");
        mockERC721_B = new MintableERC721("TestERC721_B", "TST721B");

        stERC721_A = new StERC721();
        stERC721_A.initialize("eth", mockERC721_A, registry, "Staked ERC721", "stERC721_A", mockMintStrategy);
        stERC721_B = new StERC721();
        stERC721_B.initialize("eth", mockERC721_B, registry, "Staked ERC721", "stERC721_B", mockMintStrategy);
        registry.authorize(address(stERC721_A));
        registry.authorize(address(stERC721_B));

        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(address(stERC721_A.assetVaultRegistry()), address(registry));
        assertEq(stERC721_A.underlyingAsset(), address(mockERC721_A));
        assertEq(stERC721_A.owner(), owner);
    }

    function testDisableInitializers() public {
        vm.startPrank(owner);
        StERC721 stERC721 = new StERC721();
        stERC721.disableInitializers();
        vm.expectRevert();
        stERC721.initialize("eth", mockERC721_A, registry, "Staked ERC721", "stERC721", mockMintStrategy);
        vm.stopPrank();
    }

    function testSupportsInterface() public view {
        // IStERC721 interfaceId
        bytes4 iStERC721InterfaceId = type(IStERC721).interfaceId;
        assertTrue(stERC721_A.supportsInterface(iStERC721InterfaceId));
        // Random interfaceId should return false
        assertFalse(stERC721_A.supportsInterface(0x12345678));
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
        assertEq(mockERC721_A.ownerOf(tokenId), address(registry.getAssetVault(user)));
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

        address assetVault = address(registry.getAssetVault(owner));
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
        vm.stopPrank();

        address user2 = makeAddr("user2");
        vm.startPrank(user2);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Owner.selector, address(mockERC721_A), tokenId));
        stERC721_A.burn(tokenIds);
        vm.stopPrank();

        vm.startPrank(user);
        stERC721_A.burn(tokenIds);

        assertEq(mockERC721_A.ownerOf(tokenId), user);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));
        stERC721_A.ownerOf(tokenId);
        vm.stopPrank();
    }

    function testBurnToDifferentReceiver() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        address receiver = address(0xBEEF);

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);

        stERC721_A.mint(tokenIds);
        stERC721_A.burn(tokenIds, receiver);

        assertEq(mockERC721_A.ownerOf(tokenId), receiver);

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
        vm.stopPrank();

        address user2 = makeAddr("user2");
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Owner.selector, address(mockERC721_A), tokenId));
        stERC721_A.setDelegateCashV2(delegate, tokenIds, rights, true);
        vm.stopPrank();

        bytes32 expectedDelegationHash = bytes32("DELEGATION_HASH");
        vm.mockCall(
            address(delegationRegistry),
            abi.encodeWithSelector(IDelegateRegistryV2.delegateERC721.selector),
            abi.encode(expectedDelegationHash)
        );
        vm.startPrank(user);
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

        address testUser = address(0x3333);

        // mint mockERC721_A
        vm.startPrank(testUser);
        mockERC721_A.mint(testUser, tokenIdA);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        uint256[] memory tokenIdsA = new uint256[](1);
        tokenIdsA[0] = tokenIdA;
        stERC721_A.mint(tokenIdsA);
        assertEq(stERC721_A.ownerOf(tokenIdA), testUser);
        assertEq(mockERC721_A.ownerOf(tokenIdA), address(registry.getAssetVault(testUser)));
        vm.stopPrank();

        // mint mockERC721_B
        vm.startPrank(testUser);
        mockERC721_B.mint(testUser, tokenIdB);
        mockERC721_B.setApprovalForAll(address(stERC721_B), true);
        uint256[] memory tokenIdsB = new uint256[](1);
        tokenIdsB[0] = tokenIdB;
        stERC721_B.mint(tokenIdsB);
        assertEq(stERC721_B.ownerOf(tokenIdB), testUser);
        assertEq(mockERC721_B.ownerOf(tokenIdB), address(registry.getAssetVault(testUser)));
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

    function testGetDelegateCashForTokenV2() public {
        address erc721 = address(mockERC721_A);
        uint256 tokenId = 1;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        stERC721_A.mint(tokenIds);
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
        address[][] memory delegateCash = stERC721_A.getDelegateCashForTokenV2(tokenIds);

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
        bytes4 selector = stERC721_A.onERC721Received(address(mockERC721_A), staker, tokenId, "");
        assertEq(selector, IERC721Receiver.onERC721Received.selector, "Should return correct selector");
        vm.stopPrank();
    }

    function test_onERC721Received_revertsIfNotFromUnderlying() public {
        uint256 tokenId = 43;
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721.selector, address(mockERC721_A)));
        mockERC721_A.safeMint(address(stERC721_B), tokenId);
    }

    function testMint_RevertIfInvalidERC721Token() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        // Set mintStrategy to disallow this token
        mockMintStrategy.setMintable(address(mockERC721_A), tokenId, false);

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);

        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Token.selector, address(mockERC721_A), tokenId));
        stERC721_A.mint(tokenIds);
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
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);

        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Token.selector, address(mockERC721_A), tokenId2));
        stERC721_A.mint(tokenIds);
        vm.stopPrank();
    }

    function testMint_SuccessWithZeroAddressMintStrategy() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        // Create a new StERC721 with zero address as mintStrategy
        StERC721 stERC721ZeroStrategy = new StERC721();
        vm.prank(owner);
        stERC721ZeroStrategy.initialize(
            "eth", mockERC721_A, registry, "Staked ERC721 Zero", "stERC721Zero", IMintStrategy(address(0))
        );
        vm.prank(owner);
        registry.authorize(address(stERC721ZeroStrategy));

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721ZeroStrategy), true);

        // Even if mintStrategy is zero address, mint should succeed
        stERC721ZeroStrategy.mint(tokenIds);

        assertEq(stERC721ZeroStrategy.ownerOf(tokenId), user);
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

        // Create a new StERC721, using restrictive mintStrategy
        StERC721 stERC721Restrictive = new StERC721();
        vm.prank(owner);
        stERC721Restrictive.initialize(
            "eth", mockERC721_A, registry, "Staked ERC721 Restrictive", "stERC721Restrictive", restrictiveMintStrategy
        );
        vm.prank(owner);
        registry.authorize(address(stERC721Restrictive));

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721Restrictive), true);

        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Token.selector, address(mockERC721_A), tokenId));
        stERC721Restrictive.mint(tokenIds);
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
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);

        // First mint should fail
        vm.expectRevert(abi.encodeWithSelector(InvalidERC721Token.selector, address(mockERC721_A), tokenId));
        stERC721_A.mint(tokenIds);

        // Update mintStrategy to allow this token
        vm.stopPrank();
        vm.prank(owner);
        stERC721_A.setMintStrategy(mockMintStrategy);

        vm.startPrank(user);
        // Reset mintable state
        mockMintStrategy.setMintable(address(mockERC721_A), tokenId, true);

        // Now mint should succeed
        stERC721_A.mint(tokenIds);

        assertEq(stERC721_A.ownerOf(tokenId), user);
        assertEq(mockERC721_A.ownerOf(tokenId), address(registry.getAssetVault(user)));
        vm.stopPrank();
    }

    // SetNameAndSymbol tests
    function testSetNameAndSymbol_Owner() public {
        // Check initial name and symbol
        assertEq(stERC721_A.name(), "Staked ERC721");
        assertEq(stERC721_A.symbol(), "stERC721_A");

        vm.startPrank(owner);
        string memory newName = "Custom Staked Token";
        string memory newSymbol = "CST";

        stERC721_A.setNameAndSymbol(newName, newSymbol);

        // Check updated name and symbol
        assertEq(stERC721_A.name(), newName);
        assertEq(stERC721_A.symbol(), newSymbol);
        vm.stopPrank();
    }

    function testSetNameAndSymbol_RevertIfNotOwner() public {
        string memory newName = "Custom Staked Token";
        string memory newSymbol = "CST";

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        stERC721_A.setNameAndSymbol(newName, newSymbol);
        vm.stopPrank();
    }

    function testSetNameAndSymbol_EmptyStrings() public {
        vm.startPrank(owner);
        string memory emptyName = "";
        string memory emptySymbol = "";

        stERC721_A.setNameAndSymbol(emptyName, emptySymbol);

        // Check updated name and symbol - empty strings should be set correctly
        assertEq(stERC721_A.name(), "");
        assertEq(stERC721_A.symbol(), "");
        vm.stopPrank();
    }

    function testSetNameAndSymbol_LongStrings() public {
        vm.startPrank(owner);
        string memory longName = "This is a very long name for testing purposes with many characters";
        string memory longSymbol = "VERY_LONG_SYMBOL_FOR_TESTING";

        stERC721_A.setNameAndSymbol(longName, longSymbol);

        // Check updated name and symbol
        assertEq(stERC721_A.name(), longName);
        assertEq(stERC721_A.symbol(), longSymbol);
        vm.stopPrank();
    }

    function testSetNameAndSymbol_SpecialCharacters() public {
        vm.startPrank(owner);
        string memory specialName = "Staked Token #123";
        string memory specialSymbol = "ST#123";

        stERC721_A.setNameAndSymbol(specialName, specialSymbol);

        // Check updated name and symbol
        assertEq(stERC721_A.name(), specialName);
        assertEq(stERC721_A.symbol(), specialSymbol);
        vm.stopPrank();
    }

    function testSetNameAndSymbol_MultipleUpdates() public {
        vm.startPrank(owner);

        // First update
        stERC721_A.setNameAndSymbol("First Name", "FIRST");
        assertEq(stERC721_A.name(), "First Name");
        assertEq(stERC721_A.symbol(), "FIRST");

        // Second update
        stERC721_A.setNameAndSymbol("Second Name", "SECOND");
        assertEq(stERC721_A.name(), "Second Name");
        assertEq(stERC721_A.symbol(), "SECOND");

        // Third update
        stERC721_A.setNameAndSymbol("Third Name", "THIRD");
        assertEq(stERC721_A.name(), "Third Name");
        assertEq(stERC721_A.symbol(), "THIRD");
        vm.stopPrank();
    }

    function testSetNameAndSymbol_DifferentStERC721() public {
        // Test with stERC721_B
        assertEq(stERC721_B.name(), "Staked ERC721");
        assertEq(stERC721_B.symbol(), "stERC721_B");

        vm.startPrank(owner);
        string memory newName = "Different Staked Token";
        string memory newSymbol = "DST";

        stERC721_B.setNameAndSymbol(newName, newSymbol);

        // Check updated name and symbol
        assertEq(stERC721_B.name(), newName);
        assertEq(stERC721_B.symbol(), newSymbol);

        // Verify stERC721_A is unchanged
        assertEq(stERC721_A.name(), "Staked ERC721");
        assertEq(stERC721_A.symbol(), "stERC721_A");
        vm.stopPrank();
    }

    function testSetNameAndSymbol_AfterMint() public {
        uint256 tokenId = 1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(user);
        mockERC721_A.mint(user, tokenId);
        mockERC721_A.setApprovalForAll(address(stERC721_A), true);
        stERC721_A.mint(tokenIds);
        vm.stopPrank();

        // Change name and symbol after minting
        vm.startPrank(owner);
        string memory newName = "Post Mint Name";
        string memory newSymbol = "PMN";

        stERC721_A.setNameAndSymbol(newName, newSymbol);

        // Check updated name and symbol
        assertEq(stERC721_A.name(), newName);
        assertEq(stERC721_A.symbol(), newSymbol);

        // Verify token ownership is still correct
        assertEq(stERC721_A.ownerOf(tokenId), user);
        vm.stopPrank();
    }
}
