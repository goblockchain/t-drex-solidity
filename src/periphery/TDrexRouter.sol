// TODO: will we add license?
pragma solidity ^0.8.13;

/*
 * TODO: IMPORTS
 */

// ITDrexFactory
// TODO: import from core.
// TransferHelper
import "../libraries/TransferHelper.sol";
// ITDrexRouter
// TODO: import
// TDrexLibrary
import "../libraries/TDrexLibrary.sol";
// SafeMath
import "../libraries/SafeMath.sol";
// IERC20
import "../interfaces/IERC20.sol";
// INative
import "../interfaces/INative.sol";

contract TDrexRouter {
    // NOTE: No need to use SafeMath because of pragma > 0.8
    using SafeMath for uint;

    address public immutable factory;
    // TODO: Check what's the wrapped token of the native of the Besu blockchain
    address public immutable WNative;

    /*╔═════════════════════════════╗
      ║           ERRORS            ║
      ╚═════════════════════════════╝*/

    // deadline is lesser than current block's timestamp
    error Router_Expired(uint deadline);
    // TODO: Rename errors with TDREX at the beginning
    // min tokenA liquidity to be added
    error Router_Insufficient_A_Amount(uint amountAMin);
    // min tokenB liquidity to be added
    error Router_Insufficient_B_Amount(uint amountBMin);
    error Router_Insufficient_OUTPUT_Amount(uint outputMinAmount);
    error Router_Excessive_Input_Amount(uint amountInMax);
    // invalid token, either as output or input.
    error Router_Invalid_Path(address token);

    constructor(address _factory, address _WNative) {
        factory = _factory;
        WNative = _WNative;
    }

    receive() external payable {
        // @audit-info the below is due to possibility that someone may brick the contract by sending Native directly to it, affecting the constant K.
        assert(msg.sender == WNative); // only accept Native via fallback from the WNative contract.
    }

    /*╔═════════════════════════════╗
      ║        ADD LIQUIDITY        ║
      ╚═════════════════════════════╝*/

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
            // TODO: pair should have been created in the factory by government already, so erase this line, put a revert here I believe.
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
        returns (uint amountA, uint amountB, uint liquidity)
    {
        ensure(deadline);
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = TDrexLibrary.pairFor(factory, tokenA, tokenB);
        //TODO: check if isn't it better to use _msgSender() function here?
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
        returns (uint amountToken, uint amountNative, uint liquidity)
    {
        ensure(deadline);
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

    /*╔═════════════════════════════╗
      ║      REMOVE LIQUIDITY       ║
      ╚═════════════════════════════╝*/

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override returns (uint amountA, uint amountB) {
        ensure(deadline);
        address pair = TDrexLibrary.pairFor(factory, tokenA, tokenB);
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
    ) public virtual override returns (uint amountToken, uint amountNative) {
        ensure(deadline);
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

    ///
    /// @param tokenA
    /// @param tokenB
    /// @param liquidity
    /// @param amountAMin
    /// @param amountBMin
    /// @param to
    /// @param deadline
    /// @param approveMax
    /// @param v
    /// @param r
    /// @param s
    /// @return amountA
    /// @return amountB
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = TDrexLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? type(uint).max : liquidity;
        ITDrexPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    ///
    /// @param token
    /// @param liquidity
    /// @param amountTokenMin
    /// @param amountETHMin
    /// @param to
    /// @param deadline
    /// @param approveMax
    /// @param v
    /// @param r
    /// @param s
    /// @return amountToken
    /// @return amountETH
    function removeLiquidityNativeWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountToken, uint amountNative) {
        address pair = TDrexLibrary.pairFor(factory, token, WNative);
        uint value = approveMax ? type(uint).max : liquidity;
        ITDrexPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountNative) = removeLiquidityNative(
            token,
            liquidity,
            amountTokenMin,
            amountNativeMin,
            to,
            deadline
        );
    }

    /*╔═════════════════════════════╗
      ║        REMOVE LIQUIDITY     ║
      ╚═════════════════════════════╝*/
    // for supporting fee-on-transfer tokens

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    //** In the real world, such tokens that support fee on transfer are: SafeMoon, FlokiInu, BabyDoge, Crypter */
    // NOTE: This use-case is interesting because government may actually want to add a fee on transfer of some token. So, we cover that.

    ///
    /// @param token
    /// @param liquidity
    /// @param amountTokenMin
    /// @param amountETHMin
    /// @param to
    /// @param deadline
    function removeLiquidityNativeSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline
    ) public virtual override returns (uint amountNative) {
        ensure(deadline);
        (, amountNative) = removeLiquidity(
            token,
            WNative,
            liquidity,
            amountTokenMin,
            amountNativeMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(
            token,
            to,
            IERC20(token).balanceOf(address(this))
        );
        IWNative(WNative).withdraw(amountNative);
        TransferHelper.safeTransferNative(to, amountNative);
    }

    ///
    /// @param token
    /// @param liquidity
    /// @param amountTokenMin
    /// @param amountETHMin
    /// @param to
    /// @param deadline
    /// @param approveMax
    /// @param v
    /// @param r
    /// @param s
    function removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountNative) {
        address pair = TDrexLibrary.pairFor(factory, token, WNative);
        uint value = approveMax ? type(uint).max : liquidity;
        ITDrexPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        amountNative = removeLiquidityNativeSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountNativeMin,
            to,
            deadline
        );
    }

    /*╔═════════════════════════════╗
      ║            SWAPS            ║
      ╚═════════════════════════════╝*/
    // requires the initial amount to have already been sent to the first pair

    ///
    /// @param amounts
    /// @param path
    /// @param _to
    function _swap(
        uint[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        uint pathLength = path.length; // gas optimization: cache array length.
        for (uint i; i < pathLength - 1; ) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = TDrexLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOut)
                : (amountOut, uint(0));
            address to = i < pathLength - 2
                ? TDrexLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            ITDrexPair(TDrexLibrary.pairFor(factory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
            unchecked {
                ++i; // unchecked because i < pathLength
            }
        }
    }

    ///
    /// @param amountIn
    /// @param amountOutMin
    /// @param path
    /// @param to
    /// @param deadline
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override returns (uint[] memory amounts) {
        ensure(deadline);
        amounts = TDrexLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    ///
    /// @param amountOut
    /// @param amountInMax
    /// @param path
    /// @param to
    /// @param deadline
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override returns (uint[] memory amounts) {
        ensure(deadline);
        amounts = TDrexLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax)
            revert Router_Excessive_Input_Amount(amountInMax);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    ///
    /// @param amountOutMin
    /// @param path
    /// @param to
    /// @param deadline
    function swapExactNativeForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override returns (uint[] memory amounts) {
        ensure(deadline);
        if (path[0] != WNative) revert Router_Invalid_Path(path[0]);
        amounts = TDrexLibrary.getAmountsOut(factory, msg.value, path);
        if (amounts[amounts.length - 1] < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        IWNative(WNative).deposit{value: amounts[0]}();
        assert(
            IWNative(WNative).transfer(
                TDrexLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
    }

    ///
    /// @param amountOut
    /// @param amountInMax
    /// @param path
    /// @param to
    /// @param deadline
    function swapTokensForExactNative(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override returns (uint[] memory amounts) {
        ensure(deadline);
        if (path[path.length - 1] != WNative)
            revert Router_Invalid_Path(path[path.length - 1]);
        amounts = TDrexLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax)
            revert Router_Excessive_Input_Amount(amountInMax);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWNative(WNative).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferNative(to, amounts[amounts.length - 1]);
    }

    ///
    /// @param amountIn
    /// @param amountOutMin
    /// @param path
    /// @param to
    /// @param deadline
    function swapExactTokensForNative(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override returns (uint[] memory amounts) {
        ensure(deadline);
        if (path[path.length - 1] != WNative)
            revert Router_Invalid_Path(path[path.length - 1]);
        amounts = TDrexLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWNative(WNative).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferNative(to, amounts[amounts.length - 1]);
    }

    ///
    /// @param amountOut
    /// @param path
    /// @param to
    /// @param deadline
    function swapNativeForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override returns (uint[] memory amounts) {
        ensure(deadline);
        if (path[0] != WNative) revert Router_Invalid_Path(path[0]);
        amounts = TDrexLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > msg.value)
            revert Router_Excessive_Input_Amount(amounts[0]);
        IWNative(WNative).deposit{value: amounts[0]}();
        assert(
            IWNative(WNative).transfer(
                TDrexLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
        // refund dust Native, if any
        if (msg.value > amounts[0])
            TransferHelper.safeTransferNative(
                msg.sender,
                msg.value - amounts[0]
            );
    }

    /*╔═════════════════════════════╗
      ║            SWAPS            ║
      ╚═════════════════════════════╝*/
    // requires the initial amount to have already been sent to the first pair

    ///
    /// @param path
    /// @param _to
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address _to
    ) internal virtual {
        uint pathLength = path.length;
        for (uint i; i < pathLength - 1; ) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = TDrexLibrary.sortTokens(input, output);
            ITDrexPair pair = ITDrexPair(
                TDrexLibrary.pairFor(factory, input, output)
            );
            uint amountInput;
            uint amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1, ) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(
                    reserveInput
                );
                amountOutput = TDrexLibrary.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
            }
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOutput)
                : (amountOutput, uint(0));
            address to = i < path.length - 2
                ? TDrexLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
            unchecked {
                ++i;
            }
        }
    }

    ///
    /// @param amountIn
    /// @param amountOutMin
    /// @param path
    /// @param to
    /// @param deadline
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override {
        ensure(deadline);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );

        // TODO: validate whether we're gonna use IERC20 interface or if there's an interface for ERC20-like tokens in the Besu blockchain.
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

        _swapSupportingFeeOnTransferTokens(path, to);
        if (
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) <
            amountOutMin
        ) revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
    }

    ///
    /// @param amountOutMin
    /// @param path
    /// @param to
    /// @param deadline
    function swapExactNativeForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override {
        ensure(deadline);
        if (path[0] != WNative) revert Router_Invalid_Path(path[0]);
        uint amountIn = msg.value;
        IWNative(WNative).deposit{value: amountIn}();
        assert(
            IWNative(WNative).transfer(
                TDrexLibrary.pairFor(factory, path[0], path[1]),
                amountIn
            )
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        if (
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) <
            amountOutMin
        ) revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
    }

    ///
    /// @param amountIn
    /// @param amountOutMin
    /// @param path
    /// @param to
    /// @param deadline
    function swapExactTokensForNativeSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override {
        ensure(deadline);
        if (path[path.length - 1] != WNative)
            revert Router_Invalid_Path(path[path.length - 1]);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WNative).balanceOf(address(this));
        if (amountOut < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        IWNative(WNative).withdraw(amountOut);
        TransferHelper.safeTransferNative(to, amountOut);
    }

    /*╔═════════════════════════════╗
      ║      LIBRARY FUNCTIONS      ║
      ╚═════════════════════════════╝*/
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) public pure virtual override returns (uint amountB) {
        return TDrexLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountOut) {
        return TDrexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountIn) {
        return TDrexLibrary.getAmountIn(amountIn, reserveIn, reserveOut);
    }

    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        return TDrexLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(
        uint amountOut,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        return TDrexLibrary.getAmountIn(factory, amountOut, path);
    }

    // JUMP opcode is cheaper than CODECOPY opcode as if we had used a modifier.
    function ensure(uint deadline) internal {
        if (deadline < block.timestamp) revert Router_Expired(deadline);
    }
}
