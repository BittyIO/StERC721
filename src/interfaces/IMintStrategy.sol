// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

interface IMintStrategy {
    function mintable(address erc721_, uint256 tokenId) external view returns (bool);
}
