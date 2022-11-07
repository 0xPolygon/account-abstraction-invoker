// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockContract {
    address public lastSender;
    uint256 public counter;

    function increment() external payable {
        lastSender = msg.sender;
        ++counter;
    }

    function causeRevert() external payable {
        revert();
    }

    function reset() external {
        delete lastSender;
        delete counter;

        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }
}
