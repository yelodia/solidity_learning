// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CloneFactory} from "./cloneFactory.sol";
import {LotteryCloneable} from "./lotteryCloneable.sol";


contract LotteryFactory is CloneFactory{
    LotteryCloneable[] public itemAddresses;
    event ItemCreated(LotteryCloneable item);

    address public libraryAddress;

    constructor() {
        // по логике для cloneable лотереи не надо, чтобы maxSupply был immutable, его тоже должны задавать пользователи. Здесь сделано для эксперимента.
        libraryAddress = address(new LotteryCloneable(5000));
    }

    function createItem(uint32 _whiteListSupply, string memory _uri, uint256 _mintPrice, address _signer, string memory _name, string memory _symbol) external {
        LotteryCloneable item = LotteryCloneable(
            createClone(libraryAddress)
        );
        item.initialize(_whiteListSupply, _uri, _mintPrice, _signer, _name, _symbol, msg.sender);

        itemAddresses.push(item);
        emit ItemCreated(item);
    }

    function getItems() external view returns (LotteryCloneable[] memory) {
        return itemAddresses;
    }
}
