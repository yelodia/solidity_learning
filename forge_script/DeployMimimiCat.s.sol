// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {MimimiCat} from "../contracts/homework_4/mimimiCat.sol";
import {console} from "forge-std/console.sol";

contract DeployMimimiCat is Script {
    function run() public {
        uint32 maxSupply = 1000;
        uint32 whiteListSupply = 100;
        string memory baseURI = "ipfs://bafkreibsxathnuddsuhgquc3rjaorisrgnv6zolwypnyabrec4ujhnsyly";
        uint256 mintPrice = 0.01 ether;
        address multiSigner = 0x4a8a9BCD144BeAa678686F43CcFad8b666260A26;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY_UINT"));

        MimimiCat mimimiCat = new MimimiCat(maxSupply, whiteListSupply, baseURI, mintPrice, multiSigner);
        console.log("MimimiCat:", address(mimimiCat));

        vm.stopBroadcast();
    }
}
