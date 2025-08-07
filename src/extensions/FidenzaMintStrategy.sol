// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IMintStrategy} from "../interfaces/IMintStrategy.sol";
import {IArtBlocks} from "./interfaces/IArtBlocks.sol";
import {InvalidERC721} from "../interfaces/IErrors.sol";

contract FidenzaMintStrategy is IMintStrategy {
    IArtBlocks public immutable artBlocks;
    uint256 public immutable fidenzaProjectId;

    constructor(address artBlocks_, uint256 fidenzaProjectId_) {
        artBlocks = IArtBlocks(artBlocks_);
        fidenzaProjectId = fidenzaProjectId_;
    }

    function mintable(address erc721_, uint256 tokenId) external view override returns (bool) {
        if (erc721_ != address(artBlocks)) {
            revert InvalidERC721(erc721_);
        }
        return artBlocks.tokenIdToProjectId(tokenId) == fidenzaProjectId;
    }
}
