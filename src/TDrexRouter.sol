pragma solidity ^0.8.13;

/*
 * TODO: IMPORTS
 */

contract TDrexRouter {
    // NOTE: No need to use SafeMath because of pragma > 0.8

    address public immutable factory;
    // TODO: Check what's the wrapped token of the native of the Besu blockchain
    address public immutable WNative;

    /*
     * ERRORS
     */
    // deadline is lesser than current block's timestamp
    error Expired(uint deadline);
    // TODO: Rename errors with TDREX at the beginning
    // min tokenA liquidity to be added
    error Router_Insufficient_A_Amount(uint amountAMin);
    // min tokenB liquidity to be added
    error Router_Insufficient_B_Amount(uint amountBMin);

    // TODO: substitute this for an function. JUMP opcode is cheaper than CODECOPY everytime.
    modifier ensure(uint deadline) {
        if (deadline < block.timestamp) revert Expired(deadline);
        _;
    }

    constructor(address _factory, address _WNative) {
        factory = _factory;
        WNative = _WNative;
    }

    receive() external payable {
        assert(msg.sender == WNative); // only accept Native via fallback from the WNative contract.
        // @audit-info the below is due to possibility that someone may brick the contract by sending ETH directly to it, affecting the constant K.
    }

    // **** ADD LIQUIDITY ****
    /// @notice This function adds liquidity to the pool of tokenA, tokenB. The pool though cannot receive an arbitrary number of tokens. Instead, the tokens added to the pool must maintain the pool's balance of equal token equal to a constant K when multiplied. Order of tokens does not matter, either can be A or B.
    /// @param tokenA // tokenA
    /// @param tokenB // tokenB
    /// @param amountADesired amount of liquidity the token the caller wants to add.
    /// @param amountBDesired amount of liquidity the token the caller wants to add.
    /// @param amountAMin the min amount that the caller wants to be surely added as liquidity
    /// @param amountBMin the min amount that the caller wants to be surely added as liquidity
    /// @return amountA the amount of tokens of tokenA that were actually added as liquidity to the pool supplied by the caller.
    /// @return amountB the amount of tokens of tokenB that were actually added as liquidity to the pool supplied by the caller.
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired, // seems to be the
        uint amountBDesired, // seems to be the amount of liquidity the token the caller wants to add.
        uint amountAMin, // seems
        uint amountBMin // seems the min amount that the caller wants to be surely added as liquidity
    ) internal virtual returns (uint amountA, uint amountB) {
        // create pair pool if it doesn't exist yet
        if (ITDrexFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ITDrexFactory(factory).createPair(tokenA, tokenB);
        }

        (uint reserveA, uint reserveB) = TDrexLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );

        // if the pair pool has been created above, make the user's input amount to be liquidity to be added to the pool.
        if (reserveA == 0 && reserveB == 0) {
            // @audit-issue possible brick of pool here, if user adds a zero amount of either or both token to the pool, there's no validation that amounts != 0. Check whether there's this check in the `safeTransferFrom()` function in the external addLiquidity function.
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // this case happens if the pool already exists
            uint amountBOptimal = TDrexLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin)
                    revert Router_Insufficient_B_Amount(amountBMin);
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = TDrexLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);

                if (amountAOptimal < amountAMin)
                    revert Router_Insufficient_A_Amount(amountAMin);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /// @notice
    /// @param tokenA
    /// @param tokenB
    /// @param amountADesired
    /// @param amountBDesired
    /// @param amountAMin
    /// @param amountBMin
    /// @param to
    /// @param deadline
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint amountA, uint amountB, uint liquidity)
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = TDrexLibrary.pairFor(factory, tokenA, tokenB);
        //NOTE: isn't it better to use _msgSender() function here?
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        //NOTE: This LP token minted when liquidity is added can be the representation of the titulo.
        liquidity = ITDrexPair(pair).mint(to);
    }

    /// @notice this function is intented to add liquidity to a pool where one of the tokens is the native token of the blockchain.
    /// @param token
    /// @param amountTokenDesired
    /// @param amountTokenMin
    /// @param amountNativeMin
    /// @param to
    /// @param deadline
    /// @return amountToken
    /// @return amountNative
    /// @return liquidity
    function addLiquidityNative(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint amountToken, uint amountNative, uint liquidity)
    {
        (amountToken, amountNative) = _addLiquidity(
            token,
            WNative,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountNativeMin
        );

        address pair = TDrexLibrary.pairFor(factory, token, WNative);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWNative(WNative).deposit{value: amountNative}();
        assert(IWNative(WNative).transfer(pair, amountNative));
        liquidity = ITDrexPair(pair).mint(to);
        // refund dust native, if any
        // @audit-info this is another measure to avoid receiving unexpected Native
        if (msg.value > amountNative)
            TransferHelper.safeTransferNative(
                msg.sender,
                msg.value - amountNative
            );
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint amountA, uint amountB)
    {
        addres pair = TDrexLibrary.pairFor(factory, tokenA, tokenB);
        // LP tokens are sent to the pool, then burned in next line;remember the pair pool is also a token.
        ITDrexPair(pair).transferFrom(msg.sender, pair, liquidity);
        // burn LP tokens in pool - pool is the one that send the tokens to the caller.
        (uint amount0, uint amount1) = ITDrexPair(pair).burn(to);
        (address token0, ) = TDrexLibrary.sortTokens(tokenA, tokenB);
        // the protocol uses the sort of tokens throughout since each token's address represents a number.
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        // any of the below would modify must-be constant K.
        if (amountA < amountAMin)
            revert Router_Insufficient_A_Amount(amountAMin);
        if (amountB < amountBMin)
            revert Router_Insufficient_B_Amount(amountBMin);
    }

    function removeLiquidityNative(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint amountToken, uint amountNative)
    {
        (amountToken, amountNative) = removeLiquidity(
            token,
            WNative,
            liquidity,
            amountTokenMin,
            amountNativeMin,
            address(this),
            deadline
        );
        // NOTE: Router handles Native probably because pair doesn't handle it. Check it though.
        TransferHelper.safeTransfer(token, to, amountToken);
        IWNative(WNative).withdraw(amountNative);
        TransferHelper.safeTransferNative(to, amountNative);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    //** In the real world, such tokens that support fee on transfer are: SafeMoon, FlokiInu, BabyDoge, Crypter */
    // NOTE: This use-case is interesting because government may actually want to add a fee on transfer of some token. So, we cover that.

    // TODO: removeLiquidityNative with permit functionality.

    // TODO: removeLiquidity of fee on transfer tokens.

    // TODO: removeLiquidityNative of fee on transfer tokens.

    // **** SWAP functions ****


    // **** LIBRARY functions ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return TDrexLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure virtual override returns (uint amountOut) {
        return TDrexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn( uint amountOut, uint reserveIn, uint reserveOut) public pure virtual override returns(uint amountIn) {
        return TDrexLibrary.getAmountIn(amountIn, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path) pubic view virtual override returns (uint [] memory amounts) {
        return TDrexLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn( uint amountOut, address[] memory path) public view virtual override returns(uint[] memory amounts) {
        return TDrexLibrary.getAmountIn(factory, amountOut, path);
    }
}

}
