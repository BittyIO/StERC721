// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MintableERC1155 is ERC1155 {
    constructor(string memory uri_) ERC1155(uri_) {}

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        _mintBatch(to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external {
        _burnBatch(from, ids, amounts);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || interfaceId == type(IERC1155MetadataURI).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
