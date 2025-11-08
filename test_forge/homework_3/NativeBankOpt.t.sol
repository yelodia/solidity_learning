// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { NativeBankOpt } from "../../contracts/homework_3/NativeBankOpt.sol";
import { ReentrancyAttacker } from "../../contracts/homework_3/test/ReentrancyAttacker.sol";
import { Accounts } from "../helpers/Accounts.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

contract NativeBankOptTest is Test, Accounts {
    using stdStorage for StdStorage;
    NativeBankOpt public bank;
    ReentrancyAttacker public attacker;

    event Deposit(address indexed account, uint256 amount);
    event Withdrawal(address indexed account, uint256 amount);
    
    function setUp() public {
        createSigners(10);

        vm.prank(signers[0].addr);
        bank = new NativeBankOpt([signers[1].addr, signers[2].addr, signers[3].addr]);
    }
    
    function test_CorrectlyConstructsBank() public view {
        assertEq(bank.OWNER(), signers[0].addr);
        //assertEq(bank.commissionBp(), 100);
        assertEq(bank.stakeHolders(0), signers[1].addr);
        assertEq(bank.stakeHolders(1), signers[2].addr);
        assertEq(bank.stakeHolders(2), signers[3].addr);
    }

    // ====== deposit ======
    
    function test_Deposit_Success() public {
        vm.startPrank(signers[5].addr);

        vm.expectEmit();
        emit Deposit(signers[5].addr, 0.99 ether);
        bank.deposit{value: 1 ether}();
        assertEq(bank.balanceOf(signers[5].addr), 0.99 ether);
        assertEq(bank.accumulator(), 0.01 ether);
        assertEq(address(bank).balance, 1 ether);
        
        vm.expectEmit();
        emit Deposit(signers[5].addr, 0.495 ether);
        bank.deposit{value: 0.5 ether}();
        assertEq(bank.balanceOf(signers[5].addr), 1.485 ether);
        assertEq(bank.accumulator(), 0.015 ether);
        assertEq(address(bank).balance, 1.5 ether);

        vm.startPrank(signers[6].addr);

        vm.expectEmit();
        emit Deposit(signers[6].addr, 0.495 ether);
        bank.deposit{value: 0.5 ether}();
        assertEq(bank.balanceOf(signers[6].addr), 0.495 ether);
        assertEq(bank.accumulator(), 0.02 ether);
        assertEq(address(bank).balance, 2 ether);
    }
    
    function test_Deposit_InsufficientDeposit() public {
        vm.expectRevert(
            abi.encodeWithSelector(NativeBankOpt.InsufficientDeposit.selector, signers[5].addr)
        );
        
        vm.prank(signers[5].addr);
        bank.deposit{value: 99}();
    }
    
    function test_Deposit_MinimumAmount() public {
        uint256 minAmount = 100; // минимальная сумма для 1% комиссии
        
        vm.prank(signers[5].addr);
        bank.deposit{value: minAmount}();
        
        assertEq(bank.balanceOf(signers[5].addr), 99);
        assertEq(bank.accumulator(), 1);
    }
    
    function test_Deposit_WithZeroCommission() public {
        stdstore.target(address(bank)).enable_packed_slots().sig("commissionBp()").checked_write(uint16(0));
        uint256 depositAmount = 1 ether;
        
        vm.prank(signers[5].addr);
        bank.deposit{value: depositAmount}();
        
        assertEq(bank.balanceOf(signers[5].addr), depositAmount);
        assertEq(bank.accumulator(), 0);
    }

    // ====== Тесты setCommission ======

    function test_SetCommission_ByOwner() public {
        vm.prank(signers[0].addr);
        bank.setCommission(150);
        
        assertEq(bank.commissionBp(), 150);
    }

    function test_SetCommission_NotByOwner() public {
        vm.expectRevert(NativeBankOpt.NotContractOwner.selector);
        vm.prank(signers[5].addr);
        bank.setCommission(150);
    }

    function test_SetCommission_TooLarge() public {
        vm.expectRevert("don't be impudent");
        vm.prank(signers[0].addr);
        bank.setCommission(2001);
    }

    function test_SetCommission_MaxAllowed() public {
        vm.prank(signers[0].addr);
        bank.setCommission(2000); // 20% - максимум
        
        assertEq(bank.commissionBp(), 2000);
    }

    function test_SetCommission_Zero() public {
        vm.prank(signers[0].addr);
        bank.setCommission(0);
        
        assertEq(bank.commissionBp(), 0);
    }

    function test_SetCommission_AffectsDeposit() public {
        vm.prank(signers[0].addr);
        bank.setCommission(200); // 2%
        
        vm.prank(signers[5].addr);
        bank.deposit{value: 1 ether}();
        
        assertEq(bank.balanceOf(signers[5].addr), 0.98 ether);
        assertEq(bank.accumulator(), 0.02 ether);
    }

    // ====== Тесты withdraw ======

    function before_Withdraw(address user) internal {
        vm.startPrank(user);
        bank.deposit{value: 1 ether}();
    }

    function test_Withdraw_Success() public {
        before_Withdraw(signers[5].addr);
        uint256 userBalanceBefore = signers[5].addr.balance;

        vm.expectEmit();
        emit Withdrawal(signers[5].addr, 0.5 ether);
        bank.withdraw(0.5 ether);
        assertEq(bank.balanceOf(signers[5].addr), 0.49 ether);
        assertEq(signers[5].addr.balance, userBalanceBefore + 0.5 ether);
        
        vm.expectEmit();
        emit Withdrawal(signers[5].addr, 0.4 ether);
        bank.withdraw(0.4 ether);
        assertEq(bank.balanceOf(signers[5].addr), 0.09 ether);
        assertEq(signers[5].addr.balance, userBalanceBefore + 0.9 ether);
    }

    function test_Withdraw_Zero() public {
        before_Withdraw(signers[5].addr);
        
        vm.expectRevert(
            abi.encodeWithSignature("WithdrawalAmountZero(address)", signers[5].addr)
        );
        bank.withdraw(0);
    }

    function test_Withdraw_ExceedsBalance() public {
        before_Withdraw(signers[5].addr);
        
        vm.expectRevert(
            abi.encodeWithSignature(
                "WithdrawalAmountExceedsBalance(address,uint256,uint256)", 
                signers[5].addr, 
                1.5 ether, 
                0.99 ether
            )
        );
        bank.withdraw(1.5 ether);
    }

    function test_Withdraw_FullBalance() public {
        before_Withdraw(signers[5].addr);
        
        uint256 userBalance = bank.balanceOf(signers[5].addr); // 0.99 ether
        uint256 userEthBefore = signers[5].addr.balance;
        
        bank.withdraw(userBalance);
        
        assertEq(bank.balanceOf(signers[5].addr), 0);
        assertEq(signers[5].addr.balance, userEthBefore + userBalance);
    }

    // ====== Тесты withdrawAccumulator ======

    function before_WithdrawAccumulator() internal {
        vm.prank(signers[5].addr);
        bank.deposit{value: 20 ether}();
    }

    function test_WithdrawAccumulator_NotByOwner() public {
        before_WithdrawAccumulator();
        vm.expectRevert(
            abi.encodeWithSignature("NotContractOwner()")
        );
        vm.prank(signers[7].addr);
        bank.withdrawAccumulator(150);
    }

    function test_WithdrawAccumulator_Zero() public {
        vm.expectRevert(
            abi.encodeWithSignature("WithdrawalAmountZero(address)", signers[0].addr)
        );
        vm.prank(signers[0].addr);
        bank.withdrawAccumulator(0);
    }
 
    function test_WithdrawAccumulator_ExceedsBalance() public {
        before_WithdrawAccumulator();
        vm.expectRevert(
            abi.encodeWithSignature(
                "WithdrawalAmountExceedsBalance(address,uint256,uint256)",
                signers[0].addr,
                0.3 ether,
                0.2 ether
            )
        );
        vm.prank(signers[0].addr);
        bank.withdrawAccumulator(0.3 ether);
    }

    function test_WithdrawAccumulator_DividedValue() public {
        before_WithdrawAccumulator();
        
        uint256 ownerBalanceBefore = signers[0].addr.balance;
        
        vm.prank(signers[0].addr);
        bank.withdrawAccumulator(0.1 ether);
        
        // 0.1 ether / 4 = 0.025 ether каждому
        assertEq(signers[1].addr.balance, 10000.025 ether);
        assertEq(signers[2].addr.balance, 10000.025 ether);
        assertEq(signers[3].addr.balance, 10000.025 ether);
        assertEq(signers[0].addr.balance, ownerBalanceBefore + 0.025 ether);
        assertEq(address(bank).balance, 19.9 ether);
        assertEq(bank.accumulator(), 0.1 ether);
    }

    function test_WithdrawAccumulator_NonDividedValue() public {
        before_WithdrawAccumulator();
        uint256 ownerBalanceBefore = signers[0].addr.balance;
        
        vm.prank(signers[0].addr);
        bank.withdrawAccumulator(303);
        
        assertEq(signers[1].addr.balance, 10000 ether + 75);
        assertEq(signers[2].addr.balance, 10000 ether + 75);
        assertEq(signers[3].addr.balance, 10000 ether + 75);
        assertEq(signers[0].addr.balance, ownerBalanceBefore + 75 + 3); // 75 + остаток 3
        assertEq(address(bank).balance, 20 ether - 303);
        assertEq(bank.accumulator(), 0.2 ether - 303);
    }

    function test_WithdrawAccumulator_TooSmall() public {
        before_WithdrawAccumulator();

        vm.expectRevert(
            abi.encodeWithSignature("WithdrawalAmountZero(address)", signers[0].addr)
        );
        vm.prank(signers[0].addr);
        bank.withdrawAccumulator(3);
    }

    // ====== Тесты SetHolders ======

    function test_SetHolders_NotByOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotContractOwner()", signers[7].addr)
        );
        vm.prank(signers[7].addr);
        bank.setHolders([signers[7].addr, signers[8].addr, signers[9].addr]);
    }

    function test_SetHolders() public {
        vm.prank(signers[0].addr);
        bank.setHolders([signers[7].addr, signers[8].addr, signers[9].addr]);
        assertEq(bank.stakeHolders(0), signers[7].addr);
        assertEq(bank.stakeHolders(1), signers[8].addr);
        assertEq(bank.stakeHolders(2), signers[9].addr);
    }

    // ====== Miscellaneous ======

    function testFuzz_Deposit(uint256 amount) public {
        amount = bound(amount, 10000, 100 ether);
        
        vm.deal(signers[9].addr, amount);
        vm.prank(signers[9].addr);
        bank.deposit{value: amount}();
        
        uint256 expectedFee = (amount * 100) / 10000;
        uint256 expectedBalance = amount - expectedFee;
        
        assertEq(bank.balanceOf(signers[9].addr), expectedBalance);
        assertEq(bank.accumulator(), expectedFee);
        assertEq(address(bank).balance, amount);
    }

    function test_Withdraw_ReentrancyProtected() public {
        attacker = new ReentrancyAttacker(address(bank));
        
        vm.deal(address(bank), 5 ether);
        
        vm.expectRevert();
        vm.prank(signers[6].addr);
        attacker.attack{value: 2 ether}();
        assertEq(address(bank).balance, 5 ether);
    }

}

