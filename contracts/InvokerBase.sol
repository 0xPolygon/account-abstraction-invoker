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

/**
 * @title Account Abstraction Invoker
 * @author Zero Ekkusu <zeroekkusu.eth>, Maarten Zuidhoorn <maarten@zuidhoorn.com>, Paul O'Leary <poleary@polygon.technology>
 * @notice An EIP-3074 based contract that can send one or more arbitrary transactions in the context of an publicly
 *  Owned Address (EOA), by using `AUTH` and `AUTHCALL`. See https://github.com/0xPolygon/account-abstraction-invoker for more
 *  information.
 */
abstract contract InvokerBase {
    struct Signature {
        uint256 r;
        uint256 s;
        bool v;
    }

    struct TransactionPayload {
        address to;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    string private name;
    string private version;

    bytes32 private constant EIP712DOMAIN_TYPE =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private domainSeparator;

    constructor(string memory _name, string memory _version) {
        name = _name;
        version = _version;
        updateDomainSeparator();
    }

    function getName() external view returns (string memory) {
        return name;
    }

    function getVersion() external view returns (string memory) {
        return version;
    }

    function getEIP712DomainType() external pure returns (bytes32) {
        return EIP712DOMAIN_TYPE;
    }

    function getDomainSeparator() public view returns (bytes32) {
        return domainSeparator;
    }

    /*//////////////////////////////////////////////////////////////
                                UPDATING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice This function can be used to update the domain separator, in case the chain ID changes.
     */
    function updateDomainSeparator() public {
        domainSeparator = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPE, keccak256(bytes(name)), keccak256(bytes(version)), block.chainid, address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                                INVOKING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Send an authenticated call to the address provided in the payload.
     * @dev Currently this function does not return the call data.
     * @param payload The payload to send.
     * @return success Whether the call succeeded.
     */
    function call(TransactionPayload calldata payload) internal returns (bool success) {
        require(validatePayload(payload), "Invalid payload");

        uint256 gasLimit = payload.gasLimit;
        address to = payload.to;
        uint256 value = payload.value;
        bytes memory data = payload.data;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            success := authcall(gasLimit, to, value, 0, add(data, 0x20), mload(data), 0, 0)
        }
    }

    function validatePayload(TransactionPayload calldata) internal virtual returns (bool);
}
