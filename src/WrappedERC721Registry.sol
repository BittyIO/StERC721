// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {UpgradeableProxy} from "./UpgradeableProxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IWrappedERC721} from "./interfaces/IWrappedERC721.sol";
import {IWrappedERC721Registry} from "./interfaces/IWrappedERC721Registry.sol";
import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";
import {IMintStrategy} from "./interfaces/IMintStrategy.sol";
import {InvalidAddress, WrappedERC721NotExists, InvalidParams} from "./interfaces/IErrors.sol";

contract WrappedERC721Registry is OwnableUpgradeable, ReentrancyGuardUpgradeable, IWrappedERC721Registry {
    using EnumerableSet for EnumerableSet.AddressSet;

    string private _chainName;
    string public constant namePrefix = "WrappedERC721";
    string public constant symbolPrefix = "W";
    IAssetVaultRegistry public assetVaultRegistry;
    EnumerableSet.AddressSet private _wrappedERC721s;

    modifier onlyWrappedERC721(address wrappedERC721) {
        if (!_wrappedERC721s.contains(wrappedERC721)) {
            revert WrappedERC721NotExists(wrappedERC721);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
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

    function createWrappedERC721(address erc721, address wrappedERC721Impl, address mintStrategy)
        external
        override
        nonReentrant
        onlyOwner
        returns (address)
    {
        return _createWrappedERC721(erc721, wrappedERC721Impl, mintStrategy);
    }

    function _createWrappedERC721(address erc721, address wrappedERC721Impl, address mintStrategy)
        internal
        returns (address wrappedERC721)
    {
        if (wrappedERC721Impl == address(0)) {
            revert InvalidAddress(wrappedERC721Impl);
        }
        // disable initializers for wrappedERC721Impl
        IWrappedERC721(wrappedERC721Impl).disableInitializers();

        bytes memory initParams = _buildInitParams(erc721, mintStrategy);
        wrappedERC721 = address(new UpgradeableProxy(wrappedERC721Impl, address(this), initParams));
        _wrappedERC721s.add(wrappedERC721);
        emit Created(wrappedERC721, wrappedERC721Impl);
        // make sure transfer ownership to wrappedERC721Registry
        assetVaultRegistry.authorize(address(wrappedERC721));
    }

    function _buildInitParams(address erc721, address mintStrategy) internal view returns (bytes memory initParams) {
        string memory erc721Symbol = IERC721Metadata(erc721).symbol();
        string memory erc721Name = string(abi.encodePacked(namePrefix, " ", erc721Symbol));
        erc721Symbol = string(abi.encodePacked(symbolPrefix, erc721Symbol));
        initParams = abi.encodeWithSelector(
            IWrappedERC721.initialize.selector,
            _chainName,
            IERC721Metadata(erc721),
            assetVaultRegistry,
            erc721Name,
            erc721Symbol,
            mintStrategy
        );
    }

    function batchCreateWrappedERC721(
        address[] calldata erc721s,
        address wrappedERC721Impl,
        address[] calldata mintStrategys
    ) external override nonReentrant onlyOwner returns (address[] memory wrappedERC721s_) {
        if (erc721s.length != mintStrategys.length) {
            revert InvalidParams();
        }
        wrappedERC721s_ = new address[](erc721s.length);
        for (uint256 i = 0; i < erc721s.length; i++) {
            wrappedERC721s_[i] = _createWrappedERC721(erc721s[i], wrappedERC721Impl, mintStrategys[i]);
        }
    }

    function upgradeWrappedERC721(address wrappedERC721, address wrappedERC721Impl, bytes calldata encodedCallData)
        external
        override
        nonReentrant
        onlyOwner
    {
        _upgradeWrappedERC721(wrappedERC721, wrappedERC721Impl, encodedCallData);
    }

    function _upgradeWrappedERC721(address wrappedERC721, address wrappedERC721Impl, bytes memory encodedCallData)
        internal
        onlyWrappedERC721(wrappedERC721)
    {
        ProxyAdmin proxyAdmin = ProxyAdmin(payable(UpgradeableProxy(payable(wrappedERC721)).admin()));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(wrappedERC721), wrappedERC721Impl, encodedCallData);
        emit Upgraded(wrappedERC721, wrappedERC721Impl);
    }

    function batchUpgradeWrappedERC721(
        address[] calldata wrappedERC721s,
        address wrappedERC721Impl,
        bytes[] calldata encodedCallDatas
    ) external override nonReentrant onlyOwner {
        if (wrappedERC721s.length != encodedCallDatas.length) {
            revert InvalidParams();
        }
        for (uint256 i = 0; i < wrappedERC721s.length; i++) {
            _upgradeWrappedERC721(wrappedERC721s[i], wrappedERC721Impl, encodedCallDatas[i]);
        }
    }

    function setBaseURI(address wrappedERC721_, string memory baseURI_)
        external
        override
        onlyOwner
        onlyWrappedERC721(wrappedERC721_)
    {
        IWrappedERC721(wrappedERC721_).setBaseURI(baseURI_);
    }

    function setMintStrategy(address wrappedERC721_, address mintStrategy_)
        external
        override
        onlyOwner
        onlyWrappedERC721(wrappedERC721_)
    {
        IWrappedERC721(wrappedERC721_).setMintStrategy(IMintStrategy(mintStrategy_));
    }

    function setSymbol(address wrappedERC721_, string memory symbol_)
        external
        override
        onlyOwner
        onlyWrappedERC721(wrappedERC721_)
    {
        if (bytes(symbol_).length == 0) {
            revert InvalidParams();
        }
        string memory name_ = string(abi.encodePacked(namePrefix, " ", symbol_));
        symbol_ = string(abi.encodePacked(symbolPrefix, symbol_));
        IWrappedERC721(wrappedERC721_).setNameAndSymbol(name_, symbol_);
    }

    function addClaimAirdropStrategy(address strategy_) external override onlyOwner {
        assetVaultRegistry.addClaimAirdropStrategy(strategy_);
    }

    function removeClaimAirdropStrategy(address strategy_) external override onlyOwner {
        assetVaultRegistry.removeClaimAirdropStrategy(strategy_);
    }

    function addExecuteAirdropStrategy(address strategy_) external override onlyOwner {
        assetVaultRegistry.addExecuteAirdropStrategy(strategy_);
    }

    function removeExecuteAirdropStrategy(address strategy_) external override onlyOwner {
        assetVaultRegistry.removeExecuteAirdropStrategy(strategy_);
    }
}
