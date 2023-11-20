// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {TDrexFactory} from "../src/core/TDrexFactory.sol";
import {INative} from "../src/interfaces/INative.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {mockERC1155Token, mockERC20Token} from "../src/MockToken.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract CounterTest is Test, IERC1155Receiver {
    TDrexFactory public factory;
    INative public WNATIVE;
    address govBr = address(this);
    mockERC1155Token token1;
    mockERC20Token token0;
    uint constant ID = 12345;

    function setUp() public {
        factory = new TDrexFactory(address(this), address(this));
        token1 = new mockERC1155Token();
        emit log_address(address(token1));
        token0 = new mockERC20Token();
        emit log_address(address(token0));
        vm.expectRevert(); // below reverts because erc20 does not support ERC165.
        assertEq(ERC165Checker.supportsERC165(address(token0)), false);
        // below does not revert because erc1155 supports ERC165.
        assertEq(ERC165Checker.supportsERC165(address(token1)), true);
        assertEq(token1.supportsInterface(bytes4(0xd9b67a26)), true); // is IERC1155
        assertEq(token1.supportsInterface(bytes4(0x36372b07)), false); // is IERC20
    }

    function test_Factory() public {
        factory.createPair(
            address(token0),
            address(token1),
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this), ID),
            ID
        );
        assertEq(
            factory.getPair(address(token0), address(token1), ID),
            address(0x4F7320eFd3776797cEaDEfECd606852b6Cc66AE1)
        );
        assertEq(factory.allPairsLength(), 1);
    }

    function test_supportsInterface() public {
        assertEq(token1.supportsInterface(bytes4(0xd9b67a26)), true);
    }

    // IERC155Receiver functions

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        emit log_named_uint("id received", id);
        emit log_named_uint("value received", value);
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external view returns (bool) {
        if (interfaceId == bytes4(bytes("0xd9b67a26"))) return true;
        return false;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        emit log_address(from);
        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }
}
