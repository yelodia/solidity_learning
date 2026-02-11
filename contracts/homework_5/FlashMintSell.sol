// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FlashLoanSimpleReceiverBase } from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import { IPoolAddressesProvider } from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import { IWETH } from "./IWETH.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
 Универсальный флеш-займ: займ (WETH) → withdraw в ETH → произвольный минт NFT (payable) → approve → произвольный выкуп.
 Поддерживает nft контракты, которые после минта возвращат tokenId и площадки, которые выкупают NFT по определенной цене
 Цена выкупа на площадке должна быть больше цены минта, иначе минт с займом не удастся
*/

contract FlashMintSell is FlashLoanSimpleReceiverBase {
    address public immutable weth;

    error InsufficientProceeds();
    error MintFailed();
    error MintReturnInvalid();
    error BuyFailed();

    constructor(address _weth, IPoolAddressesProvider _addressesProvider)
        FlashLoanSimpleReceiverBase(_addressesProvider)
    {
        weth = _weth;
    }

    // amount Сумма займа (цена минта в wei).
    // mintCalldata Calldata для минта на nftContract (вызов с value=amount).
    // buySelector Селектор выкупа (address nftContract, uint256 tokenId).
    // Выгода с арбитража (остаток после возврата займа) переводится вызывающему (msg.sender).
    function requestMintAndSell(
        address _nftContract,
        address _buyer,
        uint256 amount,
        bytes calldata mintCalldata,
        bytes4 buySelector
    ) external {
        POOL.flashLoanSimple(
            address(this),
            weth,
            amount,
            abi.encode(msg.sender, _nftContract, _buyer, mintCalldata, buySelector),
            0
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(initiator == address(this), "FlashMintSell: only self");
        (address beneficiary, address _nftContract, address _buyer, bytes memory mintCalldata, bytes4 buySelector) =
            abi.decode(params, (address, address, address, bytes, bytes4));

        IWETH(asset).withdraw(amount);
        (bool ok, bytes memory mintResult) = _nftContract.call{ value: amount }(mintCalldata);
        if (!ok) revert MintFailed();
        if (mintResult.length < 32) revert MintReturnInvalid();
        uint256 tokenId = abi.decode(mintResult, (uint256));

        IERC721(_nftContract).approve(_buyer, tokenId);
        (bool buyOk,) = _buyer.call(abi.encodeWithSelector(buySelector, _nftContract, tokenId));
        if (!buyOk) revert BuyFailed();
        _repayAndSendProfit(beneficiary, asset, amount, premium);
        return true;
    }

    function _repayAndSendProfit(address beneficiary, address asset, uint256 amount, uint256 premium) internal {
        uint256 totalOwed = amount + premium;
        require(address(this).balance >= totalOwed, "FlashMintSell: insufficient proceeds");
        if (address(this).balance > totalOwed) {
            (bool sent,) = payable(beneficiary).call{ value: address(this).balance - totalOwed }("");
            require(sent, "FlashMintSell: profit transfer failed");
        }
        IWETH(weth).deposit{ value: totalOwed }();
        IERC20(asset).approve(msg.sender, totalOwed);
    }

    receive() external payable {}
}
