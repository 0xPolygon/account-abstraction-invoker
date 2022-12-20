// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockContract {
    /// @notice msg.sender who called increment
    address public lastSender;
    /// @notice Simple counter
    uint256 public counter;

    /// @notice Record msg.sender and increment counter
    function increment() external payable {
        lastSender = msg.sender;
        ++counter;
    }

    /// @notice Cause revert; useful for testing transaction batching
    function causeRevert() external payable {
        revert();
    }

    /// @dev Reset mock to defaults and recover funds
    function reset() external {
        delete lastSender;
        delete counter;

        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }
}
