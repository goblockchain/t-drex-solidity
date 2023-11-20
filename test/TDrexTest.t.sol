// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {TDrexFactory} from "../src/core/TDrexFactory.sol";
import {INative} from "../src/interfaces/INative.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {mockERC1155Token, mockERC20Token} from "../src/MockToken.sol";

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
        // assertEq(token1.supportsInterface(bytes4(bytes("0xd9b67a26"))), true);
        // assertEq(token1.supportsInterface(bytes4(bytes("0x36372b07"))), true);
    }

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
            address(0)
        );
        assertEq(factory.allPairsLength(), 1);
    }
}
