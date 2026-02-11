// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * Мок покупателя NFT для тестов FlashMintSell.
 * Принимает NFT и платит buyPrice в ETH вызывающему.
 */
contract MockNftBuyer {
    uint256 public buyPrice;

    constructor(uint256 _buyPrice) {
        buyPrice = _buyPrice;
    }

    function setBuyPrice(uint256 _buyPrice) external {
        buyPrice = _buyPrice;
    }

    function buy(IERC721 nft, uint256 tokenId) external {
        nft.transferFrom(msg.sender, address(this), tokenId);
        (bool ok,) = payable(msg.sender).call{ value: buyPrice }("");
        require(ok, "MockNftBuyer: transfer failed");
    }

    receive() external payable {}
}
