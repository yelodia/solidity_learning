// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { LotteryInitializeable } from "../initializeable/lotteryInitializeable.sol";


contract MimimiCatUp is LotteryInitializeable {

    bytes32 public constant MIMIMICAT_STORAGE = 0x3e596b5924e4cbd652ac0c0844961e3c6d4e09860b46e84c2417e0039c826860;

    error ZeroAddress();
    event ImplementationUpdated(address indexed implementation);


    constructor(uint32 _maxSupply) LotteryInitializeable(_maxSupply) payable {}

    function initialize(uint32 _whiteListSupply, string memory _uri, uint256 _mintPrice, address _signer) public initializer {
        lotteryInit(_whiteListSupply, _uri, _mintPrice, _signer, "MimimiCat", "MCT", "1.0.0", msg.sender);
    }

    function changeImplementation(address newImplementation, string memory _version) external onlyOwner {

        // Check for zero address
        if (newImplementation == address(0)) {
            revert ZeroAddress();
        }

        assembly {
            sstore(MIMIMICAT_STORAGE, newImplementation)
        }

        // это было бы не нужно, если бы для удобства не было сделано наследование от LotteryInitializeable. Тогда бы в контракту permissions VERSION было бы константой, а в апгрейде просто бы изменили в коде ее значение
        permissionsInit(name(), _version);

        emit ImplementationUpdated(newImplementation);
    }

}
