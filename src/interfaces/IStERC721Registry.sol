// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

interface IStERC721Registry {
    event Minted(address indexed to, uint256[] tokenId);
    event Burned(address indexed from, uint256[] tokenId);

    function createStERC721(address erc721, address stERC721Impl) external returns (address stERC721);
    function batchCreateStERC721(address[] calldata erc721s, address stERC721Impl)
        external
        returns (address[] memory stERC721s);
    function upgradeStERC721(address erc721, address stERC721Impl, bytes calldata encodedCallData) external;
    function batchUpgradeStERC721(address[] calldata erc721s, address stERC721Impl, bytes[] calldata encodedCallDatas)
        external;
}
