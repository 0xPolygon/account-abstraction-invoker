// SPDX-License-Identifier: MIT

/* Parts of this file were based on Mrtenz/transaction-invoker:

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

import {InvokerBase} from "./InvokerBase.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";

/**
 * @title Batch Invoker
 * @author Zero Ekkusu <zeroekkusu.eth>, Maarten Zuidhoorn <maarten@zuidhoorn.com>
 * @notice An EIP-3074 based contract that can send one or more arbitrary transactions in the context of an Externally
 *  Owned Address (EOA), by using `AUTH` and `AUTHCALL`. See https://github.com/0xPolygon/account-abstraction-invoker for more
 *  information.
 */
contract BatchInvoker is InvokerBase, ReentrancyGuard {
    struct Transaction {
        address from;
        uint256 nonce;
        TransactionPayload[] payloads;
    }

    bytes32 private constant TRANSACTION_TYPE = keccak256(
        "Transaction(address from,uint256 nonce,TransactionPayload[] payloads)TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)"
    );

    bytes32 private constant TRANSACTION_PAYLOAD_TYPE =
        keccak256("TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)");

    mapping(address => uint256) private nonces;

    constructor() InvokerBase("Batch Invoker", "1.0.0") {}

    function getTransactionType() external pure returns (bytes32) {
        return TRANSACTION_TYPE;
    }

    function getTransactionPayloadType() external pure returns (bytes32) {
        return TRANSACTION_PAYLOAD_TYPE;
    }

    function getNonce(address account) external view returns (uint256) {
        return nonces[account];
    }

    /*//////////////////////////////////////////////////////////////
                                INVOKING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authenticate and send the provided transaction payload(s) in the context of the signer. This function
     *  reverts if the signature is invalid, the nonce is incorrect, or one of the calls failed.
     * @param signature The signature of the transactions to verify.
     * @param transaction The nonce and payload(s) to send.
     */
    function invoke(Signature calldata signature, Transaction calldata transaction) external payable nonReentrant {
        require(transaction.payloads.length > 0, "No payloads");

        address signer = authenticate(signature, transaction);
        // We require the signer to be the from address
        // because it is more likely to recover *some* address than address(0).
        require(signer == transaction.from, "Invalid signature");

        require(transaction.nonce == nonces[signer], "Invalid nonce");

        nonces[signer] += 1;

        uint256 startBalance = address(this).balance - msg.value;

        for (uint256 i = 0; i < transaction.payloads.length; i++) {
            bool success = call(transaction.payloads[i]);
            require(success, "Transaction failed");
        }

        // To ensure that the caller does not send more funds than used in the transaction payload, we check if the contract
        // balance is less or equal to the starting balance here.
        require(address(this).balance <= startBalance, "Invalid balance");
    }

    function validatePayload(TransactionPayload calldata) internal pure override returns (bool) {
        return true;
    }

    /**
     * @notice Authenticate based on the signature and transaction. This will calculate the EIP-712 message hash and use
     *  that as commit for authentication.
     * @param signature The signature to authenticate with.
     * @param transaction The transaction that was signed.
     * @return signer The recovered signer, or `0x0` if the signature is invalid.
     */
    function authenticate(Signature calldata signature, Transaction calldata transaction)
        internal
        view
        returns (address signer)
    {
        bytes32 commit = getCommitHash(transaction);

        uint256 r = signature.r;
        uint256 s = signature.s;
        bool v = signature.v;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            signer := auth(commit, v, r, s)
        }
    }

    /*//////////////////////////////////////////////////////////////
                                HASHING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the EIP-712 commit hash for a transaction, that can be used for authentication.
     * @param transaction The transaction to hash.
     * @return The commit hash, including the EIP-712 prefix and domain separator.
     */
    function getCommitHash(Transaction calldata transaction) internal view returns (bytes32) {
        return
            keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), getDomainSeparator(), hashTransaction(transaction)));
    }

    /**
     * @notice Get the EIP-712 hash for a transaction.
     * @param transaction The transaction to hash.
     * @return The hashed transaction.
     */
    function hashTransaction(Transaction calldata transaction) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(TRANSACTION_TYPE, transaction.from, transaction.nonce, hashPayloads(transaction.payloads))
        );
    }

    /**
     * @notice Get the EIP-712 hash for a transaction payload array.
     * @param payloads The payload(s) to hash.
     * @return The hashed transaction payloads.
     */
    function hashPayloads(TransactionPayload[] calldata payloads) internal pure returns (bytes32) {
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
    function hashPayload(TransactionPayload calldata payload) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(TRANSACTION_PAYLOAD_TYPE, payload.to, payload.value, payload.gasLimit, keccak256(payload.data))
        );
    }
}
