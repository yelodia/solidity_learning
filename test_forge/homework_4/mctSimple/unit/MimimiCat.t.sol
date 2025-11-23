// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MimimiCatUnitTestBase} from "./MimimiCatUnitTestBase.sol";
import {console} from "forge-std/Test.sol";

contract InitializationTest is MimimiCatUnitTestBase {
    
    function test_CorrectlyConstructsNft() public view {
        assertEq(mimimiCat.owner(), owner.addr);
        assertEq(mimimiCat.MAX_SUPPLY(), MAX_SUPPLY);
        assertEq(mimimiCat.mintPrice(), MINT_PRICE);
        assertEq(mimimiCat.name(), "MimimiCat");
        assertEq(mimimiCat.symbol(), "MCT");
        assertEq(mimimiCat.state(), STATE_PAUSE);
        assertEq(mimimiCat.multiSigner(), address(mockMultiSig));
    }
}

contract AddStakeholdersTest is MimimiCatUnitTestBase {
    
    function testRevert_notOwner() public {
        vm.prank(signers[10].addr);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", signers[10].addr));
        mimimiCat.addStakeHolders(_toArray(signers[8].addr));
    }
    
    function test_success() public {
        vm.prank(owner.addr);
        mimimiCat.addStakeHolders( _toArray(abi.encode(signers[8].addr, signers[9].addr)) );
        assertTrue(mimimiCat.hasRole(ROLE_STAKEHOLDER, signers[8].addr));
        assertTrue(mimimiCat.hasRole(ROLE_STAKEHOLDER, signers[9].addr));
    }
}


contract AddModeratorsTest is MimimiCatUnitTestBase {
    
    function testRevert_notOwner() public {
        vm.prank(signers[1].addr);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", signers[1].addr));
        mimimiCat.addModerators(_toArray(signers[5].addr));
    }
    
    function test_success() public {
        vm.prank(owner.addr);
        mimimiCat.addModerators(_toArray(abi.encode(signers[5].addr, signers[6].addr, signers[7].addr)));
        assertTrue(mimimiCat.hasRole(ROLE_MODERATOR, signers[5].addr));
        assertTrue(mimimiCat.hasRole(ROLE_MODERATOR, signers[6].addr));
        assertTrue(mimimiCat.hasRole(ROLE_MODERATOR, signers[7].addr));
    }
}


contract SetMintPriceTest is MimimiCatUnitTestBase {
    
    function testRevert_notStakeholder() public {
        vm.prank(signers[7].addr);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", 
                signers[7].addr, 
                ROLE_STAKEHOLDER
            )
        );
        mimimiCat.setMintPrice(0.1 ether);
    }
    
    function test_success() public withStakeholder(signers[8].addr) {
        vm.prank(signers[8].addr);
        mimimiCat.setMintPrice(0.1 ether);
        
        assertEq(mimimiCat.mintPrice(), 0.1 ether);
    }
}


contract SetToBlackListTest is MimimiCatUnitTestBase {
    
    function testRevert_notModerator() public {
        vm.prank(signers[1].addr);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", 
                signers[1].addr, 
                ROLE_MODERATOR
            )
        );
        mimimiCat.setToBlackList(signers[10].addr, true);
    }
    
    function test_success() public withModerator(signers[5].addr) {
        vm.startPrank(signers[5].addr);

        mimimiCat.setToBlackList(signers[11].addr, true);
        mimimiCat.setToBlackList(signers[12].addr, true);
        assertTrue(mimimiCat.blackList(signers[11].addr));
        assertTrue(mimimiCat.blackList(signers[12].addr));

        mimimiCat.setToBlackList(signers[12].addr, false);
        assertTrue(mimimiCat.blackList(signers[11].addr));
        assertFalse(mimimiCat.blackList(signers[12].addr));
    }

}

