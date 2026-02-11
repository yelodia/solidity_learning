// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { MimimiCat } from "../homework_4/mimimiCat.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// OpenZeppelin не предоставляет интерфейс WETH9 (deposit/withdraw)
import { IWETH } from "./IWETH.sol";

/*
 MimimiCat с ценой минта в USD (Chainlink) и оплатой в WETH.
 mintPrice хранит цену в USD (8 decimals, как у Chainlink).
 Контракт забирает WETH у пользователя после запроса к оракулу. 
 Пользователь должен предварительно сделать аппрув своих weth контракту.
 на балансе остаётся нативный ETH (unwrap).
*/
contract MimimiCatUSD is MimimiCat {
    error MCTWETHTransferFailed(address from, uint256 requiredWei);

    address public immutable ethUsdAggregator;
    address public immutable weth;

    constructor(
        uint32 _maxSupply,
        uint32 _whiteListSupply,
        string memory _uri,
        uint256 _mintPriceUSD,
        address signer,
        address _ethUsdAggregator,
        address _weth
    ) MimimiCat(_maxSupply, _whiteListSupply, _uri, _mintPriceUSD, signer) {
        ethUsdAggregator = _ethUsdAggregator;
        weth = _weth;
    }

    function mint() external payable override returns (uint256) {
        revert("MimimiCatUSD: use mintUSD");
    }

    function signedMint(address, uint8, bytes32, bytes32) external payable override returns (uint256) {
        revert("MimimiCatUSD: use signedMintUSD");
    }

    function getMintPriceInWei() public view returns (uint256) {
        (, int256 answer,,,) = AggregatorV3Interface(ethUsdAggregator).latestRoundData();
        require(answer > 0, "MimimiCatUSD: invalid price");
        // mintPrice в USD (8 decimals), answer — ETH/USD (8 decimals)
        // requiredWei = (mintPriceUSD * 1e18) / ethUsdPrice
        return (uint256(mintPrice) * 1e18) / uint256(answer);
    }

    function _mintMCT(address _account) internal override mintEnabled(MAX_SUPPLY - whiteListSupply) returns (uint256) {
        require(!this.blackList(_account), MCTAdddresInBlackList(_account));
        uint256 requiredWei = getMintPriceInWei();
        bool ok = IWETH(weth).transferFrom(msg.sender, address(this), requiredWei);
        if (!ok) revert MCTWETHTransferFailed(msg.sender, requiredWei);
        IWETH(weth).withdraw(requiredWei);

        uint256 tokenId = tokenIdCounter;
        _mint(_account, tokenId);
        return tokenId;
    }

    // Минт с оплатой в WETH по курсу оракула.
    function mintUSD() external returns (uint256) {
        return _mintMCT(msg.sender);
    }

    // Мета-транзакция минта с оплатой в WETH.
    function signedMintUSD(address _owner, uint8 v, bytes32 r, bytes32 s) external returns (uint256) {
        _validateMint(_owner, v, r, s);
        return _mintMCT(_owner);
    }

    receive() external payable {}
}
