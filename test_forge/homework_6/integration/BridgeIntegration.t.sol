// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { BridgeTestBase } from "../BridgeTestBase.sol";

/// Интеграционный тест: полный сценарий lock → release без манипуляций со слотами.
contract FullFlowTest is BridgeTestBase {
    function test_FullFlow_LockThenRelease() public {
        address user = signers[1].addr;
        address to = signers[2].addr;
        uint256 amount = 100 ether;

        vm.startPrank(user);
        token.approve(address(bridge), amount);
        bridge.lock(amount);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 900 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
        assertEq(bridge.nonce(), 1);

        vm.prank(signers[0].addr);
        bridge.release(to, amount, REMOTE_CHAIN_ID, 1);

        assertEq(token.balanceOf(to), amount);
        assertTrue(bridge.processed(keccak256(abi.encodePacked(REMOTE_CHAIN_ID, uint64(1)))));
    }
}
