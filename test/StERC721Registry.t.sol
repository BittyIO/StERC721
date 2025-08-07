// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {StERC721} from "../src/StERC721.sol";
import {MintableERC721} from "./mock/MintableERC721.sol";
import {StERC721Registry} from "../src/StERC721Registry.sol";
import {AssetVaultRegistry} from "../src/AssetVaultRegistry.sol";
import {AssetVault} from "../src/AssetVault.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAssetVaultRegistry} from "../src/interfaces/IAssetVaultRegistry.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";
import {StERC721AlreadyExists, InvalidAddress, StERC721NotExists} from "../src/interfaces/IErrors.sol";

contract StERC721RegistryTest is Test {
    // bytes32 internal constant IMPL_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    StERC721Registry public registry;
    AssetVaultRegistry public assetVaultRegistry;
    address public delegationRegistry;
    address public owner;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        delegationRegistry = makeAddr("delegationRegistry");

        vm.startPrank(owner);
        AssetVault implementation = new AssetVault();
        assetVaultRegistry = new AssetVaultRegistry();
        assetVaultRegistry.initialize(address(implementation), delegationRegistry);
        registry = new StERC721Registry();
        registry.initialize("eth", IAssetVaultRegistry(address(assetVaultRegistry)));
        assetVaultRegistry.transferOwnership(address(registry));
        vm.stopPrank();
    }

    function testDisableInitializers() public {
        vm.startPrank(owner);
        StERC721Registry registry1 = new StERC721Registry();
        registry1.disableInitializers();
        vm.expectRevert();
        registry1.initialize("eth", IAssetVaultRegistry(address(assetVaultRegistry)));
        vm.stopPrank();
    }

    function testCreateStERC721_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.createStERC721(address(erc721), address(implementation));
    }

    function testBatchCreateStERC721_RevertIfNotOwner() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        StERC721 implementation = new StERC721();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.batchCreateStERC721(erc721Addresses, address(implementation));
    }

    function testUpgradeStERC721_RevertIfNotOwner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        registry.createStERC721(address(erc721), address(implementation));
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

        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        registry.batchCreateStERC721(erc721Addresses, address(implementation));
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
        address stERC721 = registry.createStERC721(address(erc721), address(implementation));

        assertEq(registry.getStERC721(address(erc721)), stERC721);
        assertEq(StERC721(stERC721).name(), "StERC721 TEST");
        assertEq(StERC721(stERC721).symbol(), "StTEST");
        assertEq(StERC721(stERC721).underlyingAsset(), address(erc721));
    }

    function testCreateStERC721_RevertIfAssetExist() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        registry.createStERC721(address(erc721), address(implementation));

        vm.expectRevert(abi.encodeWithSelector(StERC721AlreadyExists.selector, address(erc721)));
        registry.createStERC721(address(erc721), address(implementation));
        vm.stopPrank();
    }

    function testCreateStERC721_RevertIfImplZeroAddress() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
        registry.createStERC721(address(erc721), address(0));
    }

    function testBatchCreateStERC721() public {
        MintableERC721[] memory erc721s = new MintableERC721[](2);
        erc721s[0] = new MintableERC721("Test1", "TEST1");
        erc721s[1] = new MintableERC721("Test2", "TEST2");

        address[] memory erc721Addresses = new address[](2);
        erc721Addresses[0] = address(erc721s[0]);
        erc721Addresses[1] = address(erc721s[1]);

        StERC721 implementation = new StERC721();

        vm.prank(owner);
        address[] memory stERC721s = registry.batchCreateStERC721(erc721Addresses, address(implementation));

        for (uint256 i = 0; i < erc721s.length; i++) {
            assertEq(registry.getStERC721(address(erc721s[i])), stERC721s[i]);
            assertEq(StERC721(stERC721s[i]).underlyingAsset(), address(erc721s[i]));
        }
    }

    function testUpgradeStERC721() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation));

        StERC721 newImplementation = new StERC721();

        bytes memory encodedCallData = "";

        // bytes32 implBefore = vm.load(address(stERC721), IMPL_SLOT);
        // assertEq(implBefore, bytes32(uint256(uint160(address(implementation)))));
        assertEq(UpgradeableProxy(payable(stERC721)).implementation(), address(implementation));

        registry.upgradeStERC721(address(erc721), address(newImplementation), encodedCallData);
        vm.stopPrank();

        // bytes32 implAfter = vm.load(address(stERC721), IMPL_SLOT);
        // assertEq(implAfter, bytes32(uint256(uint160(address(newImplementation)))));
        assertEq(UpgradeableProxy(payable(stERC721)).implementation(), address(newImplementation));

        assertEq(registry.getStERC721(address(erc721)), stERC721);
    }

    function testUpgradeStERC721_RevertIfAssetNonexist() public {
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

        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address[] memory stERC721s = registry.batchCreateStERC721(erc721Addresses, address(implementation));

        for (uint256 i = 0; i < stERC721s.length; i++) {
            assertEq(UpgradeableProxy(payable(stERC721s[i])).implementation(), address(implementation));
        }

        StERC721 newImplementation = new StERC721();

        bytes[] memory encodedCallDatas = new bytes[](2);
        encodedCallDatas[0] = "";
        encodedCallDatas[1] = "";

        registry.batchUpgradeStERC721(erc721Addresses, address(newImplementation), encodedCallDatas);
        vm.stopPrank();

        for (uint256 i = 0; i < stERC721s.length; i++) {
            assertEq(UpgradeableProxy(payable(stERC721s[i])).implementation(), address(newImplementation));
        }
    }

    function testSetBaseURI_Owner() public {
        MintableERC721 erc721 = new MintableERC721("Test", "TEST");
        StERC721 implementation = new StERC721();

        vm.startPrank(owner);
        address stERC721 = registry.createStERC721(address(erc721), address(implementation));
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
        address stERC721 = registry.createStERC721(address(erc721), address(implementation));
        vm.stopPrank();

        string memory baseURI = "https://example.com/metadata/";

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.setBaseURI(stERC721, baseURI);
        vm.stopPrank();
    }
}
