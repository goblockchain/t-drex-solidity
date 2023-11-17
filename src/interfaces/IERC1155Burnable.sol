// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/IERC1155.sol)

import {IERC1155} from "./IERC1155.sol";

pragma solidity ^0.8.20;

interface IERC1155Burnable is IERC1155 {
    function burn(address account, uint256 id, uint256 value) external;

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) external;
}
