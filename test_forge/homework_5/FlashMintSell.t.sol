// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { FlashMintSellTestBase } from "./FlashMintSellTestBase.sol";
import { FlashMintSell } from "../../contracts/homework_5/FlashMintSell.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract FlashMintSellTest is FlashMintSellTestBase {
    function test_NftInBuyer() public {
        vm.prank(signers[1].addr);
        _requestMintAndSellDefault();

        assertEq(IERC721(mimimiCat).ownerOf(1), address(mockNftBuyer));
    }

    function test_PoolGetsRepaid() public {
        uint256 poolBalanceBefore = mockWETH.balanceOf(address(mockPool));
        vm.prank(signers[1].addr);
        _requestMintAndSellDefault();
        uint256 poolBalanceAfter = mockWETH.balanceOf(address(mockPool));

        assertEq(poolBalanceAfter, poolBalanceBefore);
    }

    function test_FlashContractNoLeftoverWETH() public {
        vm.prank(signers[1].addr);
        _requestMintAndSellDefault();

        assertEq(mockWETH.balanceOf(address(flashMintSell)), 0);
    }

    function test_BeneficiaryReceivesProfit() public {
        address beneficiary = signers[1].addr;
        uint256 balanceBefore = beneficiary.balance;
        vm.prank(beneficiary);
        _requestMintAndSellDefault();
        uint256 balanceAfter = beneficiary.balance;
        // buyPrice = MINT_PRICE + 0.001 ether, premium = 0 => profit = 0.001 ether
        assertEq(balanceAfter - balanceBefore, 0.001 ether);
    }

    // --- Неуспешные сценарии ---

    function testRevert_MintFails_WrongAmount() public {
        vm.prank(signers[1].addr);
        vm.expectRevert(FlashMintSell.MintFailed.selector);
        _requestMintAndSell(MINT_PRICE - 0.01 ether); // меньше цены минта → mint() ревертит
    }

    function testRevert_BuyFails_BuyerHasNoEth() public {
        vm.deal(address(mockNftBuyer), 0); // у покупателя нет ETH для оплаты
        vm.prank(signers[1].addr);
        vm.expectRevert(FlashMintSell.BuyFailed.selector);
        _requestMintAndSellDefault();
    }

    function testRevert_InsufficientProceeds() public {
        mockPool.setPremium(0.001 ether);           // долг = amount + 0.001 ether
        mockNftBuyer.setBuyPrice(MINT_PRICE);       // покупатель платит ровно цену минта
        vm.prank(signers[1].addr);
        vm.expectRevert("FlashMintSell: insufficient proceeds");
        _requestMintAndSellDefault();
    }
}
