// SPDX-License-Identifier: MIT

/* MIT License

Copyright (c) 2021 Maarten Zuidhoorn

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.*/

pragma solidity ^0.8.0;

/**
 * @title EIP3074Base
 * @author Maarten Zuidhoorn <maarten@zuidhoorn.com>, ZeroEkkusu.eth, TBD...
 * @notice An EIP-3074 based contract that can send one or more arbitrary transactions in the context of an Externally
 *  Owned Address (EOA), by using `AUTH` and `AUTHCALL`. See https://github.com/0xPolygon/account-abstraction-invoker for more
 *  information.
 */
contract EIP3074Base {

    function eip712Name() internal virtual pure returns  (string memory) { return ""; }

    function eip712Version() internal virtual pure returns  (string memory) { return ""; }

    bytes32 public constant EIP712DOMAIN_TYPE =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public constant TRANSACTION_TYPE = keccak256(
        "Transaction(address from,uint256 nonce,TransactionPayload[] payloads)TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)"
    );

    bytes32 public constant TRANSACTION_PAYLOAD_TYPE =
        keccak256("TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)");

    bytes32 public immutable DOMAIN_SEPARATOR;

    struct Signature {
        uint256 r;
        uint256 s;
        bool v;
    }

    struct Transaction {
        address from;
        uint256 nonce;
        TransactionPayload[] payloads;
    }

    struct TransactionPayload {
        address to;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    constructor() {
        // Since the domain separator depends on the chain ID and contract address, it is dynamically calculated here.
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPE,
                keccak256(abi.encodePacked(eip712Name())),
                keccak256(abi.encodePacked(eip712Version())),
                block.chainid,
                address(this)
            )
        );
    }

    function validatePayload(TransactionPayload calldata /* payload */ ) internal virtual returns (bool) {
        return true;
    }

    /**
     * @notice Send an authenticated call to the address provided in the payload.
     * @dev Currently this function does not return the call data.
     * @param payload The payload to send.
     * @return success Whether the call succeeded.
     */
    function call(TransactionPayload calldata payload) internal returns (bool success) {
        uint256 gasLimit = payload.gasLimit;
        address to = payload.to;
        uint256 value = payload.value;
        bytes memory data = payload.data;

        require(validatePayload(payload), "payload validation failed");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            success := authcall(gasLimit, to, value, 0, add(data, 0x20), mload(data), 0, 0)
        }
    }

    /**
     * @notice Get the EIP-712 hash for a transaction.
     * @param transaction The transaction to hash.
     * @return The hashed transaction.
     */
    function hashTransaction(Transaction calldata transaction) public pure returns (bytes32) {
        return keccak256(abi.encode(TRANSACTION_TYPE, transaction.from, transaction.nonce, hashPayloads(transaction.payloads)));
    }

    /**
     * @notice Get the EIP-712 hash for a transaction payload array.
     * @param payloads The payload(s) to hash.
     * @return The hashed transaction payloads.
     */
    function hashPayloads(TransactionPayload[] calldata payloads) public pure returns (bytes32) {
        bytes32[] memory values = new bytes32[](payloads.length);
        for (uint256 i = 0; i < payloads.length; i++) {
            values[i] = hashPayload(payloads[i]);
        }

        return keccak256(abi.encodePacked(values));
    }

    /**
     * @notice Get the EIP-712 hash for a transaction payload.
     * @param payload The payload to hash.
     * @return The hashed transaction payload.
     */
    function hashPayload(TransactionPayload calldata payload) public pure returns (bytes32) {
        return keccak256(
            abi.encode(TRANSACTION_PAYLOAD_TYPE, payload.to, payload.value, payload.gasLimit, keccak256(payload.data))
        );
    }
}
