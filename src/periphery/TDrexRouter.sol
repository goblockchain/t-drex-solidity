// TODO: will we add license?
pragma solidity ^0.8.13;

/*
 * TODO: IMPORTS
 */

// ITDrexFactory
import "../interfaces/ITDrexFactory.sol";
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

import "../../lib/forge-std/src/console.sol";

// IERC1155
// import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title TDrexRouter
 * @author TDrex team
 * @notice Since this contract will be inside a permissioned EVM-compatible blockchain, we, therefore, decided to make some assumptions. NOTE that removing these assumptions make this contract to be vulnerable to be deployed in any EVM-compatible mainnet. The assumptions are below:
 * 1. The `tokenB` in addLiquidity/removeLiquidity will always be an ERC1155-like token, enforced by the back-end of the application.
 * 2.
 */
contract TDrexRouter {
    // NOTE: No need to use SafeMath because of pragma > 0.8
    using SafeMath for uint;

    address public immutable factory;
    address public immutable govBr;
    // TODO: Check what's the wrapped token of the native of the Besu blockchain
    address public immutable WNative;
    mapping(address => bool) entities;

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
    error Router_Forbidden();
    error Router_PairUnexists();

    constructor(address _factory, address _govBr, address _WNative) {
        factory = _factory;
        WNative = _WNative;
        govBr = _govBr;
    }

    receive() external payable {
        // @audit-info the below is due to possibility that someone may brick the contract by sending Native directly to it, affecting the constant K.
        assert(msg.sender == WNative); // only accept Native via fallback from the WNative contract.
    }

    // TODO: perform a correct ordering of the functions.

    /*╔═════════════════════════════╗
      ║      CHECK FUNCTIONS        ║
      ╚═════════════════════════════╝*/

    function _isAllowed(address caller) private {
        if (!entities[caller]) revert Router_Forbidden();
    }

    function _isGov(address caller) private {
        if (caller != govBr) revert Router_Forbidden();
    }

    /*╔═════════════════════════════╗
      ║        GOV FUNCTIONS        ║
      ╚═════════════════════════════╝*/

    function addEntity(address entity) public {
        _isGov(msg.sender);
        entities[entity] = true;
    }

    function removeEntity(address entity) public {
        _isGov(msg.sender);
        entities[entity] = false;
    }

    /*╔═════════════════════════════╗
      ║        ADD LIQUIDITY        ║
      ╚═════════════════════════════╝*/

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint id,
        uint amountADesired, // seems to be the
        uint amountBDesired, // seems to be the amount of liquidity the token the caller wants to add.
        uint amountAMin, // seems
        uint amountBMin // seems the min amount that the caller wants to be surely added as liquidity
    ) internal virtual returns (uint amountA, uint amountB) {
        // create pair pool if it doesn't exist yet
        (address token0, address token1) = TDrexLibrary.sortTokens(
            tokenA,
            tokenB
        );
        if (ITDrexFactory(factory).getPair(token0, token1, id) == address(0)) {
            // TODO: pair should have been created in the factory by government already, so erase this line, put a revert here I believe.
            revert Router_PairUnexists();
        }

        // TODO: get initial price instead of reserves...Then the sends must be adding the initialPrice or either token, if pair liquidity can be added in two steps.
        (uint reserveA, uint reserveB) = TDrexLibrary.getReserves(
            factory,
            token0,
            token1,
            id
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

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint id,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual returns (uint amountA, uint amountB, uint liquidity) {
        ensure(deadline);
        _isAllowed(msg.sender);
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            id,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = TDrexLibrary.pairFor(factory, tokenA, tokenB, id);
        //TODO: check if isn't it better to use _msgSender() function here?
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        // TODO: add an ID in here, since token B must be always an ERC1155, enforced by the back-end.
        IERC1155(tokenB).safeTransferFrom(msg.sender, pair, id, amountB, "0x");
        // TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        //NOTE: This LP token minted when liquidity is added can be the representation of the titulo.
        // TODO: if two step liquidity is supported, shall we give a different token for each added token of the pair? Im thinking this because of the burn phase - where we will burn the erc20/erc1155-like representation of the person who's added tokenB, but not tokenA, right?
        liquidity = ITDrexPair(pair).mint(to);
    }

    function addLiquidityNative(
        address token,
        uint id,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline
    )
        external
        payable
        virtual
        returns (uint amountToken, uint amountNative, uint liquidity)
    {
        ensure(deadline);
        _isAllowed(msg.sender);
        (amountToken, amountNative) = _addLiquidity(
            token,
            WNative,
            id,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountNativeMin
        );

        address pair = TDrexLibrary.pairFor(factory, token, WNative, id);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        INative(WNative).deposit{value: amountNative}();
        assert(INative(WNative).transfer(pair, amountNative));
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
        uint id,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual returns (uint amountA, uint amountB) {
        ensure(deadline);
        _isAllowed(msg.sender);
        address pair = TDrexLibrary.pairFor(factory, tokenA, tokenB, id);
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
        uint id,
        uint liquidity,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline
    ) public virtual returns (uint amountToken, uint amountNative) {
        ensure(deadline);
        _isAllowed(msg.sender);
        (amountToken, amountNative) = removeLiquidity(
            token,
            WNative,
            id,
            liquidity,
            amountTokenMin,
            amountNativeMin,
            address(this),
            deadline
        );
        // NOTE: Router handles Native probably because pair doesn't handle it. Check it though.
        TransferHelper.safeTransfer(token, to, amountToken);
        INative(WNative).withdraw(amountNative);
        TransferHelper.safeTransferNative(to, amountNative);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint id,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual returns (uint amountA, uint amountB) {
        address pair = TDrexLibrary.pairFor(factory, tokenA, tokenB, id);
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
            id,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    function removeLiquidityNativeWithPermit(
        address token,
        uint id,
        uint liquidity,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual returns (uint amountToken, uint amountNative) {
        address pair = TDrexLibrary.pairFor(factory, token, WNative, id);
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
            id,
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

    function removeLiquidityNativeSupportingFeeOnTransferTokens(
        address token,
        uint id,
        uint liquidity,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline
    ) public virtual returns (uint amountNative) {
        ensure(deadline);
        (, amountNative) = removeLiquidity(
            token,
            WNative,
            id,
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
        INative(WNative).withdraw(amountNative);
        TransferHelper.safeTransferNative(to, amountNative);
    }

    function removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint id,
        uint amountTokenMin,
        uint amountNativeMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual returns (uint amountNative) {
        address pair = TDrexLibrary.pairFor(factory, token, WNative, id);
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
            id,
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

    /// @notice the function below expects the tokens to have been sent atomically to the pair contract. It only calls the pair contract.
    /// @param amounts amounts desired to be swapped.
    /// @param path path of tokens to swap: ERC20 -> ERC1155 or ERC1155 -> ERC20.
    /// @param id ID of ERC1155 token.
    /// @param to the address to which tokens will go to after the swap.
    function _swap(
        uint[] memory amounts,
        address[] memory path,
        uint id,
        address to
    ) internal virtual {
        (address input, address output) = (path[0], path[1]);
        (address token0, ) = TDrexLibrary.sortTokens(input, output);
        uint amountOut = amounts[1];
        (uint amount0Out, uint amount1Out) = input == token0
            ? (uint(0), amountOut)
            : (amountOut, uint(0));
        ITDrexPair(TDrexLibrary.pairFor(factory, input, output, id)).swap(
            amount0Out,
            amount1Out,
            to
        );
    }

    function swapERC20TokensForERC1155Tokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint id, // ERC1155 id.
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        ensure(deadline);
        amounts = TDrexLibrary.getAmountsOut(factory, amountIn, path, id);
        // should we have the `amountOutMin`? I don't think so.
        if (amounts[amounts.length - 1] < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1], id),
            amountIn
        );
        _swap(amounts, path, id, to);
    }

    function swapERC1155TokensForERC20Tokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint id, // ERC1155 id.
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        ensure(deadline);
        amounts = TDrexLibrary.getAmountsOut(factory, amountIn, path, id);
        // should we have the `amountOutMin`? I don't think so.
        if (amounts[amounts.length - 1] < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        TransferHelper.safeTransferERC1155From(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1], id),
            id,
            amountIn
        );
        _swap(amounts, path, id, to);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external virtual returns (uint[] memory amounts) {
        ensure(deadline);
        amounts = TDrexLibrary.getAmountsOut(factory, amountIn, path, id);
        if (amounts[amounts.length - 1] < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1], id),
            amounts[0]
        );
        _swap(amounts, path, id, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external virtual returns (uint[] memory amounts) {
        ensure(deadline);
        amounts = TDrexLibrary.getAmountsIn(factory, amountOut, path, id);
        if (amounts[0] > amountInMax)
            revert Router_Excessive_Input_Amount(amountInMax);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1], id),
            amounts[0]
        );
        _swap(amounts, path, id, to);
    }

    function swapExactNativeForTokens(
        uint amountOutMin,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external payable virtual returns (uint[] memory amounts) {
        ensure(deadline);
        if (path[0] != WNative) revert Router_Invalid_Path(path[0]);
        amounts = TDrexLibrary.getAmountsOut(factory, msg.value, path, id);
        if (amounts[amounts.length - 1] < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        INative(WNative).deposit{value: amounts[0]}();
        assert(
            INative(WNative).transfer(
                TDrexLibrary.pairFor(factory, path[0], path[1], id),
                amounts[0]
            )
        );
        _swap(amounts, path, id, to);
    }

    function swapTokensForExactNative(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external virtual returns (uint[] memory amounts) {
        ensure(deadline);
        if (path[path.length - 1] != WNative)
            revert Router_Invalid_Path(path[path.length - 1]);
        amounts = TDrexLibrary.getAmountsIn(factory, amountOut, path, id);
        if (amounts[0] > amountInMax)
            revert Router_Excessive_Input_Amount(amountInMax);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1], id),
            amounts[0]
        );
        _swap(amounts, path, id, address(this));
        INative(WNative).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferNative(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForNative(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external virtual returns (uint[] memory amounts) {
        ensure(deadline);
        if (path[path.length - 1] != WNative)
            revert Router_Invalid_Path(path[path.length - 1]);
        amounts = TDrexLibrary.getAmountsOut(factory, amountIn, path, id);
        if (amounts[amounts.length - 1] < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1], id),
            amounts[0]
        );
        _swap(amounts, path, id, address(this));
        INative(WNative).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferNative(to, amounts[amounts.length - 1]);
    }

    function swapNativeForExactTokens(
        uint amountOut,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external payable virtual returns (uint[] memory amounts) {
        ensure(deadline);
        if (path[0] != WNative) revert Router_Invalid_Path(path[0]);
        amounts = TDrexLibrary.getAmountsIn(factory, amountOut, path, id);
        if (amounts[0] > msg.value)
            revert Router_Excessive_Input_Amount(amounts[0]);
        INative(WNative).deposit{value: amounts[0]}();
        assert(
            INative(WNative).transfer(
                TDrexLibrary.pairFor(factory, path[0], path[1], id),
                amounts[0]
            )
        );
        _swap(amounts, path, id, to);
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

    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        uint id,
        address _to
    ) internal virtual {
        uint pathLength = path.length;
        for (uint i; i < pathLength - 1; ) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = TDrexLibrary.sortTokens(input, output);
            ITDrexPair pair = ITDrexPair(
                TDrexLibrary.pairFor(factory, input, output, id)
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
                ? TDrexLibrary.pairFor(factory, output, path[i + 2], id)
                : _to;
            pair.swap(amount0Out, amount1Out, to);
            unchecked {
                ++i;
            }
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external virtual {
        ensure(deadline);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1], id),
            amountIn
        );

        // TODO: validate whether we're gonna use IERC20 interface or if there's an interface for ERC20-like tokens in the Besu blockchain.
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

        _swapSupportingFeeOnTransferTokens(path, id, to);
        if (
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) <
            amountOutMin
        ) revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
    }

    function swapExactNativeForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external payable virtual {
        ensure(deadline);
        if (path[0] != WNative) revert Router_Invalid_Path(path[0]);
        uint amountIn = msg.value;
        INative(WNative).deposit{value: amountIn}();
        assert(
            INative(WNative).transfer(
                TDrexLibrary.pairFor(factory, path[0], path[1], id),
                amountIn
            )
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, id, to);
        if (
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) <
            amountOutMin
        ) revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
    }

    function swapExactTokensForNativeSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint id,
        address to,
        uint deadline
    ) external virtual {
        ensure(deadline);
        if (path[path.length - 1] != WNative)
            revert Router_Invalid_Path(path[path.length - 1]);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            TDrexLibrary.pairFor(factory, path[0], path[1], id),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, id, address(this));
        uint amountOut = IERC20(WNative).balanceOf(address(this));
        if (amountOut < amountOutMin)
            revert Router_Insufficient_OUTPUT_Amount(amountOutMin);
        INative(WNative).withdraw(amountOut);
        TransferHelper.safeTransferNative(to, amountOut);
    }

    /*╔═════════════════════════════╗
      ║      LIBRARY FUNCTIONS      ║
      ╚═════════════════════════════╝*/
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) public pure virtual returns (uint amountB) {
        return TDrexLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual returns (uint amountOut) {
        return TDrexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual returns (uint amountIn) {
        return TDrexLibrary.getAmountIn(amountIn, reserveIn, reserveOut);
    }

    function getAmountsOut(
        uint amountIn,
        uint id,
        address[] memory path
    ) public view virtual returns (uint[] memory amounts) {
        return TDrexLibrary.getAmountsOut(factory, amountIn, path, id);
    }

    function getAmountsIn(
        uint amountOut,
        uint id,
        address[] memory path
    ) public view virtual returns (uint amounts) {
        // TODO: replace correctly args in line below.
        return TDrexLibrary.getAmountIn(amountOut, amountOut, amountOut);
    }

    // JUMP opcode is cheaper than CODECOPY opcode as if we had used a modifier.
    function ensure(uint deadline) internal {
        if (deadline < block.timestamp) revert Router_Expired(deadline);
    }
}
