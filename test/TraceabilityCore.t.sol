// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {TraceabilityCore} from "../src/TraceabilityCore.sol";

contract TraceabilityCoreTest is Test {
    TraceabilityCore public core;

    address admin = address(0xA1);
    address foundry = address(0xA2);
    address oem = address(0xA3);
    address supervisor = address(0xA4);
    address inspector = address(0xA5);
    address commercial = address(0xA6);
    address stranger = address(0xA7);

    function setUp() public {
        vm.startPrank(admin);
        core = new TraceabilityCore();

        core.grantRole(core.FOUNDRY_ROLE(), foundry);
        core.grantRole(core.OEM_ROLE(), oem);
        core.grantRole(core.SUPERVISOR_ROLE(), supervisor);
        core.grantRole(core.INSPECTOR_ROLE(), inspector);
        core.grantRole(core.COMMERCIAL_ROLE(), commercial);

        vm.stopPrank();
    }

    function test_MintEquipment_Authorized() public {
        vm.prank(foundry);
        TraceabilityCore.EquipmentData memory data = TraceabilityCore.EquipmentData({
            machineId: "EQ-001",
            machineType: "Furnace",
            manufacturer: "Inductotherm",
            modelNumber: "Inducto-V5",
            serialNumber: "SN-98765",
            installationDate: block.timestamp,
            calibrationStatus: "Valid",
            location: "Bay 1",
            maintenanceHash: "ipfs://maintenance-log"
        });

        uint256 tokenId = core.mintEquipment(foundry, data, "ipfs://eq-meta");
        assertEq(tokenId, 1);
        assertEq(uint256(core.tokenType(tokenId)), uint256(TraceabilityCore.TokenType.Equipment));

        TraceabilityCore.EquipmentData memory saved = core.getEquipment(tokenId);
        assertEq(saved.machineId, "EQ-001");
        assertEq(saved.manufacturer, "Inductotherm");
    }

    function test_MintEquipment_UnauthorizedReverts() public {
        vm.prank(stranger);
        TraceabilityCore.EquipmentData memory data;
        vm.expectRevert("Only FOUNDRY or ADMIN");
        core.mintEquipment(stranger, data, "ipfs://eq-meta");
    }

    function test_MintProcess_LinkedCheck() public {
        // 1. Mint Equipment
        vm.prank(foundry);
        TraceabilityCore.EquipmentData memory eqData;
        uint256 eqId = core.mintEquipment(foundry, eqData, "ipfs://eq-meta");

        // 2. Mint Manpower
        vm.prank(supervisor);
        TraceabilityCore.ManpowerData memory mpData = TraceabilityCore.ManpowerData({
            operatorId: "OP-42",
            shift: "Day",
            skillCategory: "Pouring",
            trainingCert: "Certified",
            digitalSignature: "0xSignature"
        });
        uint256 mpId = core.mintManpower(foundry, mpData, "ipfs://mp-meta");

        // 3. Mint Process linked to Equipment and Manpower
        vm.prank(foundry);
        TraceabilityCore.ProcessData memory prData = TraceabilityCore.ProcessData({
            heatNo: "H-101",
            viscosityPri: 520,
            viscosityBack: 480,
            densityPri: 120,
            densityBack: 115,
            waxTemp: 6500,
            injectionPressure: 35,
            injectionTime: 30,
            pouringTemp: 1450,
            preheatingTemp: 1000,
            pouringSpeed: 50,
            humidity: 45,
            roomTemp: 24,
            processDuration: 120,
            equipmentId: eqId,
            manpowerId: mpId
        });

        uint256 prId = core.mintProcess(foundry, prData, "ipfs://pr-meta");
        assertEq(prId, 3); // 1 = Eq, 2 = Mp, 3 = Process
        assertEq(uint256(core.tokenType(prId)), uint256(TraceabilityCore.TokenType.Process));

        TraceabilityCore.ProcessData memory saved = core.getProcess(prId);
        assertEq(saved.heatNo, "H-101");
        assertEq(saved.equipmentId, eqId);
        assertEq(saved.manpowerId, mpId);
    }

    function test_MintProcess_InvalidLinkReverts() public {
        vm.prank(foundry);
        TraceabilityCore.ProcessData memory prData;
        prData.equipmentId = 999; // Non-existent Equipment ID

        vm.expectRevert("Linked Equipment does not exist");
        core.mintProcess(foundry, prData, "ipfs://pr-meta");
    }

    function test_MintProduct_Success() public {
        // Mint Process
        vm.prank(foundry);
        TraceabilityCore.ProcessData memory prData;
        uint256 prId = core.mintProcess(foundry, prData, "ipfs://pr-meta");

        vm.prank(oem);
        TraceabilityCore.ProductData memory prodData = TraceabilityCore.ProductData({
            partName: "Turbine Blade",
            alloyGrade: "Inconel 718",
            castingId: "C-9002",
            processId: prId,
            dppHash: "ipfs://dpp-data"
        });

        uint256 prodId = core.mintProduct(oem, prodData, "ipfs://prod-meta");
        assertEq(prodId, 2);
        assertEq(uint256(core.tokenType(prodId)), uint256(TraceabilityCore.TokenType.Product));

        TraceabilityCore.ProductData memory saved = core.getProduct(prodId);
        assertEq(saved.partName, "Turbine Blade");
        assertEq(saved.processId, prId);
    }

    function test_MintQuality_Success() public {
        // Mint Product
        vm.prank(oem);
        TraceabilityCore.ProductData memory prodData;
        uint256 prodId = core.mintProduct(oem, prodData, "ipfs://prod-meta");

        vm.prank(inspector);
        TraceabilityCore.QualityData memory qData = TraceabilityCore.QualityData({
            qualityScore: 95,
            defectPrediction: "Low Risk",
            inspectionResult: "Accepted",
            distortion: false,
            roughSurface: false,
            shrinkage: false,
            slagInclusion: false,
            productId: prodId
        });

        uint256 qId = core.mintQuality(inspector, qData, "ipfs://quality-meta");
        assertEq(qId, 2);
        assertEq(uint256(core.tokenType(qId)), uint256(TraceabilityCore.TokenType.QualityCertificate));

        TraceabilityCore.QualityData memory saved = core.getQuality(qId);
        assertEq(saved.qualityScore, 95);
        assertEq(saved.productId, prodId);
    }

    function test_MintMaintenance_Success() public {
        // Mint Equipment
        vm.prank(foundry);
        TraceabilityCore.EquipmentData memory eqData;
        uint256 eqId = core.mintEquipment(foundry, eqData, "ipfs://eq-meta");

        vm.prank(inspector);
        TraceabilityCore.MaintenanceData memory maintData = TraceabilityCore.MaintenanceData({
            preventiveMaintenance: "Monthly Check",
            calibrationHistory: "Calibrated on-site",
            downtime: 2,
            nextServiceDate: block.timestamp + 30 days,
            equipmentId: eqId
        });

        uint256 maintId = core.mintMaintenance(inspector, maintData, "ipfs://maint-meta");
        assertEq(maintId, 2);

        TraceabilityCore.MaintenanceData memory saved = core.getMaintenance(maintId);
        assertEq(saved.equipmentId, eqId);
        assertEq(saved.downtime, 2);
    }

    function test_MintBusiness_Success() public {
        // Mint Product
        vm.prank(oem);
        TraceabilityCore.ProductData memory prodData;
        uint256 prodId = core.mintProduct(oem, prodData, "ipfs://prod-meta");

        vm.prank(commercial);
        TraceabilityCore.BusinessData memory bizData = TraceabilityCore.BusinessData({
            customerOrder: "PO-450098",
            invoice: "INV-10982",
            revenue: 2500000, // $25,000.00
            dispatchDate: block.timestamp,
            supplyChainTrace: "ipfs://logistics-receipt",
            productId: prodId
        });

        uint256 bizId = core.mintBusiness(commercial, bizData, "ipfs://biz-meta");
        assertEq(bizId, 2);

        TraceabilityCore.BusinessData memory saved = core.getBusiness(bizId);
        assertEq(saved.productId, prodId);
        assertEq(saved.revenue, 2500000);
    }

    function test_TokenURI() public {
        vm.prank(foundry);
        TraceabilityCore.EquipmentData memory data;
        uint256 id = core.mintEquipment(foundry, data, "ipfs://eq-meta");

        string memory uri = core.tokenURI(id);
        bytes memory uriBytes = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(uriBytes[i], prefix[i]);
        }
    }
}
