// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MimimiCatIntegrationTestBase} from "./MimimiCatIntegrationTestBase.sol";

contract FullLifecycleTest is MimimiCatIntegrationTestBase {
    
    function test_fullLotteryLifecycle() public {
        // 1. Setup roles - in setUp global
        
        // 2. Set whitelist via multisig
        bytes memory whitelistData = abi.encodeWithSignature("setWhiteList(bytes32)", whitelistRoot);
        _submitConfirmExecute(address(mimimiCat), whitelistData);
        assertEq(mimimiCat.whiteList(), whitelistRoot);
        
        // 3. Open mint
        vm.prank(moderator);
        mimimiCat.setState(STATE_OPEN);
        assertEq(mimimiCat.state(), STATE_OPEN);
        
        // 4. Mint tokens
        for (uint256 i = 10; i < 13; i++) {
            vm.prank(signers[i].addr);
            mimimiCat.mint{value: MINT_PRICE}();
        }
        assertEq(address(mimimiCat).balance, MINT_PRICE * 3);
        
        // 5. Close via multisig
        bytes memory closeData = abi.encodeWithSignature("close(string)", REVEALED_URI);
        _submitConfirmExecute(address(mimimiCat), closeData);
        assertEq(mimimiCat.state(), STATE_CLOSE);
        assertEq(mimimiCat.tokenURI(1), string.concat(REVEALED_URI, "1"));
        
        // 6. Withdraw
        uint256 balanceBefore = stakeholder.balance;
        vm.prank(stakeholder);
        mimimiCat.withdraw(MINT_PRICE * 2);
        assertEq(stakeholder.balance, balanceBefore + MINT_PRICE * 2);
        assertEq(address(mimimiCat).balance, MINT_PRICE);
    }
}


contract ExceededMintLimitTest is MimimiCatIntegrationTestBase {
    
    function setUp() public override {
        super.setUp();
        
        bytes memory whitelistData = abi.encodeWithSignature("setWhiteList(bytes32)", whitelistRoot);
        _submitConfirmExecute(address(mimimiCat), whitelistData);
        
        vm.prank(moderator);
        mimimiCat.setState(STATE_OPEN);
    }
    
    function test_paidPoolFilledFirst() public {
        // Paid minters fill 10 slots (MAX_SUPPLY - WHITELIST_SUPPLY)
        for (uint256 i = 10; i < 20; i++) {
            vm.prank(signers[i].addr);
            mimimiCat.mint{value: MINT_PRICE}();
        }
        
        // 11th paid mint should revert
        vm.prank(signers[20].addr);
        vm.expectRevert(abi.encodeWithSignature("MCTLimitExceed(address)", signers[20].addr));
        mimimiCat.mint{value: MINT_PRICE}();
        
        // Whitelist can still mint all 5
        for (uint256 i = 30; i < 35; i++) {
            vm.startPrank(signers[i].addr);
            mimimiCat.freeMint(getProof(signers[i].addr));
            vm.stopPrank();
        }
        
        // All 15 tokens minted
        assertEq(mimimiCat.tokenURI(15), BASE_URI);
    }
    
    function test_whitelistPoolFilledFirst() public {
        // Whitelist mint all 5
        for (uint256 i = 30; i < 35; i++) {
            vm.startPrank(signers[i].addr);
            mimimiCat.freeMint(getProof(signers[i].addr));
            vm.stopPrank();
        }
        
        // Paid minters fill remaining 10
        for (uint256 i = 10; i < 20; i++) {
            vm.prank(signers[i].addr);
            mimimiCat.mint{value: MINT_PRICE}();
        }
        
        // 11th paid mint should revert
        vm.prank(signers[20].addr);
        vm.expectRevert(abi.encodeWithSignature("MCTLimitExceed(address)", signers[20].addr));
        mimimiCat.mint{value: MINT_PRICE}();
        
        // All 15 tokens minted
        assertEq(mimimiCat.tokenURI(15), BASE_URI);
    }
}


contract MultiSigFailuresTest is MimimiCatIntegrationTestBase {
    
    function testRevert_insufficientConfirmations() public {
        bytes memory closeData = abi.encodeWithSignature("close(string)", REVEALED_URI);
        
        // Submit
        vm.prank(msOwners[0]);
        multiSig.submitTransaction(address(mimimiCat), 0, closeData);
        uint256 txIndex = multiSig.getTransactionCount() - 1;
        
        // Only 2 confirmations (need 3)
        vm.prank(msOwners[1]);
        multiSig.confirmTransaction(txIndex);
        
        // Execute should fail
        vm.prank(msOwners[0]);
        vm.expectRevert("cannot execute tx");
        multiSig.executeTransaction(txIndex);
    }
    
    function test_revokeConfirmation() public {
        bytes memory closeData = abi.encodeWithSignature("close(string)", REVEALED_URI);
        uint256 txIndex = _submitAndConfirm(address(mimimiCat), closeData);
        
        // Revoke one confirmation
        vm.prank(msOwners[1]);
        multiSig.revokeConfirmation(txIndex);
        
        // Now only 2 confirmations, execute should fail
        vm.prank(msOwners[0]);
        vm.expectRevert("cannot execute tx");
        multiSig.executeTransaction(txIndex);
        
        // Add confirmation back
        vm.prank(msOwners[1]);
        multiSig.confirmTransaction(txIndex);
        
        // Now it works
        _execute(txIndex);
        assertEq(mimimiCat.state(), STATE_CLOSE);
    }
}


contract BlacklistPriorityTest is MimimiCatIntegrationTestBase {
    
    function testRevert_blacklistedUserInWhitelist() public {
        // Setup
        
        bytes memory whitelistData = abi.encodeWithSignature("setWhiteList(bytes32)", whitelistRoot);
        _submitConfirmExecute(address(mimimiCat), whitelistData);
        
        vm.prank(moderator);
        mimimiCat.setState(STATE_OPEN);
        
        // Blacklist user who is in whitelist
        address whitelistUser = signers[30].addr;
        vm.prank(moderator);
        mimimiCat.setToBlackList(whitelistUser, true);
        
        // User is in whitelist
        assertTrue(mimimiCat.inWhiteList(whitelistUser, getProof(whitelistUser)));
        
        // But paid mint should fail (blacklist priority)
        vm.prank(whitelistUser);
        vm.expectRevert(abi.encodeWithSignature("MCTAdddresInBlackList(address)", whitelistUser));
        mimimiCat.mint{value: MINT_PRICE}();
        
        // Free mint works (no blacklist check in freeMint)
        vm.startPrank(whitelistUser);
        mimimiCat.freeMint(getProof(whitelistUser));
        vm.stopPrank();
        assertEq(mimimiCat.ownerOf(1), whitelistUser);
    }
}
