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

    struct FlashParams {
        address beneficiary;
        address nftContract;
        address buyer;
        bytes mintCalldata;
        bytes4 buySelector;
    }

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
        FlashParams memory p = _decodeParams(params);

        IWETH(asset).withdraw(amount);
        _doMintAndBuy(p.nftContract, p.buyer, p.mintCalldata, p.buySelector, amount);
        _repayAndSendProfit(p.beneficiary, asset, amount, premium);
        return true;
    }

    function _decodeParams(bytes calldata params) internal pure returns (FlashParams memory p) {
        (p.beneficiary, p.nftContract, p.buyer, p.mintCalldata, p.buySelector) =
            abi.decode(params, (address, address, address, bytes, bytes4));
    }

    function _doMintAndBuy(
        address nftContract,
        address buyer,
        bytes memory mintCalldata,
        bytes4 buySelector,
        uint256 mintValue
    ) internal returns (uint256 tokenId) {
        (bool ok, bytes memory mintResult) = nftContract.call{ value: mintValue }(mintCalldata);
        if (!ok) revert MintFailed();
        if (mintResult.length < 32) revert MintReturnInvalid();
        tokenId = abi.decode(mintResult, (uint256));

        IERC721(nftContract).approve(buyer, tokenId);
        (bool buyOk,) = buyer.call(abi.encodeWithSelector(buySelector, nftContract, tokenId));
        if (!buyOk) revert BuyFailed();
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
