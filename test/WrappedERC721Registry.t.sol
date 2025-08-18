// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {WrappedERC721} from "../src/WrappedERC721.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {MockMintStrategy} from "./mock/MockMintStrategy.sol";
import {WrappedERC721Registry} from "../src/WrappedERC721Registry.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAssetVaultRegistry} from "../src/interfaces/IAssetVaultRegistry.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";
import {InvalidAddress, WrappedERC721NotExists, InvalidParams} from "../src/interfaces/IErrors.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/src/Upgrades.sol";
import {Options} from "@openzeppelin/foundry-upgrades/src/Options.sol";
import {MockClaimAirdropStrategy} from "./mock/MockClaimAirdropStrategy.sol";
import {MockExecuteAirdropStrategy} from "./mock/MockExecuteAirdropStrategy.sol";
import {MockAirdropContractForCurrentOwner} from "./mock/MockAirdropContract.sol";

contract WrappedERC721RegistryTest is Test {
    // bytes32 internal constant IMPL_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    WrappedERC721Registry public registry;
    AssetVaultRegistry public assetVaultRegistry;
    address public delegationRegistry;
    address public owner;
    address public user;
    MockMintStrategy public mockMintStrategy;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        delegationRegistry = makeAddr("delegationRegistry");

        vm.startPrank(owner);
        AssetVault implementation = new AssetVault();
        Options memory opts;
        assetVaultRegistry = AssetVaultRegistry(
            Upgrades.deployTransparentProxy(
                "AssetVaultRegistry.sol",
                owner,
                abi.encodeCall(AssetVaultRegistry.initialize, (address(implementation), delegationRegistry)),
                opts
            )
        );
        registry = WrappedERC721Registry(
            Upgrades.deployTransparentProxy(
                "WrappedERC721Registry.sol",
                owner,
                abi.encodeCall(
                    WrappedERC721Registry.initialize, ("eth", IAssetVaultRegistry(address(assetVaultRegistry)))
                ),
                opts
            )
        );
        assetVaultRegistry.transferOwnership(address(registry));
        mockMintStrategy = new MockMintStrategy();
        vm.stopPrank();
    }

    function testCreateWrappedERC721_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
    }

    function testBatchCreateWrappedERC721_RevertIfNotOwner() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        WrappedERC721 implementation = new WrappedERC721();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.batchCreateWrappedERC721(erc721Addresses, address(implementation), mintStrategies);
    }

    function testUpgradeWrappedERC721_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        WrappedERC721 newImplementation = new WrappedERC721();
        bytes memory encodedCallData = "";

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.upgradeWrappedERC721(address(erc721), address(newImplementation), encodedCallData);
    }

    function testBatchUpgradeWrappedERC721_RevertIfNotOwner() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        registry.batchCreateWrappedERC721(erc721Addresses, address(implementation), mintStrategies);
        vm.stopPrank();

        WrappedERC721 newImplementation = new WrappedERC721();
        bytes[] memory encodedCallDatas = new bytes[](2);
        encodedCallDatas[0] = "";
        encodedCallDatas[1] = "";

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.batchUpgradeWrappedERC721(erc721Addresses, address(newImplementation), encodedCallDatas);
    }

    function testCreateWrappedERC721() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.prank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));

        assertEq(WrappedERC721(wrappedERC721).name(), "WrappedERC721 TEST");
        assertEq(WrappedERC721(wrappedERC721).symbol(), "WTEST");
        assertEq(WrappedERC721(wrappedERC721).underlyingAsset(), address(erc721));
        assertEq(address(WrappedERC721(wrappedERC721).mintStrategy()), address(mockMintStrategy));
    }

    function testCreateWrappedERC721_RevertIfImplZeroAddress() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
        registry.createWrappedERC721(address(erc721), address(0), address(mockMintStrategy));
    }

    function testBatchCreateWrappedERC721() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        WrappedERC721 implementation = new WrappedERC721();

        vm.prank(owner);
        address[] memory wrappedERC721s =
            registry.batchCreateWrappedERC721(erc721Addresses, address(implementation), mintStrategies);

        for (uint256 i = 0; i < erc721s.length; i++) {
            assertEq(WrappedERC721(wrappedERC721s[i]).underlyingAsset(), address(erc721s[i]));
            assertEq(address(WrappedERC721(wrappedERC721s[i]).mintStrategy()), address(mockMintStrategy));
        }
    }

    function testBatchCreateWrappedERC721_RevertIfInvalidParams() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](1); // 长度不匹配
        mintStrategies[0] = address(mockMintStrategy);

        WrappedERC721 implementation = new WrappedERC721();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidParams.selector));
        registry.batchCreateWrappedERC721(erc721Addresses, address(implementation), mintStrategies);
    }

    function testUpgradeWrappedERC721() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));

        WrappedERC721 newImplementation = new WrappedERC721();

        bytes memory encodedCallData = "";

        // bytes32 implBefore = vm.load(address(wrappedERC721), IMPL_SLOT);
        // assertEq(implBefore, bytes32(uint256(uint160(address(implementation)))));
        assertEq(UpgradeableProxy(payable(wrappedERC721)).implementation(), address(implementation));

        registry.upgradeWrappedERC721(wrappedERC721, address(newImplementation), encodedCallData);
        vm.stopPrank();

        // bytes32 implAfter = vm.load(address(wrappedERC721), IMPL_SLOT);
        // assertEq(implAfter, bytes32(uint256(uint160(address(newImplementation)))));
        assertEq(UpgradeableProxy(payable(wrappedERC721)).implementation(), address(newImplementation));
    }

    function testUpgradeWrappedERC721_RevertIfWrappedERC721Nonexist() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 newImplementation = new WrappedERC721();
        bytes memory encodedCallData = "";

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, address(erc721)));
        registry.upgradeWrappedERC721(address(erc721), address(newImplementation), encodedCallData);
    }

    function testBatchUpgradeWrappedERC721() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address[] memory wrappedERC721s =
            registry.batchCreateWrappedERC721(erc721Addresses, address(implementation), mintStrategies);

        for (uint256 i = 0; i < wrappedERC721s.length; i++) {
            assertEq(UpgradeableProxy(payable(wrappedERC721s[i])).implementation(), address(implementation));
        }

        WrappedERC721 newImplementation = new WrappedERC721();

        bytes[] memory encodedCallDatas = new bytes[](2);
        encodedCallDatas[0] = "";
        encodedCallDatas[1] = "";

        registry.batchUpgradeWrappedERC721(wrappedERC721s, address(newImplementation), encodedCallDatas);
        vm.stopPrank();

        for (uint256 i = 0; i < wrappedERC721s.length; i++) {
            assertEq(UpgradeableProxy(payable(wrappedERC721s[i])).implementation(), address(newImplementation));
        }
    }

    function testBatchUpgradeWrappedERC721_RevertIfInvalidParams() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address[] memory wrappedERC721s =
            registry.batchCreateWrappedERC721(erc721Addresses, address(implementation), mintStrategies);
        vm.stopPrank();

        WrappedERC721 newImplementation = new WrappedERC721();

        bytes[] memory encodedCallDatas = new bytes[](1);
        encodedCallDatas[0] = "";

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidParams.selector));
        registry.batchUpgradeWrappedERC721(wrappedERC721s, address(newImplementation), encodedCallDatas);
    }

    function testSetBaseURI_Owner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        string memory baseURI = "https://example.com/metadata/";
        registry.setBaseURI(wrappedERC721, baseURI);
        uint256[] memory tokenIds = new uint256[](1);
        uint256 tokenId = 1;
        tokenIds[0] = tokenId;
        erc721.mint(owner, tokenId);
        erc721.setApprovalForAll(address(wrappedERC721), true);

        WrappedERC721(wrappedERC721).mint(tokenIds);

        assertEq(WrappedERC721(wrappedERC721).tokenURI(1), string(abi.encodePacked(baseURI, "1")));
        vm.stopPrank();
    }

    function testSetBaseURI_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        string memory baseURI = "https://example.com/metadata/";

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.setBaseURI(wrappedERC721, baseURI);
        vm.stopPrank();
    }

    function testSetMintStrategy_Owner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        assertEq(address(WrappedERC721(wrappedERC721).mintStrategy()), address(mockMintStrategy));

        registry.setMintStrategy(wrappedERC721, address(newMintStrategy));
        assertEq(address(WrappedERC721(wrappedERC721).mintStrategy()), address(newMintStrategy));
        vm.stopPrank();
    }

    function testSetMintStrategy_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.setMintStrategy(wrappedERC721, address(newMintStrategy));
        vm.stopPrank();
    }

    function testSetMintStrategy_RevertIfWrappedERC721Nonexist() public {
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, address(0x123)));
        registry.setMintStrategy(address(0x123), address(newMintStrategy));
    }

    // OnlyWrappedERC721 modifier tests
    function testOnlyWrappedERC721Modifier_UpgradeWrappedERC721() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();
        WrappedERC721 newImplementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // Test with valid wrappedERC721 address - should succeed
        bytes memory encodedCallData = "";
        vm.prank(owner);
        registry.upgradeWrappedERC721(wrappedERC721, address(newImplementation), encodedCallData);

        // Test with invalid wrappedERC721 address - should fail
        address invalidWrappedERC721 = address(0x123);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, invalidWrappedERC721));
        registry.upgradeWrappedERC721(invalidWrappedERC721, address(newImplementation), encodedCallData);
    }

    function testOnlyWrappedERC721Modifier_BatchUpgradeWrappedERC721() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        WrappedERC721 implementation = new WrappedERC721();
        WrappedERC721 newImplementation = new WrappedERC721();

        vm.startPrank(owner);
        address[] memory wrappedERC721s =
            registry.batchCreateWrappedERC721(erc721Addresses, address(implementation), mintStrategies);
        vm.stopPrank();

        // Test with valid wrappedERC721 addresses - should succeed
        bytes[] memory encodedCallDatas = new bytes[](2);
        encodedCallDatas[0] = "";
        encodedCallDatas[1] = "";

        vm.prank(owner);
        registry.batchUpgradeWrappedERC721(wrappedERC721s, address(newImplementation), encodedCallDatas);

        // Test with one invalid wrappedERC721 address - should fail
        address[] memory mixedWrappedERC721s = new address[](2);
        mixedWrappedERC721s[0] = wrappedERC721s[0]; // Valid
        mixedWrappedERC721s[1] = address(0x123); // Invalid

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, address(0x123)));
        registry.batchUpgradeWrappedERC721(mixedWrappedERC721s, address(newImplementation), encodedCallDatas);
    }

    function testOnlyWrappedERC721Modifier_SetBaseURI() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        string memory baseURI = "https://example.com/metadata/";

        // Test with valid wrappedERC721 address - should succeed
        vm.prank(owner);
        registry.setBaseURI(wrappedERC721, baseURI);

        // Test with invalid wrappedERC721 address - should fail
        address invalidWrappedERC721 = address(0x456);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, invalidWrappedERC721));
        registry.setBaseURI(invalidWrappedERC721, baseURI);
    }

    function testOnlyWrappedERC721Modifier_SetMintStrategy() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // Test with valid wrappedERC721 address - should succeed
        vm.prank(owner);
        registry.setMintStrategy(wrappedERC721, address(newMintStrategy));

        // Test with invalid wrappedERC721 address - should fail
        address invalidWrappedERC721 = address(0x789);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, invalidWrappedERC721));
        registry.setMintStrategy(invalidWrappedERC721, address(newMintStrategy));
    }

    function testOnlyWrappedERC721Modifier_ZeroAddress() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // Test with zero address - should fail
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, address(0)));
        registry.setBaseURI(address(0), "https://example.com/");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, address(0)));
        registry.setMintStrategy(address(0), address(newMintStrategy));
    }

    function testOnlyWrappedERC721Modifier_NonExistentAddress() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // Test with a random non-existent address - should fail
        address randomAddress = address(0xDEADBEEF);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, randomAddress));
        registry.setBaseURI(randomAddress, "https://example.com/");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, randomAddress));
        registry.setMintStrategy(randomAddress, address(newMintStrategy));
    }

    function testOnlyWrappedERC721Modifier_AfterWrappedERC721Removal() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // First, verify the wrappedERC721 exists and operations work
        vm.prank(owner);
        registry.setBaseURI(wrappedERC721, "https://example.com/");

        // Test that operations still work after some time
        vm.prank(owner);
        registry.setMintStrategy(wrappedERC721, address(newMintStrategy));
    }

    // SetSymbol tests
    function testSetSymbol_Owner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));

        // Check initial name and symbol
        assertEq(WrappedERC721(wrappedERC721).name(), "WrappedERC721 TEST");
        assertEq(WrappedERC721(wrappedERC721).symbol(), "WTEST");

        // Set new symbol
        string memory newSymbol = "CUSTOM";
        registry.setSymbol(wrappedERC721, newSymbol);

        // Check updated name and symbol
        assertEq(WrappedERC721(wrappedERC721).name(), "WrappedERC721 CUSTOM");
        assertEq(WrappedERC721(wrappedERC721).symbol(), "WCUSTOM");
        vm.stopPrank();
    }

    function testSetSymbol_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        string memory newSymbol = "CUSTOM";

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.setSymbol(wrappedERC721, newSymbol);
        vm.stopPrank();
    }

    function testSetSymbol_RevertIfWrappedERC721Nonexist() public {
        string memory newSymbol = "CUSTOM";

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(WrappedERC721NotExists.selector, address(0x123)));
        registry.setSymbol(address(0x123), newSymbol);
    }

    function testSetSymbol_EmptySymbol() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));

        // Set empty symbol
        string memory emptySymbol = "";
        vm.expectRevert(abi.encodeWithSelector(InvalidParams.selector));
        registry.setSymbol(wrappedERC721, emptySymbol);
        vm.stopPrank();
    }

    function testSetSymbol_LongSymbol() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));

        // Set long symbol
        string memory longSymbol = "VERY_LONG_SYMBOL_NAME";
        registry.setSymbol(wrappedERC721, longSymbol);

        // Check updated name and symbol
        assertEq(WrappedERC721(wrappedERC721).name(), "WrappedERC721 VERY_LONG_SYMBOL_NAME");
        assertEq(WrappedERC721(wrappedERC721).symbol(), "WVERY_LONG_SYMBOL_NAME");
        vm.stopPrank();
    }

    function testSetSymbol_MultipleUpdates() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        WrappedERC721 implementation = new WrappedERC721();

        vm.startPrank(owner);
        address wrappedERC721 =
            registry.createWrappedERC721(address(erc721), address(implementation), address(mockMintStrategy));

        // First update
        registry.setSymbol(wrappedERC721, "FIRST");
        assertEq(WrappedERC721(wrappedERC721).name(), "WrappedERC721 FIRST");
        assertEq(WrappedERC721(wrappedERC721).symbol(), "WFIRST");

        // Second update
        registry.setSymbol(wrappedERC721, "SECOND");
        assertEq(WrappedERC721(wrappedERC721).name(), "WrappedERC721 SECOND");
        assertEq(WrappedERC721(wrappedERC721).symbol(), "WSECOND");

        // Third update
        registry.setSymbol(wrappedERC721, "THIRD");
        assertEq(WrappedERC721(wrappedERC721).name(), "WrappedERC721 THIRD");
        assertEq(WrappedERC721(wrappedERC721).symbol(), "WTHIRD");
        vm.stopPrank();
    }

    function testAddAndRemoveClaimAirdropStrategy() public {
        // Deploy a mock strategy address
        address mockStrategy = address(
            new MockClaimAirdropStrategy(
                new MockAirdropContractForCurrentOwner(address(0), address(0), address(0), address(0)),
                address(registry),
                new address[](0),
                new address[](0),
                new address[](0)
            )
        );

        // Only owner can add claim airdrop strategy
        vm.prank(owner);
        registry.addClaimAirdropStrategy(mockStrategy);

        // Only owner can remove claim airdrop strategy
        vm.prank(owner);
        registry.removeClaimAirdropStrategy(mockStrategy);

        // Non-owner should revert on add
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.addClaimAirdropStrategy(mockStrategy);

        // Non-owner should revert on remove
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.removeClaimAirdropStrategy(mockStrategy);
    }

    function testAddAndRemoveExecuteAirdropStrategy() public {
        // Deploy a mock strategy address
        address mockStrategy = address(new MockExecuteAirdropStrategy());

        // Only owner can add execute airdrop strategy
        vm.prank(owner);
        registry.addExecuteAirdropStrategy(mockStrategy);

        // Only owner can remove execute airdrop strategy
        vm.prank(owner);
        registry.removeExecuteAirdropStrategy(mockStrategy);

        // Non-owner should revert on add
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.addExecuteAirdropStrategy(mockStrategy);

        // Non-owner should revert on remove
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.removeExecuteAirdropStrategy(mockStrategy);
    }
}
