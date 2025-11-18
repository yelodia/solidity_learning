// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title MockMultiSigWallet
 * @notice Упрощённый мок мультисиг-кошелька для unit-тестов
 * @dev Просто выполняет вызовы без проверок подписей/подтверждений
 */
contract MockMultiSigWallet {
    function execute(address target, bytes calldata data) external payable returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: msg.value}(data);
        require(success, "MockMultiSig: call failed");
        return result;
    }
    

    function executeCall(address target, bytes calldata data) external payable {
        (bool success,) = target.call{value: msg.value}(data);
        require(success, "MockMultiSig: call failed");
    }

    receive() external payable {}
}
