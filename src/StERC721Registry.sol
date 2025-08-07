// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {UpgradeableProxy} from "./UpgradeableProxy.sol";
import {IStERC721} from "./interfaces/IStERC721.sol";
import {IStERC721Registry} from "./interfaces/IStERC721Registry.sol";
import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";
import {InvalidAddress, StERC721AlreadyExists, StERC721NotExists} from "./interfaces/IErrors.sol";

contract StERC721Registry is OwnableUpgradeable, ReentrancyGuardUpgradeable, IStERC721Registry {
    string private _chainName;
    string public constant namePrefix = "StERC721";
    string public constant symbolPrefix = "St";
    mapping(address => address) public stERC721s;
    IAssetVaultRegistry public assetVaultRegistry;

    function disableInitializers() external override {
        _disableInitializers();
    }

    function initialize(string memory chainName_, IAssetVaultRegistry assetVaultRegistry_)
        external
        override
        initializer
    {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        assetVaultRegistry = assetVaultRegistry_;
        _chainName = chainName_;
    }

    function createStERC721(address erc721, address stERC721Impl)
        external
        override
        nonReentrant
        onlyOwner
        returns (address)
    {
        return _createStERC721(erc721, stERC721Impl);
    }

    function _createStERC721(address erc721, address stERC721Impl) internal returns (address stERC721) {
        if (stERC721s[erc721] != address(0)) {
            revert StERC721AlreadyExists(erc721);
        }
        if (stERC721Impl == address(0)) {
            revert InvalidAddress(stERC721Impl);
        }
        stERC721 = _createProxy(erc721, stERC721Impl);
        stERC721s[erc721] = stERC721;
        // make sure transfer ownership to stERC721Registry
        assetVaultRegistry.authorize(address(stERC721));
    }

    function _createProxy(address erc721, address stERC721Impl) internal returns (address stERC721) {
        bytes memory initParams = _buildInitParams(erc721);
        stERC721 = address(new UpgradeableProxy(stERC721Impl, address(this), initParams));
    }

    function _buildInitParams(address erc721) internal view returns (bytes memory initParams) {
        string memory erc721Symbol = IERC721Metadata(erc721).symbol();
        string memory erc721Name = string(abi.encodePacked(namePrefix, " ", erc721Symbol));
        erc721Symbol = string(abi.encodePacked(symbolPrefix, erc721Symbol));
        initParams = abi.encodeWithSelector(
            IStERC721.initialize.selector,
            _chainName,
            IERC721Metadata(erc721),
            assetVaultRegistry,
            erc721Name,
            erc721Symbol
        );
    }

    function batchCreateStERC721(address[] calldata erc721s, address stERC721Impl)
        external
        override
        nonReentrant
        onlyOwner
        returns (address[] memory stERC721s_)
    {
        stERC721s_ = new address[](erc721s.length);
        for (uint256 i = 0; i < erc721s.length; i++) {
            stERC721s_[i] = _createStERC721(erc721s[i], stERC721Impl);
        }
    }

    function upgradeStERC721(address erc721, address stERC721Impl, bytes calldata encodedCallData)
        external
        override
        nonReentrant
        onlyOwner
    {
        _upgradeStERC721(erc721, stERC721Impl, encodedCallData);
    }

    function _upgradeStERC721(address erc721, address stERC721Impl, bytes memory encodedCallData) internal {
        address stERC721Proxy = stERC721s[erc721];
        if (stERC721Proxy == address(0)) {
            revert StERC721NotExists(erc721);
        }
        ProxyAdmin proxyAdmin = ProxyAdmin(payable(UpgradeableProxy(payable(stERC721Proxy)).admin()));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(stERC721Proxy), stERC721Impl, encodedCallData);
    }

    function batchUpgradeStERC721(address[] calldata erc721s, address stERC721Impl, bytes[] calldata encodedCallDatas)
        external
        override
        nonReentrant
        onlyOwner
    {
        for (uint256 i = 0; i < erc721s.length; i++) {
            _upgradeStERC721(erc721s[i], stERC721Impl, encodedCallDatas[i]);
        }
    }

    function getStERC721(address erc721) external view override returns (address stERC721) {
        stERC721 = stERC721s[erc721];
    }

    function setBaseURI(address stERC721_, string memory baseURI_) external override onlyOwner {
        IStERC721(stERC721_).setBaseURI(baseURI_);
    }
}
