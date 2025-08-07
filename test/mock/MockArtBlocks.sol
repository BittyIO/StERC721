// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IArtBlocks} from "../../src/extensions/interfaces/IArtBlocks.sol";

contract MockArtBlocks is IArtBlocks {
    mapping(uint256 => uint256) private _tokenIdToProjectId;

    function setTokenIdToProjectId(uint256 tokenId, uint256 projectId) external {
        _tokenIdToProjectId[tokenId] = projectId;
    }

    function tokenIdToProjectId(uint256 tokenId) external view override returns (uint256) {
        return _tokenIdToProjectId[tokenId];
    }
}
