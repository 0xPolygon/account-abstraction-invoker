# Transaction Invoker

Example EIP-3074 invoker contract

## About

Transaction Invoker uses [`AUTH`](https://eips.ethereum.org/EIPS/eip-3074#auth-0xf6) and [`AUTHCALL`](https://eips.ethereum.org/EIPS/eip-3074#authcall-0xf7) opcodes introduced in [EIP-3074 ](https://eips.ethereum.org/EIPS/eip-3074) to delegate control of the externally owned account (EOA) to itself (smart contract). This adds more functionality to EOAs, such as batching capabilities, allowing for gas sponsoring, expirations, scripting, and beyond.

Use cases are showcased in the [tests](test/TransactionInvoker.ts).

## Requirements

- Network with EIP-3074

## Instructions

### Quickstart

```bash
git clone https://github.com/ZeroEkkusu/transaction-invoker
cd transaction-invoker
yarn
```

### Setup

```bash
mv .env.example .env
```

Set RPC URL in `.env`.

Hardhat accounts `0` and `1` are included in `.env` for your convinience. Do not send real funds to those accounts.

Set chain ID in `hardhat.config.ts`.

### Test

Hardhat does not support EIP-3074 at the moment. All testing is done on a live network, and deployment addresses are hardcoded in the tests.

When you deploy your own contracts, replace `DEPLOYMENT_INVOKER` and `DEPLOYMENT_MOCK` in `test/TransactionInvoker.ts`, and `chainId` and `verifyingContract` in `scripts/payload.json`.

```bash
yarn hardhat test
```

## Acknowledgements

This example was based on Maarten Zuidhoorn's [EIP-3074 (Batch) Transaction Invoker](https://github.com/Mrtenz/transaction-invoker).