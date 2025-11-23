// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MimimiCatTestBase} from "../../MimimiCatTestBase.sol";
import {MimimiCat} from "../../../../contracts/homework_4/mimimiCat.sol";
import {MultiSigHelper} from "../../helpers/MultiSigHelper.sol";

contract MimimiCatIntegrationTestBase is MimimiCatTestBase, MultiSigHelper {

    address public moderator;
    address public stakeholder;

    function deployContracts() public override {
        address[] memory owners = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            owners[i] = signers[i].addr;
        }
        _deployMultiSig(owners);
        
        vm.prank(owner.addr);
        mimimiCat = new MimimiCat(
            MAX_SUPPLY,
            WHITELIST_SUPPLY,
            BASE_URI,
            MINT_PRICE,
            address(multiSig)
        );
    }

    function _targetContract() internal view override returns (address) {
        return address(mimimiCat);
    }

    function setUp() public virtual override {
        super.setUp();
        moderator = signers[5].addr;
        stakeholder = signers[6].addr;
        vm.startPrank(owner.addr);
        mimimiCat.addModerators(_toArray(moderator));
        mimimiCat.addStakeHolders(_toArray(stakeholder));
        vm.stopPrank();
    }
}