pragma solidity ^0.8.13;

// TODO: import TDrexPair instead of below
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./SafeMath.sol";

library UniswapV2Library {
    using SafeMath for uint;

    /*╔═════════════════════════════╗
      ║           ERRORS            ║
      ╚═════════════════════════════╝*/
    error Library_Identical_Addresses(address identicalToken);
    error Library_Zero_Address();
    error Library_Insufficient_Amount(uint amount);
    error Library_Insufficient_Liquidity(uint reserveA, uint reserveB);
    error Library_Insufficient_INPUT_Amount(uint amount);
    error Library_Insufficient_OUTPUT_Amount(uint amount);
    error Library_Invalid_Path(uint invalidPathLength);

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert Library_Identical_Addresses(tokenA);
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        if (token0 == address(0)) revert Library_Zero_Address();
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        // NOTE: pair pool contract address is deterministic accross TDREX.
        pair = address(
            uint(
                keccak256(
                    abi.encodePacked(
                        hex"ff",
                        factory,
                        keccak256(abi.encodePacked(token0, token1)),
                        hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                    )
                )
            )
        );
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint reserveA, uint reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1, ) = ITDrexPair(
            pairFor(factory, tokenA, tokenB)
        ).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) internal pure returns (uint amountB) {
        if (amountA == 0) revert Library_Insufficient_Amount(amountA);
        if (reserveA == 0 || reserveB == 0)
            revert Library_Insufficient_Liquidity(reserveA, reserveB);
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        if (amountIn == 0) revert Library_Insufficient_INPUT_Amount(amountIn);
        if (reserveIn == 0 || reserveOut == 0)
            revert Library_Insufficient_Liquidity(reserveIn, reserveOut);

        // TODO: Will we have fee. I thought we could set it on constructor. Fee here: 3/1000 == 0.3%
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountIn) {
        if (amountOut == 0)
            revert Library_Insufficient_OUTPUT_Amount(amountOut);
        if (reserveIn == 0 || reserveOut == 0)
            revert Library_Insufficient_Liquidity(reserveIn, reserveOut);
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address factory,
        uint amountIn,
        address[] memory path
    ) internal view returns (uint[] memory amounts) {
        uint pathLength = path.length;
        if (pathLength < 2) revert Library_Invalid_Path(pathLength);
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < pathLength - 1; ) {
            (uint reserveIn, uint reserveOut) = getReserves(
                factory,
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
            unchecked {
                ++i;
            }
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address factory,
        uint amountOut,
        address[] memory path
    ) internal view returns (uint[] memory amounts) {
        uint pathLength = path.length;
        if (pathLength < 2) revert Library_Invalid_Path(pathLength);
        amounts = new uint[](pathLength);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = pathLength - 1; i > 0; ) {
            (uint reserveIn, uint reserveOut) = getReserves(
                factory,
                path[i - 1],
                path[i]
            );
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
            unchecked {
                --i; // bounded by i>0 in loop
            }
        }
    }
}
