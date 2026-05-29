// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {EquipmentNFT} from "../src/EquipmentNFT.sol";
import {ProcessNFT} from "../src/ProcessNFT.sol";
import {ProductNFT} from "../src/ProductNFT.sol";
import {ManpowerNFT} from "../src/ManpowerNFT.sol";
import {QualityNFT} from "../src/QualityNFT.sol";
import {MaintenanceNFT} from "../src/MaintenanceNFT.sol";
import {BusinessNFT} from "../src/BusinessNFT.sol";
import {TraceabilityPortal} from "../src/TraceabilityPortal.sol";

contract DeployV3 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));

        if (deployerPrivateKey != 0) {
            vm.startBroadcast(deployerPrivateKey);
        } else {
            vm.startBroadcast();
        }

        // 1. Deploy the 7 separate NFT contracts
        EquipmentNFT equipment = new EquipmentNFT();
        ManpowerNFT manpower = new ManpowerNFT();
        ProcessNFT process = new ProcessNFT(address(equipment), address(manpower));
        ProductNFT product = new ProductNFT(address(process));
        QualityNFT quality = new QualityNFT(address(product));
        MaintenanceNFT maintenance = new MaintenanceNFT(address(equipment));
        BusinessNFT business = new BusinessNFT(address(product));

        // 2. Deploy TraceabilityPortal coordinator
        TraceabilityPortal portal = new TraceabilityPortal(
            address(equipment),
            address(process),
            address(product),
            address(manpower),
            address(quality),
            address(maintenance),
            address(business)
        );

        // 3. Grant minter roles to the portal contract on the separate NFTs
        equipment.grantRole(equipment.FOUNDRY_ROLE(), address(portal));
        manpower.grantRole(manpower.SUPERVISOR_ROLE(), address(portal));
        process.grantRole(process.FOUNDRY_ROLE(), address(portal));
        product.grantRole(product.OEM_ROLE(), address(portal));
        quality.grantRole(quality.INSPECTOR_ROLE(), address(portal));
        maintenance.grantRole(maintenance.INSPECTOR_ROLE(), address(portal));
        business.grantRole(business.COMMERCIAL_ROLE(), address(portal));

        console.log("=== DEPLOYMENT SUCCESSFUL ===");
        console.log("EquipmentNFT deployed at      :", address(equipment));
        console.log("ManpowerNFT deployed at       :", address(manpower));
        console.log("ProcessNFT deployed at        :", address(process));
        console.log("ProductNFT deployed at        :", address(product));
        console.log("QualityNFT deployed at        :", address(quality));
        console.log("MaintenanceNFT deployed at    :", address(maintenance));
        console.log("BusinessNFT deployed at       :", address(business));
        console.log("TraceabilityPortal deployed at:", address(portal));

        vm.stopBroadcast();
    }
}
