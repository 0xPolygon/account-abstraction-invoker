// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface WETH9 {
    function balanceOf(address) external returns (uint256);
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address, uint256) external returns (bool);
}

/**
 * @dev Example implementation of an EIP-3074 relayer invoker contract.
 *
 * This example illustrates how a Solidity integration for EIP-3074 could look
 * like. It assumes a Solidity-native struct-like type for the transaction-like
 * bundle for sponsored sub-transactions.
 *
 * The idea for this example is a relayer contract operated by a single owner
 * (the relayer). As part of the relay process, the contract first executes a
 * payment transaction from the sponsee. It then checks that this transaction
 * resulted in a payment sufficient to cover all transactions to be sponsored.
 * Afterwards, it executes each sponsored transaction. Finally, it refunds any
 * unused payment.
 */
contract EIP3074Relayer is Ownable {
    // The canonical mainnet wrapped ETH ERC-20 contract.
    WETH9 constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Some approximate gas accounting for the execution outside of the sub-transactions.
    uint256 constant outerGas  = 30_000;
    uint256 constant innerGas  = 10_000;
    uint256 constant refundGas =  5_000;

    // Replay protection
    mapping(address => uint256) public nonces;

    // This struct is only provided to make this example be valid Solidity.
    // Native Solidity support could expose a type similar to this struct, with additional
    // functions like tlpSponsored.send{value: _, gas: _}()
    struct tlpSponsored {
        address sponsee;
        uint256 nextra;
        address to;
        uint256 mingas;
        uint256 value;
        bytes data;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev Relays an array of sponsored transactions.
     *
     * Accepts a payment transaction and a list of transactions to be sponsored.
     */
    function relay(tlpSponsored memory paymentTx, tlpSponsored[] memory sponsoredTxs) external onlyOwner {
        // Some accounting.
        uint256 startGas = gasleft();
        uint256 startBalance = WETH.balanceOf(address(this));
        uint256 gasPrice = tx.gasprice;
        uint256 txNum = sponsoredTxs.length;

        // Load and increase the sponsee nonce in the contract.
        // This nonce is used for the relay bundle as a whole, i.e. for all sponsored transactions.
        address sponsee = paymentTx.sponsee;
        uint256 nonce = nonces[sponsee];
        nonces[sponsee] += 1;

        // Check nextra field for payment transaction, fingerprinting three values:
        // 1: The sponsee nonce for replay protection
        // 2: The position of the transaction as payment transaction
        // 3: The number of transactions to be sponsored
        require(paymentTx.nextra == uint256(keccak256(abi.encode(nonce, 0, txNum))), "incorrect nextra");
        // Execute the payment transaction and require its success
        require(sendTlpSponsored(paymentTx), "unsuccessful payment");
        // Determine the payment amout by comparing the prior and posterior WETH balances.
        uint256 payment = WETH.balanceOf(address(this)) - startBalance;

        // Calculate the maximum ETH requred for the relay bundle, consisting of two parts:
        // gasBudget: The amount of gas the ETH has to be able to pay for
        // valueBudget: The amount of ETH to be sent with the sponsored transactions directly
        uint256 gasBudget = paymentTx.mingas;
        uint256 valueBudget = paymentTx.value;
        for (uint256 i = 0; i < txNum; i++) {
            gasBudget += sponsoredTxs[i].mingas;
            valueBudget += sponsoredTxs[i].value;
        }
        // Require that the payment made covers the maximum cost.
        uint256 minPayment = valueBudget + gasPrice * (outerGas + innerGas + gasBudget);
        require(payment >= minPayment, "insufficient payment");

        // If raw ETH is required, withdraw it from the WETH contract.
        if (valueBudget > 0) {
            WETH.withdraw(valueBudget);
        }

        // Iterate through sponsored transactions
        for (uint256 i = 0; i < txNum; i++) {
            // Require that the sponsored transaction is sent from the same account as the payment was
            require(sponsoredTxs[i].sponsee == sponsee, "incorrect sponsee");
            // Check nextra field for sponsored transaction, fingerprinting two values:
            // 1: The sponsee nonce for replay protection (same nonce for whole relay bundle)
            // 2: The position of the transaction within the relay bundle, starting at 1
            require(sponsoredTxs[i].nextra == uint256(keccak256(abi.encode(nonce, i + 1))), "incorrect nextra");
            // Execute the sponsored transaction and ignore its success
            sendTlpSponsored(sponsoredTxs[i]);
        }

        // Convert any remaining raw ETH from failed transactions back to wrapped ETH
        uint256 valueLeft = address(this).balance;
        if (valueLeft > 0) {
            WETH.deposit{value: valueLeft}();
        }

        // Calculate the total cost of the relay transaction and pay out any potential refund.
        uint256 totalCost = valueBudget - valueLeft + gasPrice * (outerGas + startGas - gasleft() + refundGas);
        if (totalCost < payment) {
            WETH.transfer(sponsee, payment - totalCost);
        }
    }

    /**
     * @dev Withdraws the contract's WETH balance.
     *
     * Allows the owner to withdraw any WETH the contract holds.
     */
    function withdraw(address target) external onlyOwner {
        WETH.transfer(target, WETH.balanceOf(address(this)));
    }

    /**
     * @dev Dummy function for tlpSponsored.send().
     *
     * Dummy function provided for compatibility with vanilla Solidity.
     * Used as a stand-in for tlpSponsored.send(), with both value and gas automatically
     * set by Solidity with the values from the tlpSponsored tlb.
     *
     * Returns success of the sponsored transaction, throws on a failing pre-check.
     */
    function sendTlpSponsored(tlpSponsored memory tlp) internal returns (bool) {
        // return tlp.send();
        return false;
    }
}