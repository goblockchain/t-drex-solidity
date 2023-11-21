//SPDX-Licence: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title TDrexFactory
 * @author TDrex team
 * @notice Since this contract will be inside a permissioned EVM-compatible blockchain, we, therefore, decided to make some assumptions. NOTE that removing these assumptions make this contract to be vulnerable to be deployed in any EVM-compatible mainnet. The assumptions are below:
 * 1. only Brazil's government will be able to create pools.
 * 2. the pair to be created will always be composed of an ERC20-like contract and an ERC1155. This contract will always support the supportsInterface function as any of the most recent ERC20s do. This is key to determining the sorting of the tokens in the pool.
 * 3. `amount1` and `amount0` will represent the initial price in between token0 and token1, where token0 is always an ERC20-like token and token1 is an ERC1155-like token.
 */

import "../interfaces/ITDrexFactory.sol";
import "../interfaces/ITDrexPair.sol";
import "./TDrexPair.sol";
import "../interfaces/IERC165.sol";

contract TDrexFactory is ITDrexFactory {
    // errors
    error Factory_ZeroAddress();
    error Factory_PairExists();
    error Factory_IdenticalAddresses();
    error Factory_Forbidden();
    error Factory_ZeroAmount();

    address public feeTo;
    address public feeToSetter;
    // Brazil's Gov Account
    address public govBr;

    ///@dev token0 -> token1 -> id -> address
    mapping(address => mapping(address => mapping(uint => address)))
        public getPair;
    address[] public allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint id,
        uint amount0,
        uint amount1,
        uint
    );

    // TODO: what's this fee for? Look at RareSkills
    constructor(address _feeToSetter, address _govBR) {
        feeToSetter = _feeToSetter;
        govBr = _govBR;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /// @dev the creator of the pool
    /// @param caller must be allowed bank
    function _isGov(address caller) private {
        if (caller != govBr) revert Factory_Forbidden();
    }

    /// @notice it creates the contract holding the pair of tokens.
    /// @param tokenA token in the pool.
    /// @param tokenB token in the pool.
    /// @param amount0 initialPrice of token. It's not deterministic for the pair address creation.
    /// @param amount1 initialPrice of token. It's not deterministic for the pair address creation.
    /// @param id id of ERC1155 in the pool.
    function createPair(
        address tokenA,
        address tokenB,
        uint amount0,
        uint amount1,
        uint id
    ) external returns (address pair) {
        _isGov(msg.sender);
        if (tokenA == tokenB) revert Factory_IdenticalAddresses();
        // price is 0
        if (amount0 == 0 || amount1 == 0) revert Factory_ZeroAmount();

        // ERC20 InterfaceID == 0x36372b07
        // ERC1155 InterfaceID == 0xd9b67a26
        address token0;
        address token1;
        try IERC165(tokenA).supportsInterface(bytes4(0xd9b67a26)) returns (
            bool yes
        ) {
            if (yes) {
                // if tokenA is the IERC1155
                token0 = tokenB;
                token1 = tokenA;
            } else {
                // in case ERC20 is IERC165
                token0 = tokenA;
                token1 = tokenB;
            }
        } catch {
            //in case tokenA is ERC20 without IERC165
            token0 = tokenA;
            token1 = tokenB;
        }

        // OLD:
        /*
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        */
        if (token0 == address(0) || token1 == address(0))
            revert Factory_ZeroAddress();
        if (getPair[token0][token1][id] != address(0))
            revert Factory_PairExists();
        bytes memory bytecode = type(TDrexPair).creationCode;
        // price is also used as a way to determine salt.
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, id));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ITDrexPair(pair).initialize(token0, token1, amount0, amount1, id);
        getPair[token0][token1][id] = pair;
        getPair[token1][token0][id] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(
            token0,
            token1,
            pair,
            id,
            amount0, // price of CDBC
            amount1, // price of title
            allPairs.length
        );
    }

    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) revert Factory_Forbidden();
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) revert Factory_Forbidden();
        feeToSetter = _feeToSetter;
    }
}
