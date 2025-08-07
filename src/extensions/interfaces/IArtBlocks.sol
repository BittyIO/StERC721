// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

interface IArtBlocks {
    function tokenIdToProjectId(uint256 tokenId) external view returns (uint256);
}
