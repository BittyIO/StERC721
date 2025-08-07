// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {
    ERC721EnumerableUpgradeable,
    ERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IStERC721} from "./interfaces/IStERC721.sol";
import {IAssetVault} from "./interfaces/IAssetVault.sol";
import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";
import {InvalidERC721, InvalidERC721Owner} from "./interfaces/IErrors.sol";

contract StERC721 is IStERC721, OwnableUpgradeable, ReentrancyGuardUpgradeable, ERC721EnumerableUpgradeable {
    using Clones for address;

    IERC721Metadata private _erc721;
    IAssetVaultRegistry public assetVaultRegistry;
    string private _customBaseURI;
    string private _chainName;

    function disableInitializers() external override {
        _disableInitializers();
    }

    function initialize(
        string memory chainName_,
        IERC721Metadata erc721_,
        IAssetVaultRegistry assetVaultRegistry_,
        string memory name_,
        string memory symbol_
    ) external override initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __ERC721_init(name_, symbol_);
        __ERC721Enumerable_init();
        _erc721 = erc721_;
        assetVaultRegistry = assetVaultRegistry_;
        _chainName = chainName_;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IStERC721).interfaceId || super.supportsInterface(interfaceId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external view override returns (bytes4) {
        if (msg.sender != address(_erc721)) {
            revert InvalidERC721(msg.sender);
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function mint(uint256[] calldata tokenIds_) external override nonReentrant {
        address staker_ = msg.sender;
        address assetVault_ = assetVaultRegistry.create(staker_);
        uint256 tokenId_;
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            tokenId_ = tokenIds_[i];
            _erc721.safeTransferFrom(staker_, address(assetVault_), tokenId_);
            assetVaultRegistry.stakedERC721(staker_, address(_erc721), tokenId_);
            _safeMint(staker_, tokenId_);
        }
        emit Minted(staker_, tokenIds_);
    }

    function burn(uint256[] calldata tokenIds_) external override nonReentrant {
        _burn(tokenIds_, msg.sender);
    }

    function burn(uint256[] calldata tokenIds_, address receiver_) external override nonReentrant {
        _burn(tokenIds_, receiver_);
    }

    function _burn(uint256[] calldata tokenIds_, address receiver_) internal {
        uint256 tokenId_;
        address staker_ = msg.sender;
        address assetVault_;
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            tokenId_ = tokenIds_[i];
            if (staker_ != ownerOf(tokenId_)) {
                revert InvalidERC721Owner(address(_erc721), tokenId_);
            }
            assetVault_ = assetVaultRegistry.getAssetVault(staker_);
            _burn(tokenId_);
            assetVaultRegistry.unstakeERC721(staker_, receiver_, address(_erc721), tokenId_);
        }
        emit Burned(staker_, receiver_, tokenIds_);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(IERC721, ERC721Upgradeable) {
        assetVaultRegistry.transferERC721(from, to, address(_erc721), tokenId);
        super.transferFrom(from, to, tokenId);
    }

    function underlyingAsset() external view override returns (address) {
        return address(_erc721);
    }

    function setBaseURI(string memory baseURI_) external override onlyOwner {
        _customBaseURI = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _customBaseURI;
    }

    function tokenURI(uint256 tokenId_)
        public
        view
        override(ERC721Upgradeable, IERC721Metadata)
        returns (string memory)
    {
        if (bytes(_customBaseURI).length > 0) {
            return super.tokenURI(tokenId_);
        }

        return _erc721.tokenURI(tokenId_);
    }

    function contractURI() external view override returns (string memory) {
        string memory hexAddress = Strings.toHexString(uint256(uint160(address(this))), 20);
        return string(abi.encodePacked("https://metadata.bitty.io/", _chainName, "/", hexAddress));
    }

    function setDelegateCashV2(address delegate_, uint256[] calldata tokenIds_, bytes32 rights_, bool value_)
        external
        override
        nonReentrant
        returns (bytes32[] memory delegationHashes)
    {
        address tokenOwner_;
        uint256 tokenId_;
        delegationHashes = new bytes32[](tokenIds_.length);
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            tokenId_ = tokenIds_[i];
            tokenOwner_ = ownerOf(tokenId_);
            if (msg.sender != tokenOwner_) {
                revert InvalidERC721Owner(address(_erc721), tokenId_);
            }
            delegationHashes[i] = assetVaultRegistry.setDelegateCashV2(
                tokenOwner_, delegate_, address(_erc721), tokenId_, rights_, value_
            );
        }
    }

    function getDelegateCashForTokenV2(uint256[] calldata tokenIds_)
        external
        view
        override
        returns (address[][] memory delegates)
    {
        delegates = new address[][](tokenIds_.length);
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            address assetVault_ = assetVaultRegistry.getAssetVault(ownerOf(tokenIds_[i]));
            delegates[i] = IAssetVault(assetVault_).getDelegateCashForTokenV2(address(_erc721), tokenIds_[i]);
        }
    }
}
