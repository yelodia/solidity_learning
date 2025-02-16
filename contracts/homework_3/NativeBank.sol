// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { INativeBank } from "./INativeBank.sol";
import "hardhat/console.sol";

contract NativeBank is INativeBank {
    uint16 public commissionBp;
    uint256 public accumulator;
    uint16 public bps = 10000;
    address public owner;
    mapping(address client => uint256 balance) public balanceOf;
    address[] public stakeHolders;
    uint256 private lock;

    error NotContractOwner();
    error WithdrawFailed();
    error InsufficientDeposit(address account);
    error ReetrancyAttack();

    constructor(address[3] memory _holders) {
        owner = msg.sender;
        for(uint256 i=0; i<3; i++) {
            stakeHolders.push(_holders[i]);
        }
        commissionBp = 100; // 1%
    }

    function deposit() external payable {
        if (commissionBp > 0 && (msg.value * commissionBp) < bps) {
            revert InsufficientDeposit(msg.sender);
        }
        uint256 _amount;
        uint256 _fee = (msg.value * commissionBp) / bps;
        unchecked {
            _amount = msg.value - _fee;
        }
        balanceOf[msg.sender] += _amount;
        accumulator += _fee;
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant allowWithdraw(_amount, balanceOf[msg.sender]) {
        console.log("execution with lock", lock);

        balanceOf[msg.sender] -= _amount; // unch
        _send(_amount, msg.sender);

        emit Withdrawal(msg.sender, _amount);
    }

    function withdrawAccumulator(uint256 _amount) external nonReentrant onlyOwner allowWithdraw(_amount, accumulator) {
        uint256 _diff = _amount % 4;
        uint256 _part = _amount / 4;
        if (_part == 0 ) {
            revert WithdrawalAmountZero(msg.sender);
        }
        accumulator -= _amount; // unch

        _send((_part+_diff), msg.sender);
        for (uint256 i = 0; i < stakeHolders.length; i++) {
            _send(_part, stakeHolders[i]);
        }
    }

    function setCommission(uint16 _commission) external onlyOwner {
        require (_commission <= 2000, "don't be impudent");
        commissionBp = _commission;
    }

    function _send(uint256 _amount, address _account) internal {
        (bool success, ) = _account.call{value: _amount}("");
        //if (!success) {
        //    revert WithdrawFailed();
        //}
    }

    modifier allowWithdraw(uint256 _amount, uint256 _limit) {
        if (_amount == 0) {
            revert WithdrawalAmountZero(msg.sender);
        }
        if (_amount > _limit) {
            revert WithdrawalAmountExceedsBalance(msg.sender, _amount, _limit);
        }
        _;
    }

    modifier nonReentrant() {
        console.log("check reentrancy", lock);
        if (lock == 1) {
            console.log("it's reentrancy!!!!!!!!!!!!!!!");
            revert ReetrancyAttack();
        }
        lock = 1;
        _;
        lock = 0;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert NotContractOwner();
        }
        _;
    }

}
