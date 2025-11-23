// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MimimiCatTestBase} from "../MimimiCatTestBase.sol";
import {MimimiCatUp} from "../../../contracts/homework_4/upgradeable/mimimiCatUpgradeable.sol";
import {MimimiCatUpV2} from "../../../contracts/homework_4/upgradeable/mimimiCatUpgradeableV2.sol";
import {MimimiCatProxy} from "../../../contracts/homework_4/upgradeable/mimimiCatProxy.sol";
import {MockMultiSigWallet} from "../helpers/MockMultiSigWallet.sol";

abstract contract MimimiCatUpTestBase is MimimiCatTestBase {
    
    MimimiCatUp public implementation;
    MimimiCatUpV2 public implementationV2;
    MimimiCatProxy public proxy;
    MimimiCatUp public proxyContract;
    MockMultiSigWallet public mockMultiSig;
    
    function deployContracts() public override {
        vm.startPrank(owner.addr);
        
        mockMultiSig = new MockMultiSigWallet();
        
        implementation = new MimimiCatUp(MAX_SUPPLY);
        implementationV2 = new MimimiCatUpV2(MAX_SUPPLY);
        
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint32,string,uint256,address)",
            WHITELIST_SUPPLY,
            BASE_URI,
            MINT_PRICE,
            address(mockMultiSig)
        );
        
        proxy = new MimimiCatProxy(address(implementation), initData);
        proxyContract = MimimiCatUp(address(proxy));
        
        vm.stopPrank();
    }
    
    function _targetContract() internal view override returns (address) {
        return address(proxy);
    }
    
    function setUp() public virtual override {
        super.setUp();
        
        vm.startPrank(owner.addr);
        proxyContract.addStakeHolders(_toArray(abi.encode(signers[1].addr, signers[2].addr)));
        proxyContract.addModerators(_toArray(abi.encode(signers[8].addr, signers[9].addr, signers[10].addr)));
        vm.stopPrank();
    }
}
