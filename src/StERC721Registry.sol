// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IStERC721} from "./interfaces/IStERC721.sol";
import {IStERC721Registry} from "./interfaces/IStERC721Registry.sol";
import {IAssetVaultRegistry} from "./interfaces/IAssetVaultRegistry.sol";

contract StERC721Registry is OwnableUpgradeable, ReentrancyGuardUpgradeable, IStERC721Registry {
    string public constant namePrefix = "StNFT";
    string public constant symbolPrefix = "STNFT";
    mapping(address => address) public stERC721s;
    IAssetVaultRegistry public assetVaultRegistry;

    function initialize(IAssetVaultRegistry assetVaultRegistry_) external initializer {
        __Ownable_init(msg.sender);
        assetVaultRegistry = assetVaultRegistry_;
    }

    function createStERC721(address erc721, address stERC721Impl) external override nonReentrant returns (address) {
        return _createStERC721(erc721, stERC721Impl);
    }

    function _createStERC721(address erc721, address stERC721Impl) internal returns (address stERC721) {
        require(stERC721s[erc721] == address(0), "StERC721Registry: asset exist");
        require(stERC721Impl != address(0), "StERC721Registry: impl is zero address");
        stERC721 = _createProxy(erc721, stERC721Impl);
        stERC721s[erc721] = stERC721;
    }

    function _createProxy(address erc721, address stERC721Impl) internal returns (address stERC721) {
        bytes memory initParams = _buildInitParams(erc721);
        stERC721 = address(new TransparentUpgradeableProxy(stERC721Impl, address(this), initParams));
    }

    function _buildInitParams(address erc721) internal view returns (bytes memory initParams) {
        string memory nftSymbol = IERC721Metadata(erc721).symbol();
        string memory bNftName = string(abi.encodePacked(namePrefix, " ", nftSymbol));
        string memory bNftSymbol = string(abi.encodePacked(symbolPrefix, nftSymbol));
        initParams = abi.encodeWithSelector(
            IStERC721.initialize.selector, IERC721Metadata(erc721), assetVaultRegistry, bNftName, bNftSymbol
        );
    }

    function batchCreateStERC721(address[] calldata erc721s, address stERC721Impl)
        external
        override
        nonReentrant
        returns (address[] memory stERC721s_)
    {
        for (uint256 i = 0; i < erc721s.length; i++) {
            stERC721s_[i] = _createStERC721(erc721s[i], stERC721Impl);
        }
    }

    function upgradeStERC721(address erc721, address stERC721Impl, bytes calldata encodedCallData)
        external
        override
        nonReentrant
    {
        _upgradeStERC721(erc721, stERC721Impl, encodedCallData);
    }

    function _upgradeStERC721(address erc721, address stERC721Impl, bytes memory encodedCallData) internal {
        address stERC721Proxy = stERC721s[erc721];
        require(stERC721Proxy != address(0), "StERC721Registry: asset nonexist");

        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(payable(stERC721Proxy));
        proxy.upgradeToAndCall(stERC721Impl, encodedCallData);
    }

    function batchUpgradeStERC721(address[] calldata erc721s, address stERC721Impl, bytes[] calldata encodedCallDatas)
        external
        override
        nonReentrant
    {
        for (uint256 i = 0; i < erc721s.length; i++) {
            _upgradeStERC721(erc721s[i], stERC721Impl, encodedCallDatas[i]);
        }
    }
}
