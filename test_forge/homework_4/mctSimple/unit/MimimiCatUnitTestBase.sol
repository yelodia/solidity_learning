// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {MockMultiSigWallet} from "../../helpers/MockMultiSigWallet.sol";
import {MimimiCatTestBase} from "../MimimiCatTestBase.sol";
import {MimimiCat} from "../../../../contracts/homework_4/mimimiCat.sol";


contract MimimiCatUnitTestBase is MimimiCatTestBase {
    using stdStorage for StdStorage;
    
    bytes32 constant ROLE_MODERATOR = keccak256("ROLE_MODERATOR");
    bytes32 constant ROLE_STAKEHOLDER = keccak256("ROLE_STAKEHOLDER");
    
    MockMultiSigWallet public mockMultiSig;

    function deployContracts() public override {
        vm.startPrank(owner.addr);
        
        mockMultiSig = new MockMultiSigWallet();
        mimimiCat = new MimimiCat(
            MAX_SUPPLY,
            WHITELIST_SUPPLY,
            BASE_URI,
            MINT_PRICE,
            address(mockMultiSig)
        );
        
        vm.stopPrank();
    }
    
    // === Модификаторы для setup состояний ===
    
    modifier withBalance(uint256 amount) {
        vm.deal(address(mimimiCat), amount);
        _;
    }
    
    modifier withState(uint8 state) {
        stdstore
            .target(address(mimimiCat))
            .enable_packed_slots()
            .sig("state()")
            .checked_write(uint8(state));
        _;
    }

    modifier withStakeholder(address addr) {
        vm.prank(owner.addr);
        mimimiCat.addStakeHolders(_toArray(addr));
        _;
    }

    modifier withModerator(address addr) {
        vm.prank(owner.addr);
        mimimiCat.addModerators(_toArray(addr));
        _;
    }
    
    modifier withWhitelist() {
        vm.prank(address(mockMultiSig));
        mimimiCat.setWhiteList(whitelistRoot);
        _;
    }
    
    modifier withBlacklist(address addr) {
        stdstore
            .target(address(mimimiCat))
            .enable_packed_slots()
            .sig("blackList(address)")
            .with_key(addr)
            .checked_write(true);
        _;
    }
    
    modifier withMintPrice(uint256 price) {
        stdstore
            .target(address(mimimiCat))
            .enable_packed_slots()
            .sig("mintPrice()")
            .checked_write(uint256(price));
        _;
    }

    modifier withMintToken(address addr) {
        stdstore
            .target(address(mimimiCat))
            .enable_packed_slots()
            .sig("state()")
            .checked_write(uint8(STATE_OPEN));
        vm.startPrank(addr);
        mimimiCat.mint{value: mimimiCat.mintPrice()}();
        vm.stopPrank();
        _;
    }
}
