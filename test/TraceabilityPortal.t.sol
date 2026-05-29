// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {EquipmentNFT} from "../src/EquipmentNFT.sol";
import {ProcessNFT} from "../src/ProcessNFT.sol";
import {ProductNFT} from "../src/ProductNFT.sol";
import {ManpowerNFT} from "../src/ManpowerNFT.sol";
import {QualityNFT} from "../src/QualityNFT.sol";
import {MaintenanceNFT} from "../src/MaintenanceNFT.sol";
import {BusinessNFT} from "../src/BusinessNFT.sol";
import {TraceabilityPortal} from "../src/TraceabilityPortal.sol";

contract TraceabilityPortalTest is Test {
    EquipmentNFT public equipmentNFT;
    ProcessNFT public processNFT;
    ProductNFT public productNFT;
    ManpowerNFT public manpowerNFT;
    QualityNFT public qualityNFT;
    MaintenanceNFT public maintenanceNFT;
    BusinessNFT public businessNFT;
    TraceabilityPortal public portal;

    address admin = address(0xA1);
    address foundry = address(0xA2);
    address oem = address(0xA3);
    address supervisor = address(0xA4);
    address inspector = address(0xA5);
    address commercial = address(0xA6);
    address stranger = address(0xA7);

    function setUp() public {
        vm.startPrank(admin);

        equipmentNFT = new EquipmentNFT();
        manpowerNFT = new ManpowerNFT();
        processNFT = new ProcessNFT(address(equipmentNFT), address(manpowerNFT));
        productNFT = new ProductNFT(address(processNFT));
        qualityNFT = new QualityNFT(address(productNFT));
        maintenanceNFT = new MaintenanceNFT(address(equipmentNFT));
        businessNFT = new BusinessNFT(address(productNFT));

        portal = new TraceabilityPortal(
            address(equipmentNFT),
            address(processNFT),
            address(productNFT),
            address(manpowerNFT),
            address(qualityNFT),
            address(maintenanceNFT),
            address(businessNFT)
        );

        // Grant Roles on portal
        portal.grantRole(portal.FOUNDRY_ROLE(), foundry);
        portal.grantRole(portal.OEM_ROLE(), oem);
        portal.grantRole(portal.SUPERVISOR_ROLE(), supervisor);
        portal.grantRole(portal.INSPECTOR_ROLE(), inspector);
        portal.grantRole(portal.COMMERCIAL_ROLE(), commercial);

        // Grant Roles to portal on target contracts so portal can mint
        equipmentNFT.grantRole(equipmentNFT.FOUNDRY_ROLE(), address(portal));
        manpowerNFT.grantRole(manpowerNFT.SUPERVISOR_ROLE(), address(portal));
        processNFT.grantRole(processNFT.FOUNDRY_ROLE(), address(portal));
        productNFT.grantRole(productNFT.OEM_ROLE(), address(portal));
        qualityNFT.grantRole(qualityNFT.INSPECTOR_ROLE(), address(portal));
        maintenanceNFT.grantRole(maintenanceNFT.INSPECTOR_ROLE(), address(portal));
        businessNFT.grantRole(businessNFT.COMMERCIAL_ROLE(), address(portal));

        vm.stopPrank();
    }

    function test_PortalMintEquipment_Authorized() public {
        vm.prank(foundry);
        EquipmentNFT.EquipmentData memory data = EquipmentNFT.EquipmentData({
            machineId: "EQ-001",
            machineType: "Furnace",
            manufacturer: "OEM-Corp",
            modelNumber: "Mod-X",
            serialNumber: "SN-12345",
            installationDate: block.timestamp,
            calibrationStatus: "Valid",
            maintenanceHash: "ipfs://maint-hash",
            location: "Bay 2"
        });

        uint256 tokenId = portal.mintEquipment(foundry, data, "ipfs://eq-uri");
        assertEq(tokenId, 1);
        assertTrue(equipmentNFT.exists(tokenId));

        EquipmentNFT.EquipmentData memory saved = equipmentNFT.getEquipment(tokenId);
        assertEq(saved.machineId, "EQ-001");
    }

    function test_PortalMintEquipment_UnauthorizedReverts() public {
        vm.prank(stranger);
        EquipmentNFT.EquipmentData memory data;
        vm.expectRevert("Only FOUNDRY or ADMIN");
        portal.mintEquipment(stranger, data, "ipfs://eq-uri");
    }

    function test_PortalMintProcess_ValidationCheck() public {
        // Mint equipment & manpower first
        vm.prank(foundry);
        EquipmentNFT.EquipmentData memory eqData;
        uint256 eqId = portal.mintEquipment(foundry, eqData, "ipfs://eq-uri");

        vm.prank(supervisor);
        TraceabilityPortal.ManpowerDataCalldata memory mpData = TraceabilityPortal.ManpowerDataCalldata({
            operatorId: "OP-01",
            shift: "Night",
            skillCategory: "Melting",
            trainingCert: "Yes",
            digitalSignature: "0xSig"
        });
        uint256 mpId = portal.mintManpower(foundry, mpData, "ipfs://mp-uri");

        // Mint process linked to both
        vm.prank(foundry);
        ProcessNFT.ProcessData memory prData = ProcessNFT.ProcessData({
            heatNo: "H-502",
            viscosityPri: 100,
            viscosityBack: 99,
            densityPri: 50,
            densityBack: 49,
            waxTemp: 60,
            injectionPressure: 10,
            injectionTime: 15,
            pouringTemp: 1400,
            preheatingTemp: 900,
            pouringSpeed: 5,
            humidity: 20,
            roomTemp: 22,
            processDuration: 300,
            equipmentId: eqId,
            manpowerId: mpId
        });

        uint256 prId = portal.mintProcess(foundry, prData, "ipfs://pr-uri");
        assertEq(prId, 1);

        ProcessNFT.ProcessData memory saved = processNFT.getProcess(prId);
        assertEq(saved.heatNo, "H-502");
        assertEq(saved.equipmentId, eqId);
        assertEq(saved.manpowerId, mpId);
    }

    function test_PortalMintProcess_InvalidLinkReverts() public {
        vm.prank(foundry);
        ProcessNFT.ProcessData memory prData;
        prData.equipmentId = 99; // Non-existent equipment

        vm.expectRevert("Linked Equipment does not exist");
        portal.mintProcess(foundry, prData, "ipfs://pr-uri");
    }

    function test_PortalFullPassportResolution() public {
        // 1. Mint Equipment
        vm.prank(foundry);
        EquipmentNFT.EquipmentData memory eqData = EquipmentNFT.EquipmentData({
            machineId: "EQ-01",
            machineType: "Press",
            manufacturer: "A",
            modelNumber: "B",
            serialNumber: "C",
            installationDate: 12345,
            calibrationStatus: "OK",
            maintenanceHash: "hash",
            location: "Room 1"
        });
        uint256 eqId = portal.mintEquipment(foundry, eqData, "uri");

        // 2. Mint Manpower
        vm.prank(supervisor);
        TraceabilityPortal.ManpowerDataCalldata memory mpData = TraceabilityPortal.ManpowerDataCalldata({
            operatorId: "OP-42", shift: "Day", skillCategory: "Pressing", trainingCert: "Cert", digitalSignature: "Sig"
        });
        uint256 mpId = portal.mintManpower(foundry, mpData, "uri");

        // 3. Mint Process
        vm.prank(foundry);
        ProcessNFT.ProcessData memory prData;
        prData.heatNo = "H-001";
        prData.equipmentId = eqId;
        prData.manpowerId = mpId;
        uint256 prId = portal.mintProcess(foundry, prData, "uri");

        // 4. Mint Product
        vm.prank(oem);
        ProductNFT.ProductData memory prodData = ProductNFT.ProductData({
            partName: "Blade-V1", alloyGrade: "Titanium", castingId: "CAST-7", processId: prId, dppHash: "ipfs://dpp"
        });
        uint256 prodId = portal.mintProduct(oem, prodData, "uri");

        // 5. Mint Quality
        vm.prank(inspector);
        QualityNFT.QualityData memory qData;
        qData.qualityScore = 98;
        qData.defectPrediction = "None";
        qData.productId = prodId;
        portal.mintQuality(inspector, qData, "uri");

        // 6. Mint Maintenance
        vm.prank(inspector);
        MaintenanceNFT.MaintenanceData memory maintData;
        maintData.preventiveMaintenance = "Check gears";
        maintData.equipmentId = eqId;
        portal.mintMaintenance(inspector, maintData, "uri");

        // 7. Mint Business
        vm.prank(commercial);
        BusinessNFT.BusinessData memory bizData;
        bizData.customerOrder = "PO-777";
        bizData.productId = prodId;
        portal.mintBusiness(commercial, bizData, "uri");

        // Resolve Full Passport
        TraceabilityPortal.FullPassport memory passport = portal.getFullPassport(prodId);
        assertTrue(passport.exists);
        assertEq(passport.product.partName, "Blade-V1");
        assertEq(passport.process.heatNo, "H-001");
        assertEq(passport.equipment.machineId, "EQ-01");
        assertEq(passport.manpower.operatorId, "OP-42");

        assertEq(passport.qualityRecords.length, 1);
        assertEq(passport.qualityRecords[0].qualityScore, 98);

        assertEq(passport.maintenanceRecords.length, 1);
        assertEq(passport.maintenanceRecords[0].preventiveMaintenance, "Check gears");

        assertEq(passport.businessRecords.length, 1);
        assertEq(passport.businessRecords[0].customerOrder, "PO-777");
    }
}
