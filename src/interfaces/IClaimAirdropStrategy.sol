// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

interface IClaimAirdropStrategy {
    function proofAsset()
        external
        view
        returns (address[] memory erc20Tokens, address[] memory erc721Tokens, address[] memory erc1155Tokens);
    function claim(address to_, bytes memory data_) external;
}
