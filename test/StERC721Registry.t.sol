// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {StERC721} from "../src/StERC721.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {MockMintStrategy} from "./mock/MockMintStrategy.sol";
import {StERC721Registry} from "../src/StERC721Registry.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAssetVaultRegistry} from "../src/interfaces/IAssetVaultRegistry.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";
import {InvalidAddress, StERC721NotExists, InvalidParams} from "../src/interfaces/IErrors.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/src/Upgrades.sol";
import {Options} from "@openzeppelin/foundry-upgrades/src/Options.sol";

contract StERC721RegistryTest is Test {
    // bytes32 internal constant IMPL_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    StERC721Registry public registry;
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
        registry = StERC721Registry(
            Upgrades.deployTransparentProxy(
                "StERC721Registry.sol",
                owner,
                abi.encodeCall(StERC721Registry.initialize, ("eth", IAssetVaultRegistry(address(assetVaultRegistry)))),
                opts
            )
        );
        assetVaultRegistry.transferOwnership(address(registry));
        mockMintStrategy = new MockMintStrategy();
        vm.stopPrank();
    }

    function testCreateStERC721_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
    }

    function testBatchCreateStERC721_RevertIfNotOwner() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        StERC721 implementation = new StERC721();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.batchCreateStERC721(erc721Addresses, address(implementation), mintStrategies);
    }

    function testUpgradeStERC721_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        StERC721 newImplementation = new StERC721();
        bytes memory encodedCallData = "";

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.upgradeStERC721(address(erc721), address(newImplementation), encodedCallData);
    }

    function testBatchUpgradeStERC721_RevertIfNotOwner() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        registry.batchCreateStERC721(erc721Addresses, address(implementation), mintStrategies);
        vm.stopPrank();

        StERC721 newImplementation = new StERC721();
        bytes[] memory encodedCallDatas = new bytes[](2);
        encodedCallDatas[0] = "";
        encodedCallDatas[1] = "";

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.batchUpgradeStERC721(erc721Addresses, address(newImplementation), encodedCallDatas);
    }

    function testCreateStERC721() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.prank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));

        assertEq(StERC721(stERC721).name(), "StERC721 TEST");
        assertEq(StERC721(stERC721).symbol(), "StTEST");
        assertEq(StERC721(stERC721).underlyingAsset(), address(erc721));
        assertEq(address(StERC721(stERC721).mintStrategy()), address(mockMintStrategy));
    }

    function testCreateStERC721_RevertIfImplZeroAddress() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
        registry.createStERC721(address(erc721), address(0), address(mockMintStrategy));
    }

    function testBatchCreateStERC721() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        StERC721 implementation = new StERC721();

        vm.prank(owner);
        address[] memory stERC721s =
            registry.batchCreateStERC721(erc721Addresses, address(implementation), mintStrategies);

        for (uint256 i = 0; i < erc721s.length; i++) {
            assertEq(StERC721(stERC721s[i]).underlyingAsset(), address(erc721s[i]));
            assertEq(address(StERC721(stERC721s[i]).mintStrategy()), address(mockMintStrategy));
        }
    }

    function testBatchCreateStERC721_RevertIfInvalidParams() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](1); // 长度不匹配
        mintStrategies[0] = address(mockMintStrategy);

        StERC721 implementation = new StERC721();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidParams.selector));
        registry.batchCreateStERC721(erc721Addresses, address(implementation), mintStrategies);
    }

    function testUpgradeStERC721() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));

        StERC721 newImplementation = new StERC721();

        bytes memory encodedCallData = "";

        // bytes32 implBefore = vm.load(address(stERC721), IMPL_SLOT);
        // assertEq(implBefore, bytes32(uint256(uint160(address(implementation)))));
        assertEq(UpgradeableProxy(payable(stERC721)).implementation(), address(implementation));

        registry.upgradeStERC721(stERC721, address(newImplementation), encodedCallData);
        vm.stopPrank();

        // bytes32 implAfter = vm.load(address(stERC721), IMPL_SLOT);
        // assertEq(implAfter, bytes32(uint256(uint160(address(newImplementation)))));
        assertEq(UpgradeableProxy(payable(stERC721)).implementation(), address(newImplementation));
    }

    function testUpgradeStERC721_RevertIfStERC721Nonexist() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 newImplementation = new StERC721();
        bytes memory encodedCallData = "";

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, address(erc721)));
        registry.upgradeStERC721(address(erc721), address(newImplementation), encodedCallData);
    }

    function testBatchUpgradeStERC721() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address[] memory stERC721s =
            registry.batchCreateStERC721(erc721Addresses, address(implementation), mintStrategies);

        for (uint256 i = 0; i < stERC721s.length; i++) {
            assertEq(UpgradeableProxy(payable(stERC721s[i])).implementation(), address(implementation));
        }

        StERC721 newImplementation = new StERC721();

        bytes[] memory encodedCallDatas = new bytes[](2);
        encodedCallDatas[0] = "";
        encodedCallDatas[1] = "";

        registry.batchUpgradeStERC721(stERC721s, address(newImplementation), encodedCallDatas);
        vm.stopPrank();

        for (uint256 i = 0; i < stERC721s.length; i++) {
            assertEq(UpgradeableProxy(payable(stERC721s[i])).implementation(), address(newImplementation));
        }
    }

    function testBatchUpgradeStERC721_RevertIfInvalidParams() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address[] memory stERC721s =
            registry.batchCreateStERC721(erc721Addresses, address(implementation), mintStrategies);
        vm.stopPrank();

        StERC721 newImplementation = new StERC721();

        bytes[] memory encodedCallDatas = new bytes[](1);
        encodedCallDatas[0] = "";

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidParams.selector));
        registry.batchUpgradeStERC721(stERC721s, address(newImplementation), encodedCallDatas);
    }

    function testSetBaseURI_Owner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        string memory baseURI = "https://example.com/metadata/";
        registry.setBaseURI(stERC721, baseURI);
        uint256[] memory tokenIds = new uint256[](1);
        uint256 tokenId = 1;
        tokenIds[0] = tokenId;
        erc721.mint(owner, tokenId);
        erc721.setApprovalForAll(address(stERC721), true);

        StERC721(stERC721).mint(tokenIds);

        assertEq(StERC721(stERC721).tokenURI(1), string(abi.encodePacked(baseURI, "1")));
        vm.stopPrank();
    }

    function testSetBaseURI_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        string memory baseURI = "https://example.com/metadata/";

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.setBaseURI(stERC721, baseURI);
        vm.stopPrank();
    }

    function testSetMintStrategy_Owner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        assertEq(address(StERC721(stERC721).mintStrategy()), address(mockMintStrategy));

        registry.setMintStrategy(stERC721, address(newMintStrategy));
        assertEq(address(StERC721(stERC721).mintStrategy()), address(newMintStrategy));
        vm.stopPrank();
    }

    function testSetMintStrategy_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.setMintStrategy(stERC721, address(newMintStrategy));
        vm.stopPrank();
    }

    function testSetMintStrategy_RevertIfStERC721Nonexist() public {
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, address(0x123)));
        registry.setMintStrategy(address(0x123), address(newMintStrategy));
    }

    // OnlyStERC721 modifier tests
    function testOnlyStERC721Modifier_UpgradeStERC721() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();
        StERC721 newImplementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // Test with valid stERC721 address - should succeed
        bytes memory encodedCallData = "";
        vm.prank(owner);
        registry.upgradeStERC721(stERC721, address(newImplementation), encodedCallData);

        // Test with invalid stERC721 address - should fail
        address invalidStERC721 = address(0x123);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, invalidStERC721));
        registry.upgradeStERC721(invalidStERC721, address(newImplementation), encodedCallData);
    }

    function testOnlyStERC721Modifier_BatchUpgradeStERC721() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        address[] memory mintStrategies = new address[](2);
        mintStrategies[0] = address(mockMintStrategy);
        mintStrategies[1] = address(mockMintStrategy);

        StERC721 implementation = new StERC721();
        StERC721 newImplementation = new StERC721();

        vm.startPrank(owner);
        address[] memory stERC721s =
            registry.batchCreateStERC721(erc721Addresses, address(implementation), mintStrategies);
        vm.stopPrank();

        // Test with valid stERC721 addresses - should succeed
        bytes[] memory encodedCallDatas = new bytes[](2);
        encodedCallDatas[0] = "";
        encodedCallDatas[1] = "";

        vm.prank(owner);
        registry.batchUpgradeStERC721(stERC721s, address(newImplementation), encodedCallDatas);

        // Test with one invalid stERC721 address - should fail
        address[] memory mixedStERC721s = new address[](2);
        mixedStERC721s[0] = stERC721s[0]; // Valid
        mixedStERC721s[1] = address(0x123); // Invalid

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, address(0x123)));
        registry.batchUpgradeStERC721(mixedStERC721s, address(newImplementation), encodedCallDatas);
    }

    function testOnlyStERC721Modifier_SetBaseURI() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        string memory baseURI = "https://example.com/metadata/";

        // Test with valid stERC721 address - should succeed
        vm.prank(owner);
        registry.setBaseURI(stERC721, baseURI);

        // Test with invalid stERC721 address - should fail
        address invalidStERC721 = address(0x456);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, invalidStERC721));
        registry.setBaseURI(invalidStERC721, baseURI);
    }

    function testOnlyStERC721Modifier_SetMintStrategy() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // Test with valid stERC721 address - should succeed
        vm.prank(owner);
        registry.setMintStrategy(stERC721, address(newMintStrategy));

        // Test with invalid stERC721 address - should fail
        address invalidStERC721 = address(0x789);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, invalidStERC721));
        registry.setMintStrategy(invalidStERC721, address(newMintStrategy));
    }

    function testOnlyStERC721Modifier_ZeroAddress() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // Test with zero address - should fail
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, address(0)));
        registry.setBaseURI(address(0), "https://example.com/");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, address(0)));
        registry.setMintStrategy(address(0), address(newMintStrategy));
    }

    function testOnlyStERC721Modifier_NonExistentAddress() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // Test with a random non-existent address - should fail
        address randomAddress = address(0xDEADBEEF);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, randomAddress));
        registry.setBaseURI(randomAddress, "https://example.com/");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, randomAddress));
        registry.setMintStrategy(randomAddress, address(newMintStrategy));
    }

    function testOnlyStERC721Modifier_AfterStERC721Removal() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();
        MockMintStrategy newMintStrategy = new MockMintStrategy();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        // First, verify the stERC721 exists and operations work
        vm.prank(owner);
        registry.setBaseURI(stERC721, "https://example.com/");

        // Test that operations still work after some time
        vm.prank(owner);
        registry.setMintStrategy(stERC721, address(newMintStrategy));
    }

    // SetSymbol tests
    function testSetSymbol_Owner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));

        // Check initial name and symbol
        assertEq(StERC721(stERC721).name(), "StERC721 TEST");
        assertEq(StERC721(stERC721).symbol(), "StTEST");

        // Set new symbol
        string memory newSymbol = "CUSTOM";
        registry.setSymbol(stERC721, newSymbol);

        // Check updated name and symbol
        assertEq(StERC721(stERC721).name(), "StERC721 CUSTOM");
        assertEq(StERC721(stERC721).symbol(), "StCUSTOM");
        vm.stopPrank();
    }

    function testSetSymbol_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));
        vm.stopPrank();

        string memory newSymbol = "CUSTOM";

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.setSymbol(stERC721, newSymbol);
        vm.stopPrank();
    }

    function testSetSymbol_RevertIfStERC721Nonexist() public {
        string memory newSymbol = "CUSTOM";

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StERC721NotExists.selector, address(0x123)));
        registry.setSymbol(address(0x123), newSymbol);
    }

    function testSetSymbol_EmptySymbol() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));

        // Set empty symbol
        string memory emptySymbol = "";
        vm.expectRevert(abi.encodeWithSelector(InvalidParams.selector));
        registry.setSymbol(stERC721, emptySymbol);
        vm.stopPrank();
    }

    function testSetSymbol_LongSymbol() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));

        // Set long symbol
        string memory longSymbol = "VERY_LONG_SYMBOL_NAME";
        registry.setSymbol(stERC721, longSymbol);

        // Check updated name and symbol
        assertEq(StERC721(stERC721).name(), "StERC721 VERY_LONG_SYMBOL_NAME");
        assertEq(StERC721(stERC721).symbol(), "StVERY_LONG_SYMBOL_NAME");
        vm.stopPrank();
    }

    function testSetSymbol_MultipleUpdates() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation), address(mockMintStrategy));

        // First update
        registry.setSymbol(stERC721, "FIRST");
        assertEq(StERC721(stERC721).name(), "StERC721 FIRST");
        assertEq(StERC721(stERC721).symbol(), "StFIRST");

        // Second update
        registry.setSymbol(stERC721, "SECOND");
        assertEq(StERC721(stERC721).name(), "StERC721 SECOND");
        assertEq(StERC721(stERC721).symbol(), "StSECOND");

        // Third update
        registry.setSymbol(stERC721, "THIRD");
        assertEq(StERC721(stERC721).name(), "StERC721 THIRD");
        assertEq(StERC721(stERC721).symbol(), "StTHIRD");
        vm.stopPrank();
    }
}
