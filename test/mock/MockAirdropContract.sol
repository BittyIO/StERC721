pragma solidity 0.8.29;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {MintableERC721} from "./MintableERC721.sol";

interface IAirdropContract {
    function claim(uint256 tokenId) external;
}

contract MockAirdropContractForCurrentOwner is IAirdropContract {
    IERC721 public erc721Proof;
    IERC20 public erc20Proof;
    IERC1155 public erc1155Proof;
    MintableERC721 public airdrop721;

    constructor(address erc721Proof_, address erc20Proof_, address erc1155Proof_, address airdrop721_) {
        erc721Proof = IERC721(erc721Proof_);
        erc20Proof = IERC20(erc20Proof_);
        erc1155Proof = IERC1155(erc1155Proof_);
        airdrop721 = MintableERC721(airdrop721_);
    }

    function claim(uint256 tokenId) external {
        require(erc721Proof.ownerOf(tokenId) == msg.sender, "MockAirdropContract: not owner");
        require(erc20Proof.balanceOf(msg.sender) >= 100, "MockAirdropContract: not enough balance");
        require(erc1155Proof.balanceOf(msg.sender, tokenId) >= 10, "MockAirdropContract: not enough balance");
        airdrop721.mint(msg.sender, tokenId);
    }
}

contract MockAirdropContractForFixedOwner is IAirdropContract {
    IERC721 public erc721Proof;
    MintableERC721 public airdrop721;
    address public owner;

    constructor(address erc721_, address airdrop721_, address owner_) {
        erc721Proof = IERC721(erc721_);
        airdrop721 = MintableERC721(airdrop721_);
        owner = owner_;
    }

    function claim(uint256 tokenId) external {
        require(erc721Proof.ownerOf(tokenId) == owner, "MockAirdropContract: not owner");
        require(msg.sender == owner, "MockAirdropContract: not owner");
        airdrop721.mint(msg.sender, tokenId);
    }
}
