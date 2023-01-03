# Account Abstraction Invoker

Example account abstraction (EIP-3074) invoker contract. For demonstration purposes only.

## About

Account Abstraction Invoker uses [`AUTH`](https://eips.ethereum.org/EIPS/eip-3074#auth-0xf6) and [`AUTHCALL`](https://eips.ethereum.org/EIPS/eip-3074#authcall-0xf7) opcodes introduced in [EIP-3074 ](https://eips.ethereum.org/EIPS/eip-3074) to delegate control of the externally owned account (EOA) to itself (smart contract). This adds more functionality to EOAs, such as batching capabilities, allowing for gas sponsoring, expirations, scripting, and beyond.

Use cases are showcased in the [tests](test/AccountAbstractionInvoker.ts). The invoker works with ✨ _all_ ✨ contracts:

<img alt="Sponsoring example" src="./img/sponsoring-example.png" width="693px" />

[Commit](https://eips.ethereum.org/EIPS/eip-3074#understanding-commit) is EIP-712 hash of the this [structure](scripts/signing/README.md). This means the invoker inherits the security of EIP-712, in addition to following the [Secure Invoker](https://eips.ethereum.org/EIPS/eip-3074#secure-invokers) recommendations and implementing additional security measures.

## Requirements

- Network with EIP-3074

## Instructions

### Quickstart

```bash
git clone https://github.com/0xPolygon/account-abstraction-invoker
cd account-abstraction-invoker
yarn
```

### Setup

```bash
cp .env.example .env
```

- Set RPC URL in `.env`

    Hardhat accounts `0` and `1` are included in `.env` for your convinience. Do not send real funds to those accounts.

- Change chain ID in `hardhat.config.ts`

### Test

Hardhat does not support EIP-3074 at the moment. All testing is done on a live network.

```bash
yarn hardhat test
```

To redeploy contracts, set environment variable `REDEPLOY=true`. Otherwise, last deployed contracts will be used.

## Acknowledgements

This example was based on Maarten Zuidhoorn's [EIP-3074 (Batch) Transaction Invoker](https://github.com/Mrtenz/transaction-invoker).