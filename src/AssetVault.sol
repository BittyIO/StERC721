// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IDelegateRegistryV2} from "./interfaces/IDelegateRegistryV2.sol";
import {IAssetVault} from "./interfaces/IAssetVault.sol";

contract AssetVault is IAssetVault, IERC721Receiver, IERC1155Receiver, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    IDelegateRegistryV2 public delegationRegistryV2;

    function initialize(address delegationRegistryV2_) external override initializer {
        __Ownable_init(msg.sender);
        delegationRegistryV2 = IDelegateRegistryV2(delegationRegistryV2_);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IAssetVault).interfaceId || interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function setDelegateCashV2(address delegate_, address nft_, uint256 tokenId_, bytes32 rights_, bool value_)
        external
        override
        onlyOwner
    {
        require(delegate_ != address(0), "AssetVault: invalid delegate");
        delegationRegistryV2.delegateERC721(delegate_, nft_, tokenId_, rights_, value_);
    }

    function getDelegateCashForTokenV2(address nft_, uint256 tokenId_)
        external
        view
        override
        returns (address[] memory delegates)
    {
        IDelegateRegistryV2.Delegation[] memory allDelegations =
            delegationRegistryV2.getOutgoingDelegations(address(this));

        uint256 tokenDelegatesNum;
        for (uint256 j = 0; j < allDelegations.length; j++) {
            if (allDelegations[j].contract_ == nft_ && allDelegations[j].tokenId == tokenId_) {
                tokenDelegatesNum++;
            }
        }
        delegates = new address[](tokenDelegatesNum);
        uint256 tokenDelegateIdx;
        for (uint256 j = 0; j < allDelegations.length; j++) {
            if (allDelegations[j].contract_ == nft_ && allDelegations[j].tokenId == tokenId_) {
                delegates[tokenDelegateIdx] = allDelegations[j].to;
                tokenDelegateIdx++;
            }
        }
    }

    function withdrawERC721(address to_, address nft_, uint256 tokenId_) external override onlyOwner {
        IERC721(nft_).safeTransferFrom(address(this), to_, tokenId_);
    }

    function withdrawERC20(address to_, address token_, uint256 amount_) external override onlyOwner {
        IERC20(token_).safeTransferFrom(address(this), to_, amount_);
    }

    function withdrawERC1155(
        address token,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override onlyOwner {
        IERC1155(token).safeBatchTransferFrom(address(this), to, ids, amounts, data);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
