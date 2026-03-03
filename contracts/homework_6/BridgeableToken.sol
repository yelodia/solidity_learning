// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/*
 ERC20-токен для моста: минтить и сжигать может только контракт моста.
*/
contract BridgeableToken is ERC20, Ownable {
    // Адрес контракта моста (единственный, кто может вызывать mint/burn)
    address public bridge;

    error OnlyBridge();
    error BridgeAlreadySet();

    modifier onlyBridge() {
        if (msg.sender != bridge) revert OnlyBridge();
        _;
    }

    constructor(string memory name_, string memory symbol_, uint256 initialSupply) ERC20(name_, symbol_) Ownable(msg.sender) {
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    // Устанавливает адрес моста (только владелец, один раз)
    function setBridge(address bridge_) external onlyOwner {
        if (bridge != address(0)) revert BridgeAlreadySet();
        bridge = bridge_;
    }

    function mint(address to, uint256 amount) external onlyBridge {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyBridge {
        _burn(from, amount);
    }
}
