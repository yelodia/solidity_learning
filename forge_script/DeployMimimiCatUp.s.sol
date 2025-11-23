// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {MimimiCatUp} from "../contracts/homework_4/upgradeable/mimimiCatUpgradeable.sol";
import {MimimiCatProxy} from "../contracts/homework_4/upgradeable/mimimiCatProxy.sol";
import {console} from "forge-std/console.sol";

contract DeployMimimiCatUp is Script {
    function run() public {
        uint32 maxSupply = 15;
        uint32 whiteListSupply = 5;
        string memory baseURI = "ipfs://bafkreibsxathnuddsuhgquc3rjaorisrgnv6zolwypnyabrec4ujhnsyly";
        uint256 mintPrice = 0.05 ether;
        address multiSigner = 0x4a8a9BCD144BeAa678686F43CcFad8b666260A26;
        
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_UINT"));
        
        MimimiCatUp implementation = new MimimiCatUp(maxSupply);
        console.log("Implementation:", address(implementation));
        
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint32,string,uint256,address)",
            whiteListSupply,
            baseURI,
            mintPrice,
            multiSigner
        );
        
        MimimiCatProxy proxy = new MimimiCatProxy(address(implementation), initData);
        console.log("Proxy:", address(proxy));
        
        vm.stopBroadcast();
    }
}
