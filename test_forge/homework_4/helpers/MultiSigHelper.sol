// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../../../contracts/homework_4/multiSigWallet.sol";

abstract contract MultiSigHelper is Test {
    MultiSigWallet public multiSig;
    address[] public msOwners;
    uint256 public constant CONFIRMATIONS = 3;
    
    function _deployMultiSig(address[] memory owners) internal {
        multiSig = new MultiSigWallet(owners, CONFIRMATIONS);
        msOwners = owners;
    }
    
    function _submitAndConfirm(address to, bytes memory data) internal returns (uint256) {
        vm.prank(msOwners[0]);
        multiSig.submitTransaction(to, 0, data);
        uint256 txIndex = multiSig.getTransactionCount() - 1;
        
        for (uint256 i = 0; i < CONFIRMATIONS; i++) {
            vm.prank(msOwners[i]);
            multiSig.confirmTransaction(txIndex);
        }
        return txIndex;
    }
    
    function _execute(uint256 txIndex) internal {
        vm.prank(msOwners[0]);
        multiSig.executeTransaction(txIndex);
    }
    
    function _submitConfirmExecute(address to, bytes memory data) internal {
        uint256 txIndex = _submitAndConfirm(to, data);
        _execute(txIndex);
    }
}