contract SetWhiteListTest is MimimiCatUnitTestBase {
    
    function testRevert_notMultisigner() public {
        vm.prank(signers[12].addr);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", signers[12].addr));
        mimimiCat.setWhiteList(whitelistRoot);
    }
    
    function test_success() public {
        vm.prank(address(mockMultiSig));
        mimimiCat.setWhiteList(whitelistRoot);
        
        assertEq(mimimiCat.whiteList(), whitelistRoot);
        
        assertTrue(mimimiCat.inWhiteList(signers[31].addr, getProof(signers[31].addr) ));
        assertTrue(mimimiCat.inWhiteList(signers[32].addr, getProof(signers[32].addr) ));
        assertFalse(mimimiCat.inWhiteList(signers[2].addr, getProof(signers[2].addr)));
    }
    
}

contract SignedCloseTest is MimimiCatUnitTestBase {
    function testRevert_invalidUri() public {
        (uint8 v, bytes32 r, bytes32 s) = sigHelper.signClose(owner.privateKey, AWESOME_URI);
        
        vm.prank(signers[15].addr);
        vm.expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        mimimiCat.signedClose(INVALID_URI, v, r, s);
    }

    function testRevert_wrongSigner() public {
        (uint8 v, bytes32 r, bytes32 s) = sigHelper.signClose(signers[15].privateKey, AWESOME_URI);
        
        vm.prank(signers[15].addr);
        vm.expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        mimimiCat.signedClose(AWESOME_URI, v, r, s);
    }

    function test_success() public withMintPrice(2.5 ether) withMintToken(signers[20].addr) {
        (uint8 v, bytes32 r, bytes32 s) = sigHelper.signClose(owner.privateKey, AWESOME_URI);
        address caller = signers[15].addr;
        uint256 callerBalanceBefore = caller.balance;
    
        vm.prank(caller);
        mimimiCat.signedClose(AWESOME_URI, v, r, s);
        
        assertEq(mimimiCat.state(), STATE_CLOSE);
        assertEq(mimimiCat.tokenURI(1), string.concat(AWESOME_URI, "1"));
        
        assertEq(caller.balance, callerBalanceBefore + 2 ether);
        assertEq(address(mimimiCat).balance, 0.5 ether);

        // reply attack
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("MCTAlreadyClosed()"));
        mimimiCat.signedClose(AWESOME_URI, v, r, s);
    }
}

contract CloseTest is MimimiCatUnitTestBase {
    function testRevert_notMultisigner() public {
        vm.prank(signers[12].addr);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", signers[12].addr));
        mimimiCat.close(REVEALED_URI);
    }
    
    function test_success() public withMintToken(signers[20].addr) {
        vm.prank(address(mockMultiSig));
        mimimiCat.close(REVEALED_URI);
        
        assertEq(mimimiCat.state(), STATE_CLOSE);
        assertEq(mimimiCat.tokenURI(1), string.concat(REVEALED_URI, "1"));
    }
}


contract SetStateTest is MimimiCatUnitTestBase {
    function testRevert_notModerator() public {
        vm.prank(signers[1].addr);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", 
                signers[1].addr, 
                ROLE_MODERATOR
            )
        );
        mimimiCat.setState(STATE_OPEN);
    }
    
    function test_success() public withModerator(signers[5].addr) {
        vm.startPrank(signers[5].addr);

        mimimiCat.setState(STATE_OPEN);
        assertEq(mimimiCat.state(), STATE_OPEN);
        mimimiCat.setState(STATE_PAUSE);
        assertEq(mimimiCat.state(), STATE_PAUSE);
    }

    function testRevert_wrongClose() public withModerator(signers[5].addr) {
        vm.startPrank(signers[5].addr);
        vm.expectRevert(
            abi.encodeWithSignature("MCTInvalidTransition()")
        );

        mimimiCat.setState(STATE_CLOSE);
    }

    function testRevert_onReopen() public withModerator(signers[5].addr) withState(STATE_CLOSE) {
        vm.startPrank(signers[5].addr);
        vm.expectRevert(
            abi.encodeWithSignature("MCTInvalidTransition()")
        );

        mimimiCat.setState(STATE_OPEN);
    }
}

