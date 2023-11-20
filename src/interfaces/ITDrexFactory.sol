//SPDX-License-Identifier: UNLICENSED
// TODO: put the right license
pragma solidity ^0.8.13;

interface ITDrexFactory {
    function govBr() external view returns (address);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(
        address tokenA,
        address tokenB,
        uint id
    ) external view returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(
        address tokenA,
        address tokenB,
        uint priceA,
        uint priceB,
        uint id
    ) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}
