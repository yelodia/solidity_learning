// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPoolAddressesProvider } from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

/**
 * Мок для тестов: возвращает заданный pool из getPool(), остальные методы — заглушки.
 */
contract MockPoolAddressesProvider is IPoolAddressesProvider {
    address private _pool;

    constructor(address pool_) {
        _pool = pool_;
    }

    function getPool() external view override returns (address) {
        return _pool;
    }

    function getMarketId() external pure override returns (string memory) {
        return "mock";
    }

    function setMarketId(string calldata) external pure override {
        revert("Mock: not implemented");
    }

    function getAddress(bytes32) external pure override returns (address) {
        return address(0);
    }

    function setAddressAsProxy(bytes32, address) external pure override {
        revert("Mock: not implemented");
    }

    function setAddress(bytes32, address) external pure override {
        revert("Mock: not implemented");
    }

    function setPoolImpl(address) external pure override {
        revert("Mock: not implemented");
    }

    function getPoolConfigurator() external pure override returns (address) {
        return address(0);
    }

    function setPoolConfiguratorImpl(address) external pure override {
        revert("Mock: not implemented");
    }

    function getPriceOracle() external pure override returns (address) {
        return address(0);
    }

    function setPriceOracle(address) external pure override {
        revert("Mock: not implemented");
    }

    function getACLManager() external pure override returns (address) {
        return address(0);
    }

    function setACLManager(address) external pure override {
        revert("Mock: not implemented");
    }

    function getACLAdmin() external pure override returns (address) {
        return address(0);
    }

    function setACLAdmin(address) external pure override {
        revert("Mock: not implemented");
    }

    function getPriceOracleSentinel() external pure override returns (address) {
        return address(0);
    }

    function setPriceOracleSentinel(address) external pure override {
        revert("Mock: not implemented");
    }

    function getPoolDataProvider() external pure override returns (address) {
        return address(0);
    }

    function setPoolDataProvider(address) external pure override {
        revert("Mock: not implemented");
    }
}