contract TokenURITest is MimimiCatUnitTestBase {
    function testRevert_notMinted() public {
        vm.expectRevert(
            abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 1)
        );
        mimimiCat.tokenURI(1);
    }

    function test_invisible() public withMintToken(signers[20].addr) {
        assertEq(mimimiCat.tokenURI(1), BASE_URI);
    }

    function test_visible() public withMintToken(signers[20].addr) withState(STATE_CLOSE) {
        assertEq(mimimiCat.tokenURI(1), string.concat(BASE_URI, "1"));
    }
}

contract MintTest is MimimiCatUnitTestBase {
    function testRevert_onPaused() public {
        vm.expectRevert(
            abi.encodeWithSignature("MCTMintIsNotOpened()")
        );
        vm.prank(signers[5].addr);
        mimimiCat.mint{value: 0.05 ether}();
    }

    function testRevert_onClosed() public withState(STATE_CLOSE) {
        testRevert_onPaused();
    }

    function testRevert_onBlackList() public withState(STATE_OPEN) withBlacklist(signers[20].addr) {
        vm.expectRevert(
            abi.encodeWithSignature("MCTAdddresInBlackList(address)", signers[20].addr)
        );
        vm.prank(signers[20].addr);
        mimimiCat.mint{value: 0.05 ether}();
    }

    function testRevert_onWrongPrice() public withState(STATE_OPEN) {
        vm.expectRevert(
            abi.encodeWithSignature("MCTInvalidEthers(address,uint256,uint256)", signers[20].addr, 0.05 ether, 0.1 ether)
        );
        vm.prank(signers[20].addr);
        mimimiCat.mint{value: 0.1 ether}();
    }

    function test_success() public withState(STATE_OPEN) {
        vm.prank(signers[20].addr);
        mimimiCat.mint{value: 0.05 ether}();
        assertEq(mimimiCat.ownerOf(1), signers[20].addr);
        assertEq(address(mimimiCat).balance, 0.05 ether);
    }
}

contract SignedMintTest is MimimiCatUnitTestBase {
    uint8 v;
    bytes32 r; 
    bytes32 s;
    Signer signer;
    Signer actor;

    function setUp() public override {
        super.setUp();
        signer = signers[5];
        actor = signers[10];
        (v, r, s) = sigHelper.signMint(signer.privateKey, mimimiCat.nonces(signer.addr));
    }

    function testRevert_onPaused() public {
        vm.expectRevert(
            abi.encodeWithSignature("MCTMintIsNotOpened()")
        );
        vm.prank(actor.addr);
        mimimiCat.signedMint{value: 0.05 ether}(signer.addr, v, r, s);
    }

    function testRevert_onClosed() public withState(STATE_CLOSE) {
        testRevert_onPaused();
    }

    function testRevert_onBlackListSigner() public withState(STATE_OPEN) withBlacklist(signer.addr) {
        vm.expectRevert(
            abi.encodeWithSignature("MCTAdddresInBlackList(address)", signer.addr)
        );
        vm.prank(actor.addr);
        mimimiCat.signedMint{value: 0.05 ether}(signer.addr, v, r, s);
    }

    function test_onBlackListActor() public withState(STATE_OPEN) withBlacklist(actor.addr) {
        vm.prank(actor.addr);
        mimimiCat.signedMint{value: 0.05 ether}(signer.addr, v, r, s);
        assertEq(mimimiCat.ownerOf(1), signer.addr);
    }

    function testRevert_onWrongPrice() public withState(STATE_OPEN) {
        vm.expectRevert(
            abi.encodeWithSignature("MCTInvalidEthers(address,uint256,uint256)", signer.addr, 0.05 ether, 0.01 ether)
        );
        vm.prank(actor.addr);
        mimimiCat.signedMint{value: 0.01 ether}(signer.addr, v, r, s);
    }

    function testRevert_onWrongSign() public withState(STATE_OPEN) {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidSignature()")
        );
        vm.prank(actor.addr);
        mimimiCat.signedMint{value: 0.05 ether}(actor.addr, v, r, s);
    }

    function test_success() public withState(STATE_OPEN) {
        vm.startPrank(actor.addr);
        mimimiCat.signedMint{value: 0.05 ether}(signer.addr, v, r, s);
        assertEq(mimimiCat.ownerOf(1), signer.addr);
        assertEq(address(mimimiCat).balance, 0.05 ether);

        // reply attack
        vm.expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        mimimiCat.signedMint{value: 0.05 ether}(signer.addr, v, r, s);
    }
}


