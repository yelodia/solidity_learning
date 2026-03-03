pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { BridgeableToken } from "../../contracts/homework_6/BridgeableToken.sol";
import { Bridge } from "../../contracts/homework_6/Bridge.sol";
import { Accounts } from "../helpers/Accounts.sol";

abstract contract BridgeTestBase is Test, Accounts {
    using stdStorage for StdStorage;

    BridgeableToken public token;
    Bridge public bridge;

    uint64 internal constant REMOTE_CHAIN_ID = 97;
    uint256 internal constant INITIAL_SUPPLY = 10_000 ether;

    function setUp() public virtual {
        createSigners(5);
        deployContracts();
        token.setBridge(address(bridge));
        token.transfer(signers[1].addr, 1000 ether);
    }

    function deployContracts() internal virtual {
        token = new BridgeableToken("Bridgeable yel", "YEL", INITIAL_SUPPLY);
        bridge = new Bridge(address(token), REMOTE_CHAIN_ID);
    }

    modifier withProcessed(uint64 originChainId, uint64 nonce) {
        bytes32 id = keccak256(abi.encodePacked(originChainId, nonce));
        stdstore
            .target(address(bridge))
            .sig("processed(bytes32)")
            .with_key(id)
            .checked_write(true);
        _;
    }
}
