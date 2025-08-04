pragma solidity 0.8.29;

import {ClaimAirdropStrategy} from "../../src/ClaimAirdropStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {MockAirdropContractForCurrentOwner} from "./MockAirdropContract.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract MockClaimAirdropStrategy is ClaimAirdropStrategy, IERC721Receiver, IERC1155Receiver {
    MockAirdropContractForCurrentOwner public airdropContract;

    constructor(
        MockAirdropContractForCurrentOwner airdropContract_,
        address assetVaultRegistry_,
        address[] memory erc20ProofTokens_,
        address[] memory erc721ProofTokens_,
        address[] memory erc1155ProofTokens_
    ) ClaimAirdropStrategy(assetVaultRegistry_, erc20ProofTokens_, erc721ProofTokens_, erc1155ProofTokens_) {
        airdropContract = airdropContract_;
    }

    function claim(address to_, bytes memory data_) external override {
        uint256 erc721TokenId = abi.decode(data_, (uint256));
        airdropContract.claim(erc721TokenId);
        IERC721(airdropContract.airdrop721()).safeTransferFrom(address(this), to_, erc721TokenId);
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