contract FreeMintTest is MimimiCatUnitTestBase {
    Signer minter;
    bytes32[] minterProof;

    function setUp() public override {
        super.setUp();
        minter = signers[32];
        vm.prank(address(mockMultiSig));
        mimimiCat.setWhiteList(whitelistRoot);
        minterProof = getProof(minter.addr);
    }

    function testRevert_onPaused() public {
        vm.expectRevert(
            abi.encodeWithSignature("MCTMintIsNotOpened()")
        );
        vm.prank(minter.addr);
        mimimiCat.freeMint(minterProof);
    }

    function testRevert_onClosed() public withState(STATE_CLOSE) {
        testRevert_onPaused();
    }

    function testRevert_notWhiteList() public withState(STATE_OPEN) {
        bytes32[] memory proof = getProof(signers[20].addr);
        vm.expectRevert(
            abi.encodeWithSignature("MCTAdddresNotInWiteList(address)", signers[20].addr)
        );
        vm.prank(signers[20].addr);
        mimimiCat.freeMint(proof);
    }

    function testRevert_wrongProof() public withState(STATE_OPEN) {
        vm.expectRevert(
            abi.encodeWithSignature("MCTAdddresNotInWiteList(address)", signers[33].addr)
        );
        vm.prank(signers[33].addr);
        mimimiCat.freeMint(minterProof);
    }

    function test_success() public withState(STATE_OPEN) {
        vm.startPrank(minter.addr);
        mimimiCat.freeMint(minterProof);
        assertEq(mimimiCat.ownerOf(1), minter.addr);

        // try to reply
        vm.expectRevert(
            abi.encodeWithSignature("MCTAlreadyHasFreeMint(address)", minter.addr)
        );
        mimimiCat.freeMint(minterProof);
    }
}

