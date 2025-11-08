// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { NativeBank } from "../../contracts/homework_3/NativeBank.sol";

contract Handler is Test {
    NativeBank public bank;
    address[] public users;
    address[] public actors;
    mapping(address => bool) public isUser;
    
    constructor(NativeBank _bank) {
        bank = _bank;

        for (uint i = 0; i < 10; i++) {
            actors.push(makeAddr(string(abi.encodePacked("user", i))));
        }
    }
    
    function deposit(uint256 actorSeed, uint256 amount) public {
        amount = bound(amount, 10000, 100 ether);
        address user = actors[bound(actorSeed, 0, actors.length - 1)];
        
        if (!isUser[user]) {
            users.push(user);
            isUser[user] = true;
        }
        
        vm.deal(user, amount);
        vm.prank(user);
        bank.deposit{value: amount}();
    }
    
    function withdraw(uint256 actorSeed, uint256 amount) public {
        if (users.length == 0) return;
        
        uint256 userIndex = bound(actorSeed, 0, users.length - 1);
        address user = users[userIndex];
        uint256 balance = bank.balanceOf(user);
        
        if (balance == 0) return;
        
        amount = bound(amount, 1, balance);
        
        vm.prank(user);
        bank.withdraw(amount);
    }
    
    function getSumOfUserBalances() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < users.length; i++) {
            sum += bank.balanceOf(users[i]);
        }
        return sum;
    }
}