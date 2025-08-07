// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {FidenzaMintStrategy} from "../src/extensions/FidenzaMintStrategy.sol";
import {MockArtBlocks} from "./mock/MockArtBlocks.sol";
import {InvalidERC721} from "../src/interfaces/IErrors.sol";

contract FidenzaMintStrategyTest is Test {
    FidenzaMintStrategy public fidenzaMintStrategy;
    MockArtBlocks public mockArtBlocks;
    uint256 public constant FIDENZA_PROJECT_ID = 78;
    address public artBlocksAddress;

    function setUp() public {
        mockArtBlocks = new MockArtBlocks();
        artBlocksAddress = address(mockArtBlocks);
        fidenzaMintStrategy = new FidenzaMintStrategy(artBlocksAddress, FIDENZA_PROJECT_ID);
    }

    function testConstructor() public view {
        assertEq(address(fidenzaMintStrategy.artBlocks()), artBlocksAddress);
        assertEq(fidenzaMintStrategy.fidenzaProjectId(), FIDENZA_PROJECT_ID);
    }

    function testMintable_ValidFidenzaToken() public {
        uint256 tokenId = 12345;

        // Set tokenId to belong to Fidenza project
        mockArtBlocks.setTokenIdToProjectId(tokenId, FIDENZA_PROJECT_ID);

        bool isMintable = fidenzaMintStrategy.mintable(artBlocksAddress, tokenId);
        assertTrue(isMintable);
    }

    function testMintable_InvalidProjectId() public {
        uint256 tokenId = 12345;
        uint256 otherProjectId = 79; // Different project ID

        // Set tokenId to belong to a different project
        mockArtBlocks.setTokenIdToProjectId(tokenId, otherProjectId);

        bool isMintable = fidenzaMintStrategy.mintable(artBlocksAddress, tokenId);
        assertFalse(isMintable);
    }

    function testMintable_DifferentERC721Address() public {
        uint256 tokenId = 12345;
        address differentERC721 = address(0x123);

        // Set tokenId to belong to Fidenza project
        mockArtBlocks.setTokenIdToProjectId(tokenId, FIDENZA_PROJECT_ID);

        vm.expectRevert(abi.encodeWithSelector(InvalidERC721.selector, differentERC721));
        fidenzaMintStrategy.mintable(differentERC721, tokenId);
    }

    function testMintable_MultipleTokens() public {
        uint256 fidenzaToken1 = 1000;
        uint256 fidenzaToken2 = 2000;
        uint256 otherToken1 = 3000;
        uint256 otherToken2 = 4000;

        // Set up tokens
        mockArtBlocks.setTokenIdToProjectId(fidenzaToken1, FIDENZA_PROJECT_ID);
        mockArtBlocks.setTokenIdToProjectId(fidenzaToken2, FIDENZA_PROJECT_ID);
        mockArtBlocks.setTokenIdToProjectId(otherToken1, 79);
        mockArtBlocks.setTokenIdToProjectId(otherToken2, 80);

        // Test Fidenza tokens should be mintable
        assertTrue(fidenzaMintStrategy.mintable(artBlocksAddress, fidenzaToken1));
        assertTrue(fidenzaMintStrategy.mintable(artBlocksAddress, fidenzaToken2));

        // Test other tokens should not be mintable
        assertFalse(fidenzaMintStrategy.mintable(artBlocksAddress, otherToken1));
        assertFalse(fidenzaMintStrategy.mintable(artBlocksAddress, otherToken2));
    }

    function testMintable_ZeroTokenId() public {
        uint256 tokenId = 0;

        // Set tokenId 0 to belong to Fidenza project
        mockArtBlocks.setTokenIdToProjectId(tokenId, FIDENZA_PROJECT_ID);

        bool isMintable = fidenzaMintStrategy.mintable(artBlocksAddress, tokenId);
        assertTrue(isMintable);
    }

    function testMintable_LargeTokenId() public {
        uint256 tokenId = 999999;

        // Set large tokenId to belong to Fidenza project
        mockArtBlocks.setTokenIdToProjectId(tokenId, FIDENZA_PROJECT_ID);

        bool isMintable = fidenzaMintStrategy.mintable(artBlocksAddress, tokenId);
        assertTrue(isMintable);
    }

    function testMintable_UnsetTokenId() public view {
        uint256 tokenId = 12345;

        // Don't set the tokenId, so it will return 0 by default

        bool isMintable = fidenzaMintStrategy.mintable(artBlocksAddress, tokenId);
        assertFalse(isMintable);
    }

    function testMintable_WithStERC721Integration() public {
        // This test simulates how FidenzaMintStrategy would work with StERC721
        uint256 fidenzaTokenId = 12345;
        uint256 otherTokenId = 67890;

        // Set up tokens
        mockArtBlocks.setTokenIdToProjectId(fidenzaTokenId, FIDENZA_PROJECT_ID);
        mockArtBlocks.setTokenIdToProjectId(otherTokenId, 79);

        // Simulate StERC721 mint logic
        bool fidenzaMintable = fidenzaMintStrategy.mintable(artBlocksAddress, fidenzaTokenId);
        bool otherMintable = fidenzaMintStrategy.mintable(artBlocksAddress, otherTokenId);

        assertTrue(fidenzaMintable, "Fidenza token should be mintable");
        assertFalse(otherMintable, "Other token should not be mintable");
    }

    function testMintable_BatchValidation() public {
        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = 1000; // Fidenza
        tokenIds[1] = 2000; // Other project
        tokenIds[2] = 3000; // Fidenza
        tokenIds[3] = 4000; // Other project
        tokenIds[4] = 5000; // Fidenza

        // Set up tokens
        mockArtBlocks.setTokenIdToProjectId(1000, FIDENZA_PROJECT_ID);
        mockArtBlocks.setTokenIdToProjectId(2000, 79);
        mockArtBlocks.setTokenIdToProjectId(3000, FIDENZA_PROJECT_ID);
        mockArtBlocks.setTokenIdToProjectId(4000, 80);
        mockArtBlocks.setTokenIdToProjectId(5000, FIDENZA_PROJECT_ID);

        // Test each token individually
        assertTrue(fidenzaMintStrategy.mintable(artBlocksAddress, 1000));
        assertFalse(fidenzaMintStrategy.mintable(artBlocksAddress, 2000));
        assertTrue(fidenzaMintStrategy.mintable(artBlocksAddress, 3000));
        assertFalse(fidenzaMintStrategy.mintable(artBlocksAddress, 4000));
        assertTrue(fidenzaMintStrategy.mintable(artBlocksAddress, 5000));
    }
}
