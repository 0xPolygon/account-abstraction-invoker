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
SOFTWARE.
*/

pragma solidity ^0.8.0;

/**
 * @title Account Abstraction Invoker
 * @author Maarten Zuidhoorn <maarten@zuidhoorn.com>, modified by ZeroEkkusu.eth
 * @notice An EIP-3074 based contract that can send one or more arbitrary transactions in the context of an Externally
 *  Owned Address (EOA), by using `AUTH` and `AUTHCALL`. See https://github.com/ZeroEkkusu/account-abstraction-invoker for more
 *  information.
 */
contract AccountAbstractionInvoker {
    string private constant NAME = "Account Abstraction Invoker";
    string private constant VERSION = "1.0.0";

    bytes32 public constant EIP712DOMAIN_TYPE =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 public constant TRANSACTION_TYPE =
        keccak256(
            "Transaction(address from,uint256 nonce,TransactionPayload[] payload)TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)"
        );

    bytes32 public constant TRANSACTION_PAYLOAD_TYPE =
        keccak256(
            "TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)"
        );

    bytes32 public immutable DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    struct Signature {
        uint256 r;
        uint256 s;
        bool v;
    }

    struct Transaction {
        address from;
        uint256 nonce;
        TransactionPayload[] payload;
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
                keccak256(abi.encodePacked(NAME)),
                keccak256(abi.encodePacked(VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Authenticate and send the provided transaction payload(s) in the context of the signer. This function
     *  reverts if the signature is invalid, the nonce is incorrect, or one of the calls failed.
     * @param signature The signature of the transactions to verify.
     * @param transaction The nonce and payload(s) to send.
     */
    function invoke(
        Signature calldata signature,
        Transaction calldata transaction
    ) external payable {
        require(transaction.payload.length > 0, "No transaction payload");

        address signer = authenticate(signature, transaction);
        // Require the signer to be the from address
        // because it is more likely to recover *some* address than address(0).
        require(signer == transaction.from, "Invalid signature");
        require(transaction.nonce == nonces[signer], "Invalid nonce");

        nonces[signer] += 1;

        for (uint256 i = 0; i < transaction.payload.length; i++) {
            bool success = call(transaction.payload[i]);
            require(success, "Transaction failed");
        }

        // To ensure that the caller does not send more funds than used in the transaction payload, we check if the contract
        // balance is zero here.
        require(address(this).balance == 0, "Invalid balance");
    }

    /**
     * @notice Authenticate based on the signature and transaction. This will calculate the EIP-712 message hash and use
     *  that as commit for authentication.
     * @param signature The signature to authenticate with.
     * @param transaction The transaction that was signed.
     * @return signer The recovered signer, or `0x0` if the signature is invalid.
     */
    function authenticate(
        Signature calldata signature,
        Transaction calldata transaction
    ) private view returns (address signer) {
        bytes32 commit = getCommitHash(transaction);

        uint256 r = signature.r;
        uint256 s = signature.s;
        bool v = signature.v;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            signer := auth(commit, v, r, s)
        }
    }

    /**
     * @notice Send an authenticated call to the address provided in the payload.
     * @dev Currently this function does not return the call data.
     * @param payload The payload to send.
     * @return success Whether the call succeeded.
     */
    function call(TransactionPayload calldata payload)
        private
        returns (bool success)
    {
        uint256 gasLimit = payload.gasLimit;
        address to = payload.to;
        uint256 value = payload.value;
        bytes memory data = payload.data;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            success := authcall(
                gasLimit,
                to,
                value,
                0,
                add(data, 0x20),
                mload(data),
                0,
                0
            )
        }
    }

    /**
     * @notice Get the EIP-712 commit hash for a transaction, that can be used for authentication.
     * @param transaction The transaction to hash.
     * @return The commit hash, including the EIP-712 prefix and domain separator.
     */
    function getCommitHash(Transaction calldata transaction)
        private
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    bytes1(0x19),
                    bytes1(0x01),
                    DOMAIN_SEPARATOR,
                    hash(transaction)
                )
            );
    }

    /**
     * @notice Get the EIP-712 hash for a transaction.
     * @param transaction The transaction to hash.
     * @return The hashed transaction.
     */
    function hash(Transaction calldata transaction)
        private
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    TRANSACTION_TYPE,
                    transaction.from,
                    transaction.nonce,
                    hash(transaction.payload)
                )
            );
    }

    /**
     * @notice Get the EIP-712 hash for a transaction payload array.
     * @param payload The payload(s) to hash.
     * @return The hashed transaction payloads.
     */
    function hash(TransactionPayload[] calldata payload)
        private
        pure
        returns (bytes32)
    {
        bytes32[] memory values = new bytes32[](payload.length);
        for (uint256 i = 0; i < payload.length; i++) {
            values[i] = hash(payload[i]);
        }

        return keccak256(abi.encodePacked(values));
    }

    /**
     * @notice Get the EIP-712 hash for a transaction payload.
     * @param payload The payload to hash.
     * @return The hashed transaction payload.
     */
    function hash(TransactionPayload calldata payload)
        private
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    TRANSACTION_PAYLOAD_TYPE,
                    payload.to,
                    payload.value,
                    payload.gasLimit,
                    keccak256(payload.data)
                )
            );
    }
}
