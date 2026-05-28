// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {ManufacturingDPP} from "../src/ManufacturingDPP.sol";

contract Deploy is Script {
    function run() external returns (ManufacturingDPP dpp) {
        vm.startBroadcast();

        dpp = new ManufacturingDPP();

        console.log("ManufacturingDPP deployed at:", address(dpp));
        console.log("Deployer (ADMIN_ROLE)        :", msg.sender);

        vm.stopBroadcast();
    }
}
