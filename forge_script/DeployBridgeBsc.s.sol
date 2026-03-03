// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { BridgeableToken } from "../contracts/homework_6/BridgeableToken.sol";
import { Bridge } from "../contracts/homework_6/Bridge.sol";

contract DeployBridgeBsc is Script {
    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_UINT");

        vm.startBroadcast(deployerKey);

        BridgeableToken token = new BridgeableToken("Bridgeable yel", "YEL", 0);
        // Удалённая цепь для release: Polygon Amoy (chainId 80002)
        Bridge bridge = new Bridge(address(token), 80002);
        token.setBridge(address(bridge));

        vm.stopBroadcast();
    }
}
