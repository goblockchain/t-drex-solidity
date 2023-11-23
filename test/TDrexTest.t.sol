// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {TDrexFactory} from "../src/core/TDrexFactory.sol";
import {INative} from "../src/interfaces/INative.sol";
import {NATIVE} from "../src/core/Native.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {TDrexRouter} from "../src/periphery/TDrexRouter.sol";
import {mockERC1155Token, mockERC20Token} from "../src/MockToken.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {TDrexLibrary} from "../src/libraries/TDrexLibrary.sol";
import {TDrexPair} from "../src/core/TDrexPair.sol";

contract CounterTest is Test, IERC1155Receiver {
    TDrexPair pair;
    TDrexRouter router;
    TDrexFactory public factory;
    NATIVE public native;
    address randomUser = address(101);
    mockERC1155Token token1;
    mockERC20Token token0;
    uint constant ID = 12345;

    function setUp() public {
        factory = new TDrexFactory(address(this), address(this));
        token1 = new mockERC1155Token();
        token0 = new mockERC20Token();
        native = new NATIVE();
        router = new TDrexRouter(
            address(factory),
            address(this),
            address(native)
        );

        vm.expectRevert();
        // below reverts because erc20 does not support ERC165.
        assertEq(ERC165Checker.supportsERC165(address(token0)), false);

        // below does not revert because erc1155 supports ERC165.
        assertEq(ERC165Checker.supportsERC165(address(token1)), true);
        assertEq(token1.supportsInterface(bytes4(0xd9b67a26)), true); // is IERC1155
        assertEq(token1.supportsInterface(bytes4(0x36372b07)), false); // is IERC20

        /*╔═════════════════════════════╗
          ║   MOCK PAIR USED IN TESTS   ║
          ╚═════════════════════════════╝*/

        pair = TDrexPair(
            factory.createPair(
                address(token0),
                address(token1),
                token0.balanceOf(address(this)),
                token1.balanceOf(address(this), ID),
                ID
            )
        );
        // address below is deterministic because of the CREATE2 opcode.
        /*assertEq(
            factory.getPair(address(token0), address(token1), ID),
            address(0x96507cb9B4763D5E14A20F7C65A1cF948E115C92)
        );
        */
        assertEq(factory.allPairsLength(), 1);
    }

    function test_Factory() public {}

    function test_Library() public {
        // NOTE: Library reverts if pair doesn't exist, as government will be the only one able to create a pair.

        // `pairFor` and `getPair` should return the same address.
        assertEq(
            TDrexLibrary.pairFor(
                address(factory),
                address(token1),
                address(token0),
                ID
            ),
            factory.getPair(address(token0), address(token1), ID)
        );

        // sort works despite order given.
        (address tokenA, address tokenB) = TDrexLibrary.sortTokens(
            address(token1),
            address(token0)
        );
        (address reverseTokenA, address reverseTokenB) = TDrexLibrary
            .sortTokens(address(token0), address(token1));
        assert(tokenA == reverseTokenA);
        assert(tokenB == reverseTokenB);

        /**
         * amountA == 1 ether, reserveA = 10 ether, reserveB = 10 ether, so:
         * amountB = amountA * reserveB / reserveB
         * amountB = 1 ether * 10 ether / 10 ether = 1 ether.
         */
        assertEq(
            TDrexLibrary.quote(
                1 ether,
                token0.totalSupply(),
                token1.balanceOf(address(this), ID)
            ),
            833333333333333333
        );

        /**
         * getAmountOut
         * amountIn, reserveIn, reserveOut
         * MATH BELOW:
         * amountOut = amountIn * 0,97% * reserveOut / (reserveIn + amountIn * 0,97%)
         * 0.3% fee for protocol.
         */
        uint amountOut = TDrexLibrary.getAmountOut(
            1 ether, // amountIn
            token0.totalSupply(), // reserveIn, 10 ether
            token1.balanceOf(address(this), ID) // reserveOut, 10 ether
        );
        assertEq(amountOut, 767100100023082249); // 0.906... ether

        /**
         * getAmountIn
         */
        uint amountIn = TDrexLibrary.getAmountIn(
            906610893880149131, // amountOut- erc1155
            token1.balanceOf(address(this), ID), // reserveIn
            token0.totalSupply() // reserveOut
        );
        assertEq(amountIn, 819712444874338082);

        // getReserves returns reserves
        (uint reserveA, uint reserveB) = TDrexLibrary.getReserves(
            address(factory),
            address(token1),
            address(token0),
            ID
        );

        (uint reverseReserveA, uint reverseReserveB) = TDrexLibrary.getReserves(
            address(factory),
            address(token1),
            address(token0),
            ID
        );

        // getReserves returns reserves
        assert(reserveA == 0);
        // getReserves sorts tokens
        assert(reserveA == reverseReserveA);
        // getReserves returns reserves
        assert(reserveA == reserveB);
    }

    /// @dev it works great!
    function test_RouterNormally() public {
        // gov makes itself an entity.
        router.addEntity(address(this));
        // it approves the router to transfer its tokens.
        token0.approve(address(router), type(uint).max);
        token1.setApprovalForAll(address(router), true);
        // liquidity is added for both tokens at once.
        router.addLiquidity(
            address(token0),
            address(token1),
            ID,
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this), ID),
            0,
            0,
            address(this),
            block.timestamp + 1 days
        );

        // liquidity provide (address(this)) receives 9999999999999999000 LP tokens.
        assertEq(pair.balanceOf(address(this)), 9999999999999999000);

        pair.approve(address(router), type(uint).max);
        router.removeLiquidity(
            address(token0),
            address(token1),
            ID,
            9999999999999999000,
            0,
            0,
            address(this),
            block.timestamp + 1 days
        );

        // address(this) receives: 9999999999999999000 ERC1155 tokens of ID 12345 && 9999999999999999000 of tokens ERC20.
        // pair still has 1000 of each token.
        assertEq(token0.balanceOf(address(pair)), 1000);
        assertEq(token1.balanceOf(address(pair), ID), 1000);

        assertEq(token1.balanceOf(randomUser, ID), 0.1 ether);
        assertEq(token0.balanceOf(randomUser), 2 ether);

        //NOTE: test swap

        // approve router to get tokens.
        vm.startPrank(randomUser);
        token0.approve(address(router), type(uint).max);
        token1.setApprovalForAll(address(router), true);

        // setup path
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        // swap ERC20 -> ERC1155
        router.swapERC20TokensForERC1155Tokens(
            token0.balanceOf(randomUser),
            0,
            path,
            ID,
            randomUser,
            block.timestamp + 1 days
        );

        // check `randomUser` got ERC1155 tokens
        assertEq(token1.balanceOf(randomUser, ID), 0.1 ether + 999);

        // setup path
        path[0] = address(token1);
        path[1] = address(token0);

        // swap ERC1155 -> ERC20
        router.swapERC1155TokensForERC20Tokens(
            token1.balanceOf(randomUser, ID),
            0,
            path,
            ID,
            randomUser,
            block.timestamp + 1 days
        );
        assertEq(token0.balanceOf(randomUser), 2000000000000000979);
    }

    /// @dev it reverts on TDrexPair-L:208 in the `sub` function.
    function test_RouterTDrex() public {
        // gov makes itself an entity.
        router.addEntity(address(this));
        // it approves the router to transfer its tokens.
        token0.approve(address(router), type(uint).max);
        token1.setApprovalForAll(address(router), true);
        uint balance1 = token1.balanceOf(address(this), ID);

        // it adds liquidity of only one token.
        vm.expectRevert();
        router.addLiquidity(
            address(token0),
            address(token1),
            ID,
            0,
            balance1,
            0,
            0,
            address(this),
            block.timestamp + 1 days
        );
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
    ) external pure returns (bool) {
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
