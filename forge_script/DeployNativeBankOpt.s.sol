// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {NativeBankOpt} from "../contracts/homework_3/NativeBankOpt.sol";

contract DeployNativeBankOpt is Script {
    function run() public {
        
        address[3] memory holders = [0x4a8a9BCD144BeAa678686F43CcFad8b666260A26, 0x4a8a9BCD144BeAa678686F43CcFad8b666260A26, 0x4a8a9BCD144BeAa678686F43CcFad8b666260A26];

        vm.startBroadcast(vm.envUint("PRIVATE_KEY_UINT"));
        NativeBankOpt bank = new NativeBankOpt(holders);
        vm.stopBroadcast();

    }
}

