// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { NativeBank } from "../../contracts/homework_3/NativeBank.sol";
import { Handler } from "./Handler.sol";

contract InvariantTests is Test {
    NativeBank bank;
    Handler handler;
    
    function setUp() public {
        address[3] memory holders = [makeAddr("h1"), makeAddr("h2"), makeAddr("h3")];
        bank = new NativeBank(holders);
        
        handler = new Handler(bank);
        targetContract(address(handler));
    }
    
    function invariant_BalanceEqualsSum() public view {
        assertEq(
            address(bank).balance,
            handler.getSumOfUserBalances() + bank.accumulator()
        );
    }
}