// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IFlashLoanSimpleReceiver } from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

/*
 Мок пула с flashLoanSimple (совместим с вызовом от FlashMintSell через POOL).
*/
contract MockFlashLoanPool {
    address public immutable weth;
    uint256 public premium;

    constructor(address _weth) {
        weth = _weth;
    }

    function setPremium(uint256 _premium) external {
        premium = _premium;
    }

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 /* referralCode */
    ) external {
        require(asset == weth, "MockPool: only WETH");
        uint256 totalOwed = amount + premium;
        IERC20(asset).transfer(receiverAddress, amount);
        require(
            IFlashLoanSimpleReceiver(receiverAddress).executeOperation(
                asset,
                amount,
                premium,
                msg.sender,
                params
            ),
            "MockPool: executeOperation failed"
        );
        IERC20(asset).transferFrom(receiverAddress, address(this), totalOwed);
    }
}
