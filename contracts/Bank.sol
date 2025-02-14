// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { INativeBank } from "./INativeBank.sol";
import "hardhat/console.sol";

contract Bank is INativeBank {
    mapping(address client => uint256 balance) public balanceOf;
    uint256 private lock;

    error WithdrawFailed();
    error ReetrancyAttack();

    constructor() {}

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external {
        console.log("check reentrancy", lock);
        if (lock == 1) {
            console.log("it's reentrancy!!!!!!!!!!!!!!!");
            revert ReetrancyAttack();
        }
        lock = 1;

        console.log("execution with lock", lock);

        if (_amount == 0) {
            revert WithdrawalAmountZero(msg.sender);
        }
        if (_amount > balanceOf[msg.sender]) {
            revert WithdrawalAmountExceedsBalance(msg.sender, _amount, balanceOf[msg.sender]);
        }

        balanceOf[msg.sender] -= _amount; // unch
        _send(_amount, msg.sender);

        emit Withdrawal(msg.sender, _amount);
        lock = 0;
    }

    function _send(uint256 _amount, address _account) internal {
        (bool success, ) = _account.call{value: _amount}("");
        //if (!success) {
        //    revert WithdrawFailed();
        //}
    }

}
