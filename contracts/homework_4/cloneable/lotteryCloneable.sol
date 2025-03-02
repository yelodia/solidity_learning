// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { LotteryInitializeable } from "../initializeable/lotteryInitializeable.sol";


contract LotteryCloneable is LotteryInitializeable {

    constructor(uint32 _maxSupply) LotteryInitializeable(_maxSupply) payable {}

    function initialize(uint32 _whiteListSupply, string memory _uri, uint256 _mintPrice, address _signer, string memory _name, string memory _symbol, address _owner) public initializer {
        lotteryInit(_whiteListSupply, _uri, _mintPrice, _signer, _name, _symbol, "1.0.0", _owner);
    }

}
