// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {
    ERC721EnumerableUpgradeable,
    ERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IStERC721} from "./interfaces/IStERC721.sol";
import {IAssetVault} from "./interfaces/IAssetVault.sol";
import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";

abstract contract StERC721 is IStERC721, OwnableUpgradeable, ReentrancyGuardUpgradeable, ERC721EnumerableUpgradeable {
    using Clones for address;

    IERC721Metadata private _erc721;
    IAssetVaultRegistry public assetVaultRegistry;
    string private _customBaseURI;
    mapping(address => bool) private _authorized;

    function initialize(
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
        require(msg.sender == address(_erc721), "StNft: nft not acceptable");
        return IERC721Receiver.onERC721Received.selector;
    }

    function mint(address to_, uint256[] calldata tokenIds_) external override nonReentrant {
        address staker_ = msg.sender;
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            IAssetVault assetVault_ = assetVaultRegistry.create(staker_);
            _erc721.safeTransferFrom(staker_, address(assetVault_), tokenIds_[i]);
            _safeMint(to_, tokenIds_[i]);
        }
        emit Minted(to_, tokenIds_);
    }

    function burn(uint256[] calldata tokenIds_) external override nonReentrant {
        uint256 tokenId_;
        address staker_ = msg.sender;
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            tokenId_ = tokenIds_[i];
            require(staker_ == ownerOf(tokenId_), "stNft: only owner can burn");
            IAssetVault assetVault_ = assetVaultRegistry.create(staker_);
            require(address(assetVault_) == _erc721.ownerOf(tokenId_), "stNft: invalid tokenId_");
            _burn(tokenId_);
            assetVault_.withdrawERC721(staker_, address(_erc721), tokenId_);
        }
        emit Burned(staker_, tokenIds_);
    }

    function underlyingAsset() external view override returns (address) {
        return address(_erc721);
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
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
        return string(abi.encodePacked("https://metadata.bitty.io/eth/", hexAddress));
    }

    function setDelegateCashV2(address delegate_, uint256[] calldata tokenIds_, bytes32 rights_, bool value_)
        external
        override
        nonReentrant
    {
        address tokenOwner_;
        uint256 tokenId_;
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            tokenId_ = tokenIds_[i];
            tokenOwner_ = ownerOf(tokenId_);
            require(msg.sender == tokenOwner_, "stNft: only owner can delegate");
            assetVaultRegistry.create(tokenOwner_).setDelegateCashV2(
                delegate_, address(_erc721), tokenId_, rights_, value_
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
            IAssetVault assetVault_ = assetVaultRegistry.get(ownerOf(tokenIds_[i]));
            if (address(assetVault_) == address(0)) {
                continue;
            }
            delegates[i] = assetVault_.getDelegateCashForTokenV2(address(_erc721), tokenIds_[i]);
        }
    }
}
