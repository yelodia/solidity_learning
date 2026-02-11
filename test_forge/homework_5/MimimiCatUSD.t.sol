// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { MimimiCatUSDTestBase } from "./MimimiCatUSDTestBase.sol";

contract InitializationMimimiCatUSDTest is MimimiCatUSDTestBase {
    function test_immutableAddresses() public view {
        assertEq(mimimiCatUSD.ethUsdAggregator(), address(mockAggregator));
        assertEq(mimimiCatUSD.weth(), address(mockWETH));
        assertEq(mimimiCatUSD.mintPrice(), MINT_PRICE_USD);
    }
}

contract GetMintPriceInWeiTest is MimimiCatUSDTestBase {
    function test_returnsWeiFromOracle() public view {
        assertEq(mimimiCatUSD.getMintPriceInWei(), MINT_PRICE_WEI);
    }

    function test_whenOraclePriceChanges() public {
        // 4000 USD/ETH => 100e8 * 1e18 / 4000e8 = 0.025 ether
        mockAggregator.setAnswer(4000e8);
        assertEq(mimimiCatUSD.getMintPriceInWei(), 0.025 ether);
    }
}

contract MintWithWETHTest is MimimiCatUSDTestBase {
    function test_success() public withState(STATE_OPEN) {
        address user = signers[10].addr;
        mockWETH.mint(user, MINT_PRICE_WEI);
        vm.prank(user);
        mockWETH.approve(address(mimimiCatUSD), MINT_PRICE_WEI);

        uint256 balanceBefore = address(mimimiCatUSD).balance;
        vm.prank(user);
        mimimiCatUSD.mintUSD();

        assertEq(mimimiCatUSD.ownerOf(1), user); // первый минт: модификатор делает tokenIdCounter++ => id = 1
        assertEq(mockWETH.balanceOf(address(mimimiCatUSD)), 0);
        assertEq(address(mimimiCatUSD).balance, balanceBefore + MINT_PRICE_WEI);
    }

    function testRevert_insufficientAllowance() public withState(STATE_OPEN) {
        address user = signers[10].addr;
        mockWETH.mint(user, MINT_PRICE_WEI);
        // no approve — transferFrom reverts in WETH
        vm.prank(user);
        vm.expectRevert();
        mimimiCatUSD.mintUSD();
    }

    function testRevert_insufficientBalance() public withState(STATE_OPEN) {
        address user = signers[10].addr;
        // no mint WETH to user — transferFrom reverts in WETH
        vm.prank(user);
        mockWETH.approve(address(mimimiCatUSD), MINT_PRICE_WEI);
        vm.prank(user);
        vm.expectRevert();
        mimimiCatUSD.mintUSD();
    }
}

