// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// Интерфейс токена для моста: мосту нужны только mint и burn.
interface IBridgeableToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}
