pragma solidity 0.8.29;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ExecuteAirdropStrategy} from "../../src/ExecuteAirdropStrategy.sol";
import {MockAirdropContractForFixedOwner} from "./MockAirdropContract.sol";

contract MockExecuteAirdropStrategy is ExecuteAirdropStrategy {
    function execute(address to_, bytes memory data_) external override {
        (address airdropContract_, address erc721Airdrop_, uint256 tokenId_) =
            abi.decode(data_, (address, address, uint256));
        MockAirdropContractForFixedOwner(airdropContract_).claim(tokenId_);
        IERC721(erc721Airdrop_).safeTransferFrom(address(this), to_, tokenId_);
    }
}
