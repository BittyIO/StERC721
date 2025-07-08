// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

interface IAssetVault {
    function initialize(address delegationRegistryV2_) external;

    function setDelegateCashV2(address delegate_, address nft_, uint256 tokenId_, bytes32 rights_, bool value_)
        external;

    function getDelegateCashForTokenV2(address nft_, uint256 tokenId_) external view returns (address[] memory);

    function withdrawERC721(address to_, address nft_, uint256 tokenId_) external;

    function withdrawERC20(address to_, address token_, uint256 amount_) external;

    function withdrawERC1155(
        address token,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}
