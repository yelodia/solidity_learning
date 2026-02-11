// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { MimimiCat } from "../../contracts/homework_4/mimimiCat.sol";
import { FlashMintSell } from "../../contracts/homework_5/FlashMintSell.sol";
import { MockFlashLoanPool } from "../../contracts/homework_5/mocks/MockFlashLoanPool.sol";
import { MockNftBuyer } from "../../contracts/homework_5/mocks/MockNftBuyer.sol";
import { MockPoolAddressesProvider } from "../../contracts/homework_5/mocks/MockPoolAddressesProvider.sol";
import { MockWETH } from "../../contracts/homework_5/mocks/MockWETH.sol";
import { Accounts } from "../helpers/Accounts.sol";

abstract contract FlashMintSellTestBase is Test, Accounts {
    using stdStorage for StdStorage;

    address constant MULTISIG_ADDRESS = address(1);
    uint8 constant STATE_OPEN = 2;
    uint32 constant MAX_SUPPLY = 15;
    uint32 constant WHITELIST_SUPPLY = 5;
    uint256 constant MINT_PRICE = 0.05 ether;
    string constant BASE_URI = "ipfs://hidden_metadata";

    MimimiCat public mimimiCat;
    MockNftBuyer public mockNftBuyer;
    FlashMintSell public flashMintSell;
    MockFlashLoanPool public mockPool;
    MockPoolAddressesProvider public mockAddressesProvider;
    MockWETH public mockWETH;

    function setUp() public virtual {
        createSigners(10);
        mockWETH = new MockWETH();
        vm.deal(address(mockWETH), 1000 ether);

        vm.startPrank(signers[0].addr);
        mimimiCat = new MimimiCat(
            MAX_SUPPLY,
            WHITELIST_SUPPLY,
            BASE_URI,
            MINT_PRICE,
            MULTISIG_ADDRESS
        );
        mimimiCat.addStakeHolders(_toArray(signers[0].addr));
        mimimiCat.addModerators(_toArray(signers[0].addr));
        vm.stopPrank();

        stdstore.target(address(mimimiCat)).enable_packed_slots().sig("state()").checked_write(uint8(STATE_OPEN));

        uint256 buyPrice = MINT_PRICE + 0.001 ether;
        mockNftBuyer = new MockNftBuyer(buyPrice);
        vm.deal(address(mockNftBuyer), buyPrice + 1 ether);

        mockPool = new MockFlashLoanPool(address(mockWETH));
        mockWETH.mint(address(mockPool), 1000 ether);
        mockAddressesProvider = new MockPoolAddressesProvider(address(mockPool));

        flashMintSell = new FlashMintSell(address(mockWETH), mockAddressesProvider);
    }

    function _toArray(address a) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = a;
        return arr;
    }

    function _requestMintAndSellDefault() internal {
        _requestMintAndSell(MINT_PRICE);
    }

    function _requestMintAndSell(uint256 amount) internal {
        flashMintSell.requestMintAndSell(
            address(mimimiCat),
            address(mockNftBuyer),
            amount,
            abi.encodeWithSignature("mint()"),
            bytes4(keccak256("buy(address,uint256)"))
        );
    }
}
