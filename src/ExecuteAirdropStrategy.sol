// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IExecuteAirdropStrategy} from "./interfaces/IExecuteAirdropStrategy.sol";

abstract contract ExecuteAirdropStrategy is ERC165, IExecuteAirdropStrategy {
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IExecuteAirdropStrategy).interfaceId || super.supportsInterface(interfaceId);
    }
}
