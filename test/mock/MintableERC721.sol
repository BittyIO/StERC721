// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.29;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title MintableERC721
 * @dev ERC721 minting logic
 */
contract MintableERC721 is ERC721Enumerable {
    string public baseURI;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        baseURI = "https://MintableERC721/";
    }

    function safeMint(address to, uint256 tokenId) public returns (bool) {
        _safeMint(to, tokenId);
        return true;
    }

    function mint(address to, uint256 tokenId) public returns (bool) {
        _mint(to, tokenId);
        return true;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
}
