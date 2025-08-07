// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IClaimAirdropStrategy} from "./interfaces/IClaimAirdropStrategy.sol";
import {IDelegateRegistryV2} from "./interfaces/IDelegateRegistryV2.sol";
import {IAssetVault} from "./interfaces/IAssetVault.sol";
import {MissingStakedERC721, InvalidAddress, InvalidERC721Owner} from "./interfaces/IErrors.sol";

contract AssetVault is IAssetVault, IERC721Receiver, IERC1155Receiver, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    IDelegateRegistryV2 public delegationRegistryV2;
    EnumerableSet.AddressSet private _stakedERC721;
    mapping(address => EnumerableSet.UintSet) private _stakedERC721TokenIds;

    modifier keepStaked() {
        _;
        uint256 erc721Length = _stakedERC721.length();
        for (uint256 i = 0; i < erc721Length; i++) {
            address erc721 = _stakedERC721.at(i);
            uint256 tokenIdLength = _stakedERC721TokenIds[erc721].length();
            for (uint256 j = 0; j < tokenIdLength; j++) {
                uint256 tokenId = _stakedERC721TokenIds[erc721].at(j);
                if (IERC721(erc721).ownerOf(tokenId) != address(this)) {
                    revert MissingStakedERC721(erc721);
                }
            }
        }
    }

    function disableInitializers() external override {
        _disableInitializers();
    }

    function owner() public view virtual override(IAssetVault, OwnableUpgradeable) returns (address) {
        return super.owner();
    }

    function initialize(address owner_, address delegationRegistryV2_) external override initializer {
        __Ownable_init(owner_);
        delegationRegistryV2 = IDelegateRegistryV2(delegationRegistryV2_);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IAssetVault).interfaceId || interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function setDelegateCashV2(address delegate_, address erc721_, uint256 tokenId_, bytes32 rights_, bool value_)
        external
        override
        onlyOwner
        returns (bytes32 delegationHash)
    {
        if (delegate_ == address(0)) {
            revert InvalidAddress(delegate_);
        }
        return delegationRegistryV2.delegateERC721(delegate_, erc721_, tokenId_, rights_, value_);
    }

    function getDelegateCashForTokenV2(address erc721_, uint256 tokenId_)
        external
        view
        override
        returns (address[] memory delegates)
    {
        IDelegateRegistryV2.Delegation[] memory allDelegations =
            delegationRegistryV2.getOutgoingDelegations(address(this));

        uint256 tokenDelegatesNum;
        for (uint256 j = 0; j < allDelegations.length; j++) {
            if (allDelegations[j].contract_ == erc721_ && allDelegations[j].tokenId == tokenId_) {
                tokenDelegatesNum++;
            }
        }
        delegates = new address[](tokenDelegatesNum);
        uint256 tokenDelegateIdx;
        for (uint256 j = 0; j < allDelegations.length; j++) {
            if (allDelegations[j].contract_ == erc721_ && allDelegations[j].tokenId == tokenId_) {
                delegates[tokenDelegateIdx] = allDelegations[j].to;
                tokenDelegateIdx++;
            }
        }
    }

    function isERC721Staked(address erc721_, uint256 tokenId_) external view override returns (bool) {
        return _stakedERC721.contains(erc721_) && _stakedERC721TokenIds[erc721_].contains(tokenId_);
    }

    function stakeERC721(address erc721_, uint256 tokenId_) external override onlyOwner {
        if (IERC721(erc721_).ownerOf(tokenId_) != address(this)) {
            revert InvalidERC721Owner(erc721_, tokenId_);
        }
        _stakedERC721.add(erc721_);
        _stakedERC721TokenIds[erc721_].add(tokenId_);
    }

    function unstakeERC721(address erc721_, uint256 tokenId_) external override onlyOwner {
        if (IERC721(erc721_).ownerOf(tokenId_) == address(this)) {
            revert InvalidERC721Owner(erc721_, tokenId_);
        }
        _stakedERC721TokenIds[erc721_].remove(tokenId_);
        if (_stakedERC721TokenIds[erc721_].length() == 0) {
            _stakedERC721.remove(erc721_);
        }
    }

    function transferERC721(address to_, address erc721_, uint256 tokenId_) external override onlyOwner {
        IERC721(erc721_).safeTransferFrom(address(this), to_, tokenId_);
    }

    function transferNonStakedERC721(address to_, address erc721_, uint256 tokenId_)
        external
        override
        onlyOwner
        keepStaked
    {
        IERC721(erc721_).safeTransferFrom(address(this), to_, tokenId_);
    }

    function transferERC20(address to_, address token_, uint256 amount_) external override onlyOwner {
        IERC20(token_).safeTransfer(to_, amount_);
    }

    function transferERC1155(address to_, address token_, uint256 id_, uint256 amount_, bytes calldata data_)
        external
        override
        onlyOwner
    {
        IERC1155(token_).safeTransferFrom(address(this), to_, id_, amount_, data_);
    }

    function delegateCall(address target, bytes memory data)
        external
        override
        onlyOwner
        keepStaked
        returns (bytes memory)
    {
        return target.functionDelegateCall(data);
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
