## Foundry

**Foundry is a blazing-fast, portable, and modular toolkit for Ethereum application development, written in Rust.**

Foundry consists of:

-   **Forge**: An Ethereum testing framework similar to Truffle, Hardhat, and DappTools.
-   **Cast**: A Swiss army knife for interacting with EVM smart contracts, sending transactions, and retrieving chain data.
-   **Anvil**: A local Ethereum node, akin to Ganache and Hardhat Network.
-   **Chisel**: A fast, utilitarian, and verbose Solidity REPL.

## Documentation

For comprehensive documentation, visit: [Foundry Book](https://book.getfoundry.sh/)

## Usage

To run the project, ensure you have Node.js installed. Refer to [NVM](https://github.com/nvm-sh/nvm) for installation.

Once you've installed the recommended Node.js version (ideally **Node 21**), please run:

```shell
npm run deps
# or
yarn deps
```

Running this command is crucial because there are packages that are not compatible, and this process will make them compatible. The `--legacy-peer-deps` option comes into play primarily when a package you're trying to install has a peer dependency that conflicts with your current project setup.

## Chain Forking

To fork the required chains, refer to the `forkChainA.bash.example` and `forkChainB.bash.example` files.

After creating the appropriate script file for your system, run the following commands (assuming you are on macOS):

```shell
bash forkChainA.bash
```

In another window or tab, run:

```shell
bash forkChainB.bash
```

### Build

To build the project, run:

```shell
forge build
```

### Test

Please note that **not all contracts were tested**; the focus was on the happy paths and the main functionality of the game.

```shell
forge test -vvvvvv
```

### Format

To format the code, run:

```shell
forge fmt
```

### Gas Snapshots

To create gas snapshots, run:

```shell
forge snapshot
```

### Anvil

To start Anvil, run:

```shell
anvil
```

### Deploy

To deploy the script, use:

```shell
forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

To use Cast, run:

```shell
cast <subcommand>
```

### Deploying Locally

To deploy the contracts locally, run:

```shell
npm run deploy:local::A
npm run deploy:local::B
```

This will deploy the contracts on the forked nodes.

### Help

For additional help, run:

```shell
forge --help
anvil --help
cast --help
```
```