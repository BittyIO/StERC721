// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IClaimAirdropStrategy} from "./IClaimAirdropStrategy.sol";

interface IAssetVault {
    function disableInitializers() external;

    function initialize(address owner_, address delegationRegistryV2_) external;

    function owner() external view returns (address);

    function setDelegateCashV2(address delegate_, address erc721_, uint256 tokenId_, bytes32 rights_, bool value_)
        external
        returns (bytes32 delegationHash);

    function getDelegateCashForTokenV2(address erc721_, uint256 tokenId_) external view returns (address[] memory);

    function isERC721Staked(address erc721_, uint256 tokenId_) external view returns (bool);

    function stakeERC721(address erc721_, uint256 tokenId_) external;

    function unstakeERC721(address erc721_, uint256 tokenId_) external;

    function transferERC721(address to_, address erc721_, uint256 tokenId_) external;

    function transferNonStakedERC721(address to_, address erc721_, uint256 tokenId_) external;

    function transferERC20(address to_, address token_, uint256 amount_) external;

    function transferERC1155(address to_, address token_, uint256 id_, uint256 amount_, bytes calldata data_)
        external;

    function delegateCall(address target_, bytes memory data_) external returns (bytes memory);
}
