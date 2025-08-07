// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IMintStrategy} from "../../src/interfaces/IMintStrategy.sol";

contract MockMintStrategy is IMintStrategy {
    bool public allMintable;
    mapping(address => mapping(uint256 => bool)) public mintableTokens;

    constructor() {
        allMintable = true;
    }

    function setMintable(address erc721_, uint256 tokenId, bool mintable_) external {
        allMintable = false;
        mintableTokens[erc721_][tokenId] = mintable_;
    }

    function mintable(address erc721_, uint256 tokenId) external view override returns (bool) {
        if (allMintable) {
            return true;
        }
        return mintableTokens[erc721_][tokenId];
    }
}
