// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { BridgeableToken } from "../contracts/homework_6/BridgeableToken.sol";
import { Bridge } from "../contracts/homework_6/Bridge.sol";

contract DeployBridgeAmoy is Script {
    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_UINT");

        vm.startBroadcast(deployerKey);

        BridgeableToken token = new BridgeableToken("Bridgeable yel", "YEL", 10_000 ether);
        // Удалённая цепь для release: BSC Testnet (chainId 97)
        Bridge bridge = new Bridge(address(token), 97);
        token.setBridge(address(bridge));

        vm.stopBroadcast();
    }
}
