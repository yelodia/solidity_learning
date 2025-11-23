// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {MimimiCat} from "../../../../contracts/homework_4/mimimiCat.sol";
import {MockMultiSigWallet} from "../../helpers/MockMultiSigWallet.sol";
import {MimimiCatHandler} from "./MimimiCatHandler.sol";
import {Accounts} from "../../../helpers/Accounts.sol";

contract MimimiCatInvariantTest is Test, Accounts {
    uint32 constant MAX_SUPPLY = 100;
    uint32 constant WHITELIST_SUPPLY = 10;
    uint256 constant MINT_PRICE = 0.05 ether;
    
    MimimiCat public mimimiCat;
    MockMultiSigWallet public mockMultiSig;
    MimimiCatHandler public handler;
    Merkle public murky;
    
    function setUp() public {
        createSigners(50);
        
        mockMultiSig = new MockMultiSigWallet();
        
        vm.startPrank(signers[0].addr);
        mimimiCat = new MimimiCat(
            MAX_SUPPLY,
            WHITELIST_SUPPLY,
            "ipfs://base/",
            MINT_PRICE,
            address(mockMultiSig)
        );
        
        mimimiCat.addModerators(_toArray(signers[0].addr));
        vm.stopPrank();
        
        murky = new Merkle();
        bytes32[] memory leaves = new bytes32[](10);
        for (uint256 i = 0; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked(signers[10 + i].addr));
        }
        bytes32 root = murky.getRoot(leaves);
        
        vm.prank(address(mockMultiSig));
        mimimiCat.setWhiteList(root);
        
        vm.prank(signers[0].addr);
        mimimiCat.setState(2);
        
        handler = new MimimiCatHandler(mimimiCat, signers);
        
        for (uint256 i = 0; i < 10; i++) {
            bytes32[] memory proof = murky.getProof(leaves, i);
            handler.setWhitelistProof(signers[10 + i].addr, proof);
        }
        
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = MimimiCatHandler.mint.selector;
        selectors[1] = MimimiCatHandler.freeMint.selector;
        
        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: selectors
        }));
        
        targetContract(address(handler));
    }
    
    function invariant_totalMintsNeverExceedsMaxSupply() public view {
        uint256 totalMints = handler.ghost_paidMints() + handler.ghost_freeMints();
        assertLe(totalMints, MAX_SUPPLY, "Total mints exceeded MAX_SUPPLY");
    }
    
    function invariant_whitelistPoolReserved() public view {
        uint256 paidMints = handler.ghost_paidMints();
        uint256 freeMints = handler.ghost_freeMints();
        
        assertLe(paidMints, MAX_SUPPLY - WHITELIST_SUPPLY, "Paid mints exceeded reserved pool");
        assertLe(freeMints, WHITELIST_SUPPLY, "Free mints exceeded whitelist pool");
        assertLe(paidMints + freeMints, MAX_SUPPLY, "Total mints exceeded MAX_SUPPLY");
    }
    
    function invariant_balanceMatchesPaidMints() public view {
        uint256 expectedBalance = handler.ghost_paidMints() * MINT_PRICE;
        assertEq(address(mimimiCat).balance, expectedBalance, "Balance mismatch");
    }
    
    function invariant_callSummary() public view {
        console.log("---");
        console.log("Paid mints:", handler.ghost_paidMints());
        console.log("Free mints:", handler.ghost_freeMints());
        console.log("Balance:", address(mimimiCat).balance);
    }
    
    function _toArray(address addr) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = addr;
        return arr;
    }
}