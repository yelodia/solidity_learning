pragma solidity 0.8.28;

import { Bridge } from "../../../contracts/homework_6/Bridge.sol";
import { BridgeTestBase } from "../BridgeTestBase.sol";

contract InitializationTest is BridgeTestBase {
    function test_Constructor_SetsTokenAndRemoteChainId() public view {
        assertEq(address(bridge.token()), address(token));
        assertEq(bridge.remoteChainId(), REMOTE_CHAIN_ID);
        assertEq(bridge.nonce(), 0);
    }
}

contract LockTest is BridgeTestBase {
    function test_Lock_Success() public {
        address user = signers[1].addr;
        uint256 amount = 100 ether;
        vm.startPrank(user);
        token.approve(address(bridge), amount);
        vm.expectEmit(true, true, true, true);
        emit Bridge.BridgeLock(user, amount, uint64(block.chainid), 1);
        bridge.lock(amount);
        vm.stopPrank();
        assertEq(token.balanceOf(user), 900 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
        assertEq(bridge.nonce(), 1);
    }

    function test_Lock_RevertWhen_NoAllowance() public {
        vm.prank(signers[1].addr);
        vm.expectRevert();
        bridge.lock(100 ether);
    }

    function test_Lock_RevertWhen_InsufficientAllowance() public {
        vm.startPrank(signers[1].addr);
        token.approve(address(bridge), 50 ether);
        vm.expectRevert();
        bridge.lock(100 ether);
        vm.stopPrank();
    }
}

contract ReleaseTest is BridgeTestBase {
    function test_Release_Success() public {
        address to = signers[2].addr;
        uint256 amount = 50 ether;
        uint64 nonce = 1;
        vm.prank(signers[0].addr);
        bridge.release(to, amount, REMOTE_CHAIN_ID, nonce);
        assertEq(token.balanceOf(to), amount);
        assertTrue(bridge.processed(keccak256(abi.encodePacked(REMOTE_CHAIN_ID, nonce))));
    }

    function test_Release_RevertWhen_WrongChain() public {
        vm.expectRevert(Bridge.WrongChain.selector);
        bridge.release(signers[2].addr, 50 ether, 80002, 1);
    }

    function test_Release_RevertWhen_AlreadyProcessed() public withProcessed(REMOTE_CHAIN_ID, 1) {
        vm.expectRevert(Bridge.AlreadyProcessed.selector);
        bridge.release(signers[2].addr, 50 ether, REMOTE_CHAIN_ID, 1);
    }
}
