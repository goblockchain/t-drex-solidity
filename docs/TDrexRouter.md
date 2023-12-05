# Solidity API

## TDrexRouter

Since this contract will be inside a permissioned EVM-compatible blockchain, we, therefore, decided to make some assumptions. NOTE that removing these assumptions make this contract to be vulnerable to be deployed in any EVM-compatible mainnet. The assumptions are below:
1. The `tokenB` in addLiquidity/removeLiquidity will always be an ERC1155-like token, enforced by the back-end of the application.

### Contract
TDrexRouter : src/periphery/TDrexRouter.sol

 --- 
### Functions:
### constructor

```solidity
constructor(address _factory, address _govBr, address _WNative) public
```

### receive

```solidity
receive() external payable
```

### addEntity

```solidity
function addEntity(address entity) public
```

### removeEntity

```solidity
function removeEntity(address entity) public
```

### _addLiquidity

```solidity
function _addLiquidity(address tokenA, address tokenB, uint256 id, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin) internal virtual returns (uint256 amountA, uint256 amountB)
```

### addLiquidity

```solidity
function addLiquidity(address tokenA, address tokenB, uint256 id, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external virtual returns (uint256 amountA, uint256 amountB, uint256 liquidity)
```

### addLiquidityNative

```solidity
function addLiquidityNative(address token, uint256 id, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountNativeMin, address to, uint256 deadline) external payable virtual returns (uint256 amountToken, uint256 amountNative, uint256 liquidity)
```

### removeLiquidity

```solidity
function removeLiquidity(address tokenA, address tokenB, uint256 id, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) public virtual returns (uint256 amountA, uint256 amountB)
```

### removeLiquidityNative

```solidity
function removeLiquidityNative(address token, uint256 id, uint256 liquidity, uint256 amountTokenMin, uint256 amountNativeMin, address to, uint256 deadline) public virtual returns (uint256 amountToken, uint256 amountNative)
```

### removeLiquidityWithPermit

```solidity
function removeLiquidityWithPermit(address tokenA, address tokenB, uint256 id, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) external virtual returns (uint256 amountA, uint256 amountB)
```

### removeLiquidityNativeWithPermit

```solidity
function removeLiquidityNativeWithPermit(address token, uint256 id, uint256 liquidity, uint256 amountTokenMin, uint256 amountNativeMin, address to, uint256 deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) external virtual returns (uint256 amountToken, uint256 amountNative)
```

### removeLiquidityNativeSupportingFeeOnTransferTokens

```solidity
function removeLiquidityNativeSupportingFeeOnTransferTokens(address token, uint256 id, uint256 liquidity, uint256 amountTokenMin, uint256 amountNativeMin, address to, uint256 deadline) public virtual returns (uint256 amountNative)
```

### removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens

```solidity
function removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens(address token, uint256 liquidity, uint256 id, uint256 amountTokenMin, uint256 amountNativeMin, address to, uint256 deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) external virtual returns (uint256 amountNative)
```

### _swap

```solidity
function _swap(uint256[] amounts, address[] path, uint256 id, address to) internal virtual
```

the function below expects the tokens to have been sent atomically to the pair contract. It only calls the pair contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amounts | uint256[] | amounts desired to be swapped. |
| path | address[] | path of tokens to swap: ERC20 -> ERC1155 or ERC1155 -> ERC20. |
| id | uint256 | ID of ERC1155 token. |
| to | address | the address to which tokens will go to after the swap. |

### swapERC20TokensForERC1155Tokens

```solidity
function swapERC20TokensForERC1155Tokens(uint256 amountIn, uint256 amountOutMin, address[] path, uint256 id, address to, uint256 deadline) external returns (uint256[] amounts)
```

### swapERC1155TokensForERC20Tokens

```solidity
function swapERC1155TokensForERC20Tokens(uint256 amountIn, uint256 amountOutMin, address[] path, uint256 id, address to, uint256 deadline) external returns (uint256[] amounts)
```

### swapExactTokensForTokens

```solidity
function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] path, uint256 id, address to, uint256 deadline) external virtual returns (uint256[] amounts)
```

### swapTokensForExactTokens

```solidity
function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] path, uint256 id, address to, uint256 deadline) external virtual returns (uint256[] amounts)
```

### swapExactNativeForTokens

```solidity
function swapExactNativeForTokens(uint256 amountOutMin, address[] path, uint256 id, address to, uint256 deadline) external payable virtual returns (uint256[] amounts)
```

### swapTokensForExactNative

```solidity
function swapTokensForExactNative(uint256 amountOut, uint256 amountInMax, address[] path, uint256 id, address to, uint256 deadline) external virtual returns (uint256[] amounts)
```

### swapExactTokensForNative

```solidity
function swapExactTokensForNative(uint256 amountIn, uint256 amountOutMin, address[] path, uint256 id, address to, uint256 deadline) external virtual returns (uint256[] amounts)
```

### swapNativeForExactTokens

```solidity
function swapNativeForExactTokens(uint256 amountOut, address[] path, uint256 id, address to, uint256 deadline) external payable virtual returns (uint256[] amounts)
```

### _swapSupportingFeeOnTransferTokens

```solidity
function _swapSupportingFeeOnTransferTokens(address[] path, uint256 id, address _to) internal virtual
```

### swapExactTokensForTokensSupportingFeeOnTransferTokens

```solidity
function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] path, uint256 id, address to, uint256 deadline) external virtual
```

### swapExactNativeForTokensSupportingFeeOnTransferTokens

```solidity
function swapExactNativeForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, address[] path, uint256 id, address to, uint256 deadline) external payable virtual
```

### swapExactTokensForNativeSupportingFeeOnTransferTokens

```solidity
function swapExactTokensForNativeSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] path, uint256 id, address to, uint256 deadline) external virtual
```

### quote

```solidity
function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure virtual returns (uint256 amountB)
```

### getAmountOut

```solidity
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure virtual returns (uint256 amountOut)
```

### getAmountIn

```solidity
function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public pure virtual returns (uint256 amountIn)
```

### getAmountsOut

```solidity
function getAmountsOut(uint256 amountIn, uint256 id, address[] path) public view virtual returns (uint256[] amounts)
```

### ensure

```solidity
function ensure(uint256 deadline) internal
```

