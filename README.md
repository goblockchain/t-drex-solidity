## TDrex

It will work as follows:
We create pools.
1. Front-end will come and make sure banks can addLiquidity to a pool - the liquidity will be composed of a CDBC and a title.
2. DONE: Gov is the only one who can create the pool in the factory.
2. DONE: There will be a whitelist that will try checking whether the bank is part of the whitelist when adding liquidity to a pool in the Router.
2. One bank can addLiquidity for both of them - or either of them. What will the bank/gov use to get liquidity of other asset? He will borrow, for example, titles or/and CDBC in our own smart contract in the `GARANTIAS` tab. Borrow is overcollaterized. It seems to be better though for us to create some pools beforehand. (TODO: Test what happens if I create a pair pool with one of them being 0 as amount.) If we can create a pair with 0 amount, let's do it.
3. Then they will addLiquidity to a pool.
4. The the pool will mint an ERC1155-like representation of the title added, such that there exists a 1:1 ratio (original and representation ratio).
5. In the swaps, only the representation is swap.
6. The representation is burned at once when the govBR burns the titles from the TDrex pair pool contract. The TDrex then distributes the money to all holders that have the representation of the title.
7. Banks/govs come and swap titles <-> CDBCs.
8. DONE: Only banks can addLiquidity and onlyGov can create the pair. Gov determines the amount of titles per amount of CDBCs, determining therefore the initial price of the titles. 
9. bank/gov calls Router -> router get tokens from caller -> pool gets tokens from routers -> pool sends tokens to user. 
10. When the title is expired: gov calls burn on pool -> pool calls burn itself on its tokens -> pool distributes it to LP holders -> pool also stays with what has not been swap. 
11. Should I define 1155 as the token1, so that users exchange CDBCs per titles. They can also exchange token1 for token0, ofc. But instead of defining tokens per their numbers' sort, I define them per their ercType. This begins in factory. 
12. Pair could have pause function and this could be unpaused for swaps etc - only after liquidity has been added. Router would check whether the pair he is calling is paused or not.
13. Substitute where there is token1 _safeTransfer for token1 _safeTransfer of 1155.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
