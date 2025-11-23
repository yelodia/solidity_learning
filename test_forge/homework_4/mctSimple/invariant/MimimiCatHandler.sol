// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MimimiCat} from "../../../../contracts/homework_4/mimimiCat.sol";
import {Accounts} from "../../../helpers/Accounts.sol";

contract MimimiCatHandler is Test, Accounts {
    MimimiCat public mimimiCat;
    
    uint256 public ghost_paidMints;
    uint256 public ghost_freeMints;
    mapping(address => bool) public ghost_hasFreeMinted;
    
    mapping(address => bytes32[]) public whitelistProofs;
    
    constructor(MimimiCat _mimimiCat, Signer[] memory _users) {
        mimimiCat = _mimimiCat;
        signers = _users;
    }
    
    function setWhitelistProof(address user, bytes32[] memory proof) external {
        whitelistProofs[user] = proof;
    }
    
    function mint(uint256 userSeed) public {
        address user = signers[bound(userSeed, 0, signers.length - 1)].addr;
        
        vm.startPrank(user);
        try mimimiCat.mint{value: mimimiCat.mintPrice()}() {
            ghost_paidMints++;
        } catch {
            // Expected failures
        }
        vm.stopPrank();
    }
    
    function freeMint(uint256 userSeed) public {
        address user = signers[bound(userSeed, 0, signers.length - 1)].addr;
        bytes32[] memory proof = whitelistProofs[user];
        
        if (proof.length == 0) return;
        if (ghost_hasFreeMinted[user]) return;
        
        vm.prank(user);
        try mimimiCat.freeMint(proof) {
            ghost_freeMints++;
            ghost_hasFreeMinted[user] = true;
        } catch {
            // Expected failures
        }
    }
    
}