// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {UpgradeableProxy} from "./UpgradeableProxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IStERC721} from "./interfaces/IStERC721.sol";
import {IStERC721Registry} from "./interfaces/IStERC721Registry.sol";
import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";
import {IMintStrategy} from "./interfaces/IMintStrategy.sol";
import {InvalidAddress, StERC721NotExists, InvalidParams} from "./interfaces/IErrors.sol";

contract StERC721Registry is OwnableUpgradeable, ReentrancyGuardUpgradeable, IStERC721Registry {
    using EnumerableSet for EnumerableSet.AddressSet;

    string private _chainName;
    string public constant namePrefix = "StERC721";
    string public constant symbolPrefix = "St";
    IAssetVaultRegistry public assetVaultRegistry;
    EnumerableSet.AddressSet private _stERC721s;

    modifier onlyStERC721(address stERC721) {
        if (!_stERC721s.contains(stERC721)) {
            revert StERC721NotExists(stERC721);
        }
        _;
    }

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

    function createStERC721(address erc721, address stERC721Impl, address mintStrategy)
        external
        override
        nonReentrant
        onlyOwner
        returns (address)
    {
        return _createStERC721(erc721, stERC721Impl, mintStrategy);
    }

    function _createStERC721(address erc721, address stERC721Impl, address mintStrategy)
        internal
        returns (address stERC721)
    {
        if (stERC721Impl == address(0)) {
            revert InvalidAddress(stERC721Impl);
        }
        // disable initializers for stERC721Impl
        IStERC721(stERC721Impl).disableInitializers();

        bytes memory initParams = _buildInitParams(erc721, mintStrategy);
        stERC721 = address(new UpgradeableProxy(stERC721Impl, address(this), initParams));
        _stERC721s.add(stERC721);
        emit Created(stERC721, stERC721Impl);
        // make sure transfer ownership to stERC721Registry
        assetVaultRegistry.authorize(address(stERC721));
    }

    function _buildInitParams(address erc721, address mintStrategy) internal view returns (bytes memory initParams) {
        string memory erc721Symbol = IERC721Metadata(erc721).symbol();
        string memory erc721Name = string(abi.encodePacked(namePrefix, " ", erc721Symbol));
        erc721Symbol = string(abi.encodePacked(symbolPrefix, erc721Symbol));
        initParams = abi.encodeWithSelector(
            IStERC721.initialize.selector,
            _chainName,
            IERC721Metadata(erc721),
            assetVaultRegistry,
            erc721Name,
            erc721Symbol,
            mintStrategy
        );
    }

    function batchCreateStERC721(address[] calldata erc721s, address stERC721Impl, address[] calldata mintStrategys)
        external
        override
        nonReentrant
        onlyOwner
        returns (address[] memory stERC721s_)
    {
        if (erc721s.length != mintStrategys.length) {
            revert InvalidParams();
        }
        stERC721s_ = new address[](erc721s.length);
        for (uint256 i = 0; i < erc721s.length; i++) {
            stERC721s_[i] = _createStERC721(erc721s[i], stERC721Impl, mintStrategys[i]);
        }
    }

    function upgradeStERC721(address stERC721, address stERC721Impl, bytes calldata encodedCallData)
        external
        override
        nonReentrant
        onlyOwner
    {
        _upgradeStERC721(stERC721, stERC721Impl, encodedCallData);
    }

    function _upgradeStERC721(address stERC721, address stERC721Impl, bytes memory encodedCallData)
        internal
        onlyStERC721(stERC721)
    {
        ProxyAdmin proxyAdmin = ProxyAdmin(payable(UpgradeableProxy(payable(stERC721)).admin()));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(stERC721), stERC721Impl, encodedCallData);
        emit Upgraded(stERC721, stERC721Impl);
    }

    function batchUpgradeStERC721(address[] calldata stERC721s, address stERC721Impl, bytes[] calldata encodedCallDatas)
        external
        override
        nonReentrant
        onlyOwner
    {
        if (stERC721s.length != encodedCallDatas.length) {
            revert InvalidParams();
        }
        for (uint256 i = 0; i < stERC721s.length; i++) {
            _upgradeStERC721(stERC721s[i], stERC721Impl, encodedCallDatas[i]);
        }
    }

    function setBaseURI(address stERC721_, string memory baseURI_)
        external
        override
        onlyOwner
        onlyStERC721(stERC721_)
    {
        IStERC721(stERC721_).setBaseURI(baseURI_);
    }

    function setMintStrategy(address stERC721_, address mintStrategy_)
        external
        override
        onlyOwner
        onlyStERC721(stERC721_)
    {
        IStERC721(stERC721_).setMintStrategy(IMintStrategy(mintStrategy_));
    }

    function setSymbol(address stERC721_, string memory symbol_) external override onlyOwner onlyStERC721(stERC721_) {
        if (bytes(symbol_).length == 0) {
            revert InvalidParams();
        }
        string memory name_ = string(abi.encodePacked(namePrefix, " ", symbol_));
        symbol_ = string(abi.encodePacked(symbolPrefix, symbol_));
        IStERC721(stERC721_).setNameAndSymbol(name_, symbol_);
    }
}
