// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {TDrexFactory} from "../src/core/TDrexFactory.sol";
import {INative} from "../src/interfaces/INative.sol";
// import {IWETH9} from "../src/core/Native.sol";
import {mockERC1155Token, mockERC20Token} from "../src/MockToken.sol";

contract CounterTest is Test {
    TDrexFactory public factory;
    INative public WNATIVE;
    address govBr = address(this);
    mockERC1155Token token1;
    mockERC20Token token0;
    uint constant ID = 12345;

    function setUp() public {
        // WNATIVE = new IWETH9();
        factory = TDrexFactory(govBr);
        vm.startPrank(govBr);
        token1 = new mockERC1155Token();
        token0 = new mockERC20Token();
        assertEq(token1.supportsInterface(bytes4(bytes("0xd9b67a26"))), true);
        // assertEq(token0.supportsInterface(bytes4(bytes("0x36372b07"))), true);
    }

    function test_Factory() public {
        factory.createPair(
            address(token0),
            address(token1),
            token0.balanceOf(govBr),
            token1.balanceOf(govBr, ID),
            ID
        );
        assertEq(
            factory.getPair(address(token0), address(token1), ID),
            address(0)
        );
        assertEq(factory.allPairsLength(), 1);
    }
}
