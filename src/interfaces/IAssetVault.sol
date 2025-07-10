// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

interface IAssetVault {

    function disableInitializers() external;
    
    function initialize(address owner_, address delegationRegistryV2_) external;

    function owner() external view returns (address);

    function setDelegateCashV2(address delegate_, address erc721_, uint256 tokenId_, bytes32 rights_, bool value_)
        external
        returns (bytes32 delegationHash);

    function getDelegateCashForTokenV2(address erc721_, uint256 tokenId_) external view returns (address[] memory);

    function withdrawERC721(address to_, address erc721_, uint256 tokenId_) external;

    function withdrawERC20(address to_, address token_, uint256 amount_) external;

    function withdrawERC1155(
        address token,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}
