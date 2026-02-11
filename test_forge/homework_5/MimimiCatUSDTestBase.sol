// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { Accounts } from "../helpers/Accounts.sol";
import { MimimiCatUSD } from "../../contracts/homework_5/MimimiCatUSD.sol";
import { MockAggregatorV3 } from "../../contracts/homework_5/mocks/MockAggregatorV3.sol";
import { MockWETH } from "../../contracts/homework_5/mocks/MockWETH.sol";

abstract contract MimimiCatUSDTestBase is Test, Accounts {
    using stdStorage for StdStorage;

    address constant MULTISIG_ADDRESS = address(1);
    uint8 constant STATE_PAUSE = 1;
    uint8 constant STATE_OPEN = 2;
    uint32 constant MAX_SUPPLY = 15;
    uint32 constant WHITELIST_SUPPLY = 5;
    // 100 USD (8 decimals)
    uint256 constant MINT_PRICE_USD = 100e8;
    // ETH/USD = 2000 => getMintPriceInWei = 100e8 * 1e18 / 2000e8 = 0.05 ether
    uint256 constant MINT_PRICE_WEI = 0.05 ether;
    int256 constant AGGREGATOR_ETH_USD = 2000e8;

    string constant BASE_URI = "ipfs://hidden_metadata";

    MimimiCatUSD public mimimiCatUSD;
    MockAggregatorV3 public mockAggregator;
    MockWETH public mockWETH;

    Signer public owner;

    function setUp() public virtual {
        createSigners(35);
        owner = signers[0];

        vm.startPrank(owner.addr);
        mockAggregator = new MockAggregatorV3();
        mockAggregator.setAnswer(AGGREGATOR_ETH_USD);
        mockWETH = new MockWETH();

        mimimiCatUSD = new MimimiCatUSD(
            MAX_SUPPLY,
            WHITELIST_SUPPLY,
            BASE_URI,
            MINT_PRICE_USD,
            MULTISIG_ADDRESS,
            address(mockAggregator),
            address(mockWETH)
        );
        vm.stopPrank();
        vm.deal(address(mockWETH), 1000 ether); // чтобы withdraw() мог отправить ETH
    }

    modifier withState(uint8 state) {
        stdstore
            .target(address(mimimiCatUSD))
            .enable_packed_slots()
            .sig("state()")
            .checked_write(uint8(state));
        _;
    }

}
