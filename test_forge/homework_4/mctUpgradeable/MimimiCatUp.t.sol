// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MimimiCatUpTestBase} from "./MimimiCatUpTestBase.sol";

contract InitializationTest is MimimiCatUpTestBase {
    
    function test_CorrectlyConstructsNft() public view {
        assertEq(proxyContract.owner(), owner.addr);
        assertEq(proxyContract.MAX_SUPPLY(), MAX_SUPPLY);
        assertEq(proxyContract.mintPrice(), MINT_PRICE);
        assertEq(proxyContract.name(), "MimimiCat");
        assertEq(proxyContract.state(), STATE_PAUSE);
        assertEq(proxy.getImplementation(), address(implementation));
    }
    
    function testRevert_ReInitialization() public {
        vm.expectRevert();
        proxyContract.initialize(10, "ipfs://new_metadata/", 0.05 ether, address(mockMultiSig));
    }
}

contract AccessControlTest is MimimiCatUpTestBase {
    
    function testRevert_NonStakeholderCannotSetMintPrice() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                signers[5].addr,
                keccak256("ROLE_STAKEHOLDER")
            )
        );
        vm.prank(signers[5].addr);
        proxyContract.setMintPrice(0.1 ether);
    }
    
    function test_StakeholderCanSetMintPrice() public {
        vm.prank(signers[1].addr);
        proxyContract.setMintPrice(0.1 ether);
        assertEq(proxyContract.mintPrice(), 0.1 ether);
    }
    
    function testRevert_NonMultiwalletCannotSetWhiteList() public {
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", signers[5].addr)
        );
        vm.prank(signers[5].addr);
        proxyContract.setWhiteList(whitelistRoot);
    }
    
    function test_MultiwalletCanSetWhitelist() public {
        bytes memory data = abi.encodeWithSignature("setWhiteList(bytes32)", whitelistRoot);
        
        vm.prank(address(mockMultiSig));
        mockMultiSig.executeCall(address(proxy), data);
        
        assertEq(proxyContract.whiteList(), whitelistRoot);
        assertTrue(proxyContract.inWhiteList(signers[31].addr, getProof(signers[31].addr)));
    }
    
    function testRevert_NonModeratorCannotSetBlackList() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                signers[5].addr,
                keccak256("ROLE_MODERATOR")
            )
        );
        vm.prank(signers[5].addr);
        proxyContract.setToBlackList(signers[19].addr, true);
    }
    
    function test_ModeratorCanSetBlackList() public {
        vm.prank(signers[10].addr);
        proxyContract.setToBlackList(signers[19].addr, true);
        assertTrue(proxyContract.blackList(signers[19].addr));
    }
    
    function testRevert_NonOwnerCannotUpgrade() public {
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", signers[5].addr)
        );
        vm.prank(signers[5].addr);
        proxyContract.changeImplementation(address(implementationV2), "1.0.1");
    }
}

contract PermissionsTest is MimimiCatUpTestBase {
    
    function test_SignedMintWithValidSignature() public {
        vm.prank(signers[8].addr);
        proxyContract.setState(STATE_OPEN);
        
        (uint8 v, bytes32 r, bytes32 s) = sigHelper.signMint(
            signers[20].privateKey,
            proxyContract.nonces(signers[20].addr)
        );
        
        vm.prank(signers[21].addr);
        proxyContract.signedMint{value: MINT_PRICE}(signers[20].addr, v, r, s);
        
        assertEq(proxyContract.ownerOf(1), signers[20].addr);
        
        vm.expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        vm.prank(signers[20].addr);
        proxyContract.signedMint{value: MINT_PRICE}(signers[20].addr, v, r, s);
        
        assertEq(address(proxy).balance, MINT_PRICE);
    }
}

contract UpgradeTest is MimimiCatUpTestBase {
    
    function setUp() public override {
        super.setUp();
        
        vm.prank(signers[1].addr);
        proxyContract.setMintPrice(2.5 ether);
        
        vm.prank(signers[8].addr);
        proxyContract.setState(STATE_OPEN);
        
        vm.prank(signers[19].addr);
        proxyContract.mint{value: 2.5 ether}();
        
        vm.prank(owner.addr);
        proxyContract.changeImplementation(address(implementationV2), "1.0.1");
    }
    
    function test_StoragePreserved() public view {
        assertEq(proxy.getImplementation(), address(implementationV2));
        assertEq(proxyContract.ownerOf(1), signers[19].addr);
        assertEq(address(proxy).balance, 2.5 ether);
        assertEq(proxyContract.version(), "1.0.1");
        assertEq(proxyContract.mintPrice(), 2.5 ether);
    }
    
    function testRevert_MultiwalletCannotSetWhiteList() public {
        bytes memory data = abi.encodeWithSignature("setWhiteList(bytes32)", whitelistRoot);
        
        vm.expectRevert();
        vm.prank(address(mockMultiSig));
        mockMultiSig.executeCall(address(proxy), data);
    }
    
    function test_OwnerCanSetWhiteList() public {
        vm.prank(owner.addr);
        proxyContract.setWhiteList(whitelistRoot);
        
        assertEq(proxyContract.whiteList(), whitelistRoot);
    }
    
    function test_AwardIsCorrect() public {
        (uint8 v, bytes32 r, bytes32 s) = sigHelper.signClose(
            owner.privateKey, 
            AWESOME_URI,
            "1.0.1"
        );
        
        vm.prank(signers[21].addr);
        proxyContract.signedClose(AWESOME_URI, v, r, s);
        
        assertEq(proxyContract.tokenURI(1), string.concat(AWESOME_URI, "1"));
        assertEq(address(proxy).balance, 0.5 ether);
    }
    
    function test_NewDomainSeparatorWorks() public {
        (uint8 v, bytes32 r, bytes32 s) = sigHelper.signMint(
            signers[20].privateKey,
            proxyContract.nonces(signers[20].addr),
            "1.0.1"
        );
        
        vm.prank(signers[21].addr);
        proxyContract.signedMint{value: 2.5 ether}(signers[20].addr, v, r, s);
        
        assertEq(proxyContract.ownerOf(2), signers[20].addr);
    }
    
    function testRevert_ReInitializationStillDisabled() public {
        vm.expectRevert();
        proxyContract.initialize(10, "ipfs://new_metadata/", 0.05 ether, address(mockMultiSig));
    }
}
