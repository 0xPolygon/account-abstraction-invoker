## Signing

Call `getSignature` with `message` and `privateKey`:

```typescript
const message = {
  from: 0x0000000000000000000000000000000000000000,
  nonce: 0,
  payload: [
    { to: "0x0000000000000000000000000000000000000000", value: 0, gasLimit: 0, data: "0x" }
  ]
};
const signature = getSignature(message, privateKey);
```

`getSignature` will sign EIP-712 hash of the following data:

```json
{
  "types": {
    "EIP712Domain": [
      { "name": "name", "type": "string" },
      { "name": "version", "type": "string" },
      { "name": "chainId", "type": "uint256" },
      { "name": "verifyingContract", "type": "address" }
    ],
    "Transaction": [
      { "name": "from", "type": "address" },
      { "name": "nonce", "type": "uint256" },
      { "name": "payload", "type": "TransactionPayload[]" }
    ],
    "TransactionPayload": [
      { "name": "to", "type": "address" },
      { "name": "value", "type": "uint256" },
      { "name": "gasLimit", "type": "uint256" },
      { "name": "data", "type": "bytes" }
    ]
  },
  "primaryType": "Transaction",
  "domain": {
    "name": "Account Abstraction Invoker",
    "version": "1.0.0",
    "chainId": 0,
    "verifyingContract": "0x0000000000000000000000000000000000000000"
  },
  "message": {
    "from": "0x0000000000000000000000000000000000000000",
    "nonce": 0,
    "payload": [
      {
        "to": "0x0000000000000000000000000000000000000000",
        "value": 0,
        "gasLimit": 0,
        "data": "0x"
      }
    ]
  }
}
```