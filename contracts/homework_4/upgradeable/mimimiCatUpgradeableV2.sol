// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { MimimiCatUp } from "./mimimiCatUpgradeable.sol";

contract MimimiCatUpV2 is MimimiCatUp {

    constructor(uint32 _maxSupply) MimimiCatUp(_maxSupply) payable {}

    function setWhiteList(bytes32 _whiteList) external override onlyOwner {
        whiteList = _whiteList;
    }

}
