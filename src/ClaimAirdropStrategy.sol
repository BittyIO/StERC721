// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IClaimAirdropStrategy} from "./interfaces/IClaimAirdropStrategy.sol";

abstract contract ClaimAirdropStrategy is ERC165, IClaimAirdropStrategy {
    address public immutable assetVaultRegistry;

    constructor(
        address assetVaultRegistry_,
        address[] memory erc20ProofTokens_,
        address[] memory erc721ProofTokens_,
        address[] memory erc1155ProofTokens_
    ) {
        assetVaultRegistry = assetVaultRegistry_;
        for (uint256 i = 0; i < erc20ProofTokens_.length; i++) {
            require(erc20ProofTokens_[i] != address(0), "ClaimAirdropStrategy: erc20 proof token is zero address");
            IERC20(erc20ProofTokens_[i]).approve(assetVaultRegistry_, type(uint256).max);
        }
        for (uint256 i = 0; i < erc721ProofTokens_.length; i++) {
            require(erc721ProofTokens_[i] != address(0), "ClaimAirdropStrategy: erc721 proof token is zero address");
            IERC721(erc721ProofTokens_[i]).setApprovalForAll(assetVaultRegistry_, true);
        }
        for (uint256 i = 0; i < erc1155ProofTokens_.length; i++) {
            require(erc1155ProofTokens_[i] != address(0), "ClaimAirdropStrategy: erc1155 proof token is zero address");
            IERC1155(erc1155ProofTokens_[i]).setApprovalForAll(assetVaultRegistry_, true);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IClaimAirdropStrategy).interfaceId || super.supportsInterface(interfaceId);
    }
}
