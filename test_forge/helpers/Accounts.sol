// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

contract Accounts is Test {

    struct Signer {
        address addr; 
        uint256 privateKey;
    }

    Signer[] public signers;

    function createSigners(uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            (address addr, uint256 privateKey) = makeAddrAndKey(string.concat("account", vm.toString(i)));
            vm.deal(addr, 10_000 ether);
            
            signers.push(Signer(addr, privateKey));
        }
    }
    
    
}