contract FreeSignedMintTest is MimimiCatUnitTestBase {
    Signer minter;
    bytes32[] minterProof;
    uint8 v;
    bytes32 r; 
    bytes32 s;
    Signer actor;

    function setUp() public override {
        super.setUp();
        minter = signers[32];
        actor = signers[20];
        vm.prank(address(mockMultiSig));
        mimimiCat.setWhiteList(whitelistRoot);
        minterProof = getProof(minter.addr);
        (v, r, s) = sigHelper.signFreeMint(minter.privateKey, minterProof, mimimiCat.nonces(minter.addr));
    }

    function testRevert_onPaused() public {
        vm.expectRevert(
            abi.encodeWithSignature("MCTMintIsNotOpened()")
        );
        vm.prank(actor.addr);
        mimimiCat.signedFreeMint(minter.addr, minterProof, v, r, s);
    }

    function testRevert_onClosed() public withState(STATE_CLOSE) {
        testRevert_onPaused();
    }

    function testRevert_notWhiteList() public withState(STATE_OPEN) {
        bytes32[] memory proof = getProof(signers[10].addr);
        (uint8 _v, bytes32 _r, bytes32 _s) = sigHelper.signFreeMint(signers[10].privateKey, proof, mimimiCat.nonces(signers[10].addr));
        vm.expectRevert(
            abi.encodeWithSignature("MCTAdddresNotInWiteList(address)", signers[10].addr)
        );
        vm.prank(actor.addr);
        mimimiCat.signedFreeMint(signers[10].addr, proof, _v, _r, _s);
    }

    function testRevert_wrongProof() public withState(STATE_OPEN) {
        (uint8 _v, bytes32 _r, bytes32 _s) = sigHelper.signFreeMint(signers[33].privateKey, minterProof, mimimiCat.nonces(signers[33].addr));
        vm.expectRevert(
            abi.encodeWithSignature("MCTAdddresNotInWiteList(address)", signers[33].addr)
        );
        vm.prank(actor.addr);
        mimimiCat.signedFreeMint(signers[33].addr, minterProof, _v, _r, _s);
    }

    function testRevert_wrongSignature() public withState(STATE_OPEN) {
        (uint8 _v, bytes32 _r, bytes32 _s) = sigHelper.signFreeMint(actor.privateKey, minterProof, mimimiCat.nonces(actor.addr));
        vm.expectRevert(
            abi.encodeWithSignature("InvalidSignature()")
        );
        vm.prank(actor.addr);
        mimimiCat.signedFreeMint(minter.addr, minterProof, _v, _r, _s);
    }

    function test_success() public withState(STATE_OPEN) {
        vm.startPrank(actor.addr);
        mimimiCat.signedFreeMint(minter.addr, minterProof, v, r, s);
        assertEq(mimimiCat.ownerOf(1), minter.addr);

        // try to reply
        (uint8 _v, bytes32 _r, bytes32 _s) = sigHelper.signFreeMint(minter.privateKey, minterProof, mimimiCat.nonces(minter.addr));
        vm.expectRevert(
            abi.encodeWithSignature("MCTAlreadyHasFreeMint(address)", minter.addr)
        );
        mimimiCat.signedFreeMint(minter.addr, minterProof, _v, _r, _s);
    }

}

contract PermitTest is MimimiCatUnitTestBase {
    uint8 v;
    bytes32 r; 
    bytes32 s;
    Signer permitter;
    Signer actor;

    function setUp() public override {
        super.setUp();
        permitter = signers[10];
        actor = signers[20];
        (v, r, s) = sigHelper.signPermit(permitter.privateKey, actor.addr, 1, mimimiCat.nonces(permitter.addr));
    }

    function testRevert_wrongSignature() public withMintToken(permitter.addr) {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidSignature()")
        );
        vm.prank(signers[5].addr);
        mimimiCat.permit(permitter.addr, signers[5].addr, 1, v, r, s);
    }

    function test_success() public withMintToken(permitter.addr) {
        vm.prank(signers[5].addr);
        mimimiCat.permit(permitter.addr, actor.addr, 1, v, r, s);
        assertEq(mimimiCat.getApproved(1), actor.addr);
    }
}

contract WithdrawTest is MimimiCatUnitTestBase {
    address stakeholder;

    function setUp() public override {
        super.setUp();
        vm.deal(address(mimimiCat), 5 ether);
        stakeholder = signers[1].addr;
        vm.prank(owner.addr);
        mimimiCat.addStakeHolders(_toArray(stakeholder));
    }

    function testRevert_whenPaused() public {
        vm.expectRevert(
            abi.encodeWithSignature("MCTMintIsNotClosed()")
        );
        vm.prank(stakeholder);
        mimimiCat.withdraw(2 ether);
    }

    function testRevert_whenOpened() public withState(STATE_OPEN) {
        testRevert_whenPaused();
    }

    function testRevert_nonStakeholder() public withState(STATE_CLOSE) {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", 
                signers[20].addr, 
                ROLE_STAKEHOLDER
            )
        );
        vm.prank(signers[20].addr);
        mimimiCat.withdraw(2 ether);
    }

    function test_success() public withState(STATE_CLOSE) {
        uint256 balanceBefore = stakeholder.balance;
        vm.prank(stakeholder);
        mimimiCat.withdraw(2 ether);
        
        assertEq(stakeholder.balance, balanceBefore + 2 ether);
        assertEq(address(mimimiCat).balance, 3 ether);
    }
}