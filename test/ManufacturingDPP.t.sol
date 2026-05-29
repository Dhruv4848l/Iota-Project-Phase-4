// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {ManufacturingDPP} from "../src/ManufacturingDPP.sol";

contract ManufacturingDPPTest is Test {
    ManufacturingDPP public dpp;

    // Test accounts
    address admin = address(0xA1);
    address foundry = address(0xA2);
    address machining = address(0xA3);
    address oem = address(0xA4);
    address mro = address(0xA5);
    address stranger = address(0xA6);

    bytes32 constant NOTARIZATION = bytes32(uint256(0xDEAD));
    string constant URI_V1 = "ipfs://QmV1";
    string constant URI_V2 = "ipfs://QmV2";

    uint256 constant EQUIPMENT_ID = 1;
    uint256 constant PART_ID = 2;

    function setUp() public {
        vm.startPrank(admin);
        dpp = new ManufacturingDPP();

        // Grant roles
        dpp.grantRole(dpp.FOUNDRY_ROLE(), foundry);
        dpp.grantRole(dpp.MACHINING_ROLE(), machining);
        dpp.grantRole(dpp.OEM_ROLE(), oem);
        dpp.grantRole(dpp.MRO_ROLE(), mro);

        // Mint equipment & part
        dpp.mintEquipment(foundry, EQUIPMENT_ID, URI_V1);
        dpp.mintPart(foundry, PART_ID, EQUIPMENT_ID, URI_V1);
        vm.stopPrank();
    }

    /* ─────────────────────────────────────────
       MINTING
    ───────────────────────────────────────── */

    function test_MintEquipment_TokenExists() public view {
        assertTrue(dpp.exists(EQUIPMENT_ID));
        assertEq(dpp.ownerOf(EQUIPMENT_ID), foundry);
    }

    function test_MintEquipment_InitialStageIsManufacturing() public view {
        assertEq(
            uint8(dpp.currentStage(EQUIPMENT_ID)), uint8(ManufacturingDPP.LifecycleStage.ManufacturingAndInspection)
        );
    }

    function test_MintPart_LinkedToParent() public view {
        assertEq(dpp.parentOf(PART_ID), EQUIPMENT_ID);
        assertEq(dpp.getChildCount(EQUIPMENT_ID), 1);
        assertEq(dpp.getChildren(EQUIPMENT_ID)[0], PART_ID);
    }

    function test_MintEquipment_RevertNonAdmin() public {
        vm.prank(stranger);
        vm.expectRevert();
        dpp.mintEquipment(stranger, 99, URI_V1);
    }

    function test_MintPart_RevertParentNotExist() public {
        vm.prank(admin);
        vm.expectRevert("Equipment must exist");
        dpp.mintPart(foundry, 99, 999, URI_V1);
    }

    /* ─────────────────────────────────────────
       UPDATE METADATA
    ───────────────────────────────────────── */

    function test_UpdateMetadata_FoundryDuringManufacturing() public {
        vm.prank(foundry);
        vm.expectEmit(true, false, false, true);
        emit ManufacturingDPP.MetadataUpdated(EQUIPMENT_ID, URI_V2, NOTARIZATION);
        dpp.updateMetadata(EQUIPMENT_ID, URI_V2, NOTARIZATION);
        assertEq(dpp.tokenUris(EQUIPMENT_ID), URI_V2);
    }

    function test_UpdateMetadata_RevertMachiningDuringManufacturing() public {
        vm.prank(machining);
        vm.expectRevert("Only FOUNDRY or ADMIN");
        dpp.updateMetadata(EQUIPMENT_ID, URI_V2, NOTARIZATION);
    }

    function test_UpdateMetadata_AdminCanAlwaysUpdate() public {
        vm.prank(admin);
        dpp.updateMetadata(EQUIPMENT_ID, URI_V2, NOTARIZATION);
        assertEq(dpp.tokenUris(EQUIPMENT_ID), URI_V2);
    }

    function test_UpdateMetadata_RevertNonexistentToken() public {
        vm.prank(admin);
        vm.expectRevert("Token does not exist");
        dpp.updateMetadata(999, URI_V2, NOTARIZATION);
    }

    /* ─────────────────────────────────────────
       LIFECYCLE STAGE TRANSITIONS
    ───────────────────────────────────────── */

    function test_LifecycleStage_FoundryAdvancesToAssembly() public {
        vm.prank(foundry);
        vm.expectEmit(true, false, false, true);
        emit ManufacturingDPP.LifecycleStageUpdated(
            EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.AssemblyAndIntegration, NOTARIZATION
        );
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.AssemblyAndIntegration, NOTARIZATION);
        assertEq(uint8(dpp.currentStage(EQUIPMENT_ID)), uint8(ManufacturingDPP.LifecycleStage.AssemblyAndIntegration));
    }

    function test_LifecycleStage_OemAdvancesToOperation() public {
        // Move to assembly first
        vm.prank(foundry);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.AssemblyAndIntegration, NOTARIZATION);

        vm.prank(oem);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.OperationAndUsage, NOTARIZATION);
        assertEq(uint8(dpp.currentStage(EQUIPMENT_ID)), uint8(ManufacturingDPP.LifecycleStage.OperationAndUsage));
    }

    function test_LifecycleStage_RevertSameStage() public {
        vm.prank(foundry);
        vm.expectRevert("Already at this stage");
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.ManufacturingAndInspection, NOTARIZATION);
    }

    function test_LifecycleStage_RevertUnauthorizedRole() public {
        // OEM cannot advance from Manufacturing stage (only FOUNDRY/MACHINING/ADMIN)
        vm.prank(oem);
        vm.expectRevert("Only FOUNDRY, MACHINING or ADMIN");
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.AssemblyAndIntegration, NOTARIZATION);
    }

    /* ─────────────────────────────────────────
       METADATA STAGE-GATING
    ───────────────────────────────────────── */

    function test_MetadataGating_MachiningDuringAssembly() public {
        // Advance to Assembly
        vm.prank(foundry);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.AssemblyAndIntegration, NOTARIZATION);

        // Machining should now be able to update metadata
        vm.prank(machining);
        dpp.updateMetadata(EQUIPMENT_ID, URI_V2, NOTARIZATION);
        assertEq(dpp.tokenUris(EQUIPMENT_ID), URI_V2);
    }

    function test_MetadataGating_MRODuringMaintenance() public {
        // Advance through stages
        vm.prank(foundry);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.AssemblyAndIntegration, NOTARIZATION);
        vm.prank(oem);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.OperationAndUsage, NOTARIZATION);
        vm.prank(oem);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.MaintenanceAndService, NOTARIZATION);

        // MRO should now update metadata
        vm.prank(mro);
        dpp.updateMetadata(EQUIPMENT_ID, URI_V2, NOTARIZATION);
        assertEq(dpp.tokenUris(EQUIPMENT_ID), URI_V2);
    }

    /* ─────────────────────────────────────────
       OWNERSHIP TRANSFER
    ───────────────────────────────────────── */

    function test_OwnershipTransfer_EmitsEvent() public {
        vm.prank(foundry);
        vm.expectEmit(true, false, false, true);
        emit ManufacturingDPP.OwnershipTransferred(EQUIPMENT_ID, foundry, oem, "Aerospace OEM Corp", NOTARIZATION);
        dpp.recordOwnershipTransfer(EQUIPMENT_ID, oem, "Aerospace OEM Corp", NOTARIZATION);
        assertEq(dpp.ownerOf(EQUIPMENT_ID), oem);
    }

    function test_OwnershipTransfer_RevertNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert("Not token owner");
        dpp.recordOwnershipTransfer(EQUIPMENT_ID, stranger, "Stranger", NOTARIZATION);
    }

    function test_OwnershipTransfer_RevertZeroAddress() public {
        vm.prank(foundry);
        vm.expectRevert("Cannot transfer to zero address");
        dpp.recordOwnershipTransfer(EQUIPMENT_ID, address(0), "Zero", NOTARIZATION);
    }

    /* ─────────────────────────────────────────
       MAINTENANCE LOGGING
    ───────────────────────────────────────── */

    function test_RecordMaintenance_EmitsEvent() public {
        vm.prank(mro);
        vm.expectEmit(true, false, false, true);
        emit ManufacturingDPP.MaintenanceLogged(EQUIPMENT_ID, "Blade tip inspection", NOTARIZATION);
        dpp.recordMaintenance(EQUIPMENT_ID, "Blade tip inspection", NOTARIZATION);
    }

    function test_RecordMaintenance_RevertNonMRO() public {
        vm.prank(foundry);
        vm.expectRevert();
        dpp.recordMaintenance(EQUIPMENT_ID, "Unauthorized entry", NOTARIZATION);
    }

    /* ─────────────────────────────────────────
       CERTIFICATION
    ───────────────────────────────────────── */

    function test_AddCertification_FoundryCanAdd() public {
        vm.prank(foundry);
        vm.expectEmit(true, false, false, true);
        emit ManufacturingDPP.CertificationAdded(EQUIPMENT_ID, "NDT", "ipfs://QmCert", NOTARIZATION);
        dpp.addCertification(EQUIPMENT_ID, "NDT", "ipfs://QmCert", NOTARIZATION);
    }

    function test_AddCertification_RevertStranger() public {
        vm.prank(stranger);
        vm.expectRevert("Unauthorized");
        dpp.addCertification(EQUIPMENT_ID, "NDT", "ipfs://QmCert", NOTARIZATION);
    }

    /* ─────────────────────────────────────────
       PROCESS STEP RECORDING
    ───────────────────────────────────────── */

    function test_RecordProcessStep_FoundryRole() public {
        vm.prank(foundry);
        vm.expectEmit(true, false, false, true);
        emit ManufacturingDPP.ProcessStepRecorded(
            EQUIPMENT_ID, "Wax Pattern Creation", "Tolerance: +/-0.05mm", NOTARIZATION
        );
        dpp.recordProcessStep(EQUIPMENT_ID, "Wax Pattern Creation", "Tolerance: +/-0.05mm", NOTARIZATION);
    }

    function test_RecordProcessStep_RevertNonFoundry() public {
        vm.prank(machining);
        vm.expectRevert();
        dpp.recordProcessStep(EQUIPMENT_ID, "Wax Pattern Creation", "Tolerance: +/-0.05mm", NOTARIZATION);
    }

    /* ─────────────────────────────────────────
       VIEW FUNCTIONS
    ───────────────────────────────────────── */

    function test_GetTokenInfo_ReturnsCorrectData() public view {
        (address owner, ManufacturingDPP.LifecycleStage stage, string memory uri, uint256 parent, uint256 childCount) =
            dpp.getTokenInfo(EQUIPMENT_ID);

        assertEq(owner, foundry);
        assertEq(uint8(stage), uint8(ManufacturingDPP.LifecycleStage.ManufacturingAndInspection));
        assertEq(uri, URI_V1);
        assertEq(parent, 0); // root token
        assertEq(childCount, 1);
    }

    function test_GetTokenInfo_RevertNonexistent() public {
        vm.expectRevert("Token does not exist");
        dpp.getTokenInfo(999);
    }

    function test_GetRoles_AdminHasAdminRole() public view {
        (,,,, bool isAdmin,) = dpp.getRoles(admin);
        assertTrue(isAdmin);
    }

    function test_GetRoles_FoundryHasFoundryRole() public view {
        (bool isFoundry,,,,,) = dpp.getRoles(foundry);
        assertTrue(isFoundry);
    }

    function test_GetRoles_StrangerHasNoRoles() public view {
        (bool f, bool m, bool o, bool mr, bool a, bool cr) = dpp.getRoles(stranger);
        assertFalse(f);
        assertFalse(m);
        assertFalse(o);
        assertFalse(mr);
        assertFalse(a);
        assertFalse(cr);
    }

    function test_TokenURI_ReturnsCorrectURI() public view {
        assertEq(dpp.tokenURI(EQUIPMENT_ID), URI_V1);
    }

    function test_TokenURI_RevertNonexistent() public {
        vm.expectRevert("Token does not exist");
        dpp.tokenURI(999);
    }

    function test_SupportsInterface_ERC721() public view {
        // ERC721 interfaceId = 0x80ac58cd
        assertTrue(dpp.supportsInterface(0x80ac58cd));
    }

    /* ─────────────────────────────────────────
       FULL LIFECYCLE INTEGRATION
    ───────────────────────────────────────── */

    function test_FullLifecycle_EndToEnd() public {
        console.log("=== Full Lifecycle Test: Turbine Blade #1 ===");

        // 1. Foundry records process steps
        vm.startPrank(foundry);
        dpp.recordProcessStep(EQUIPMENT_ID, "Wax Pattern Creation", "Alloy: IN718, Tolerance: +-0.05mm", NOTARIZATION);
        dpp.recordProcessStep(EQUIPMENT_ID, "Investment Casting", "Temp: 1450C, Vacuum: 1e-4 torr", NOTARIZATION);
        dpp.addCertification(EQUIPMENT_ID, "NDT", "ipfs://QmNDTCert", NOTARIZATION);
        dpp.addCertification(EQUIPMENT_ID, "X-Ray", "ipfs://QmXRayCert", NOTARIZATION);

        // 2. Advance to assembly
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.AssemblyAndIntegration, NOTARIZATION);
        dpp.recordOwnershipTransfer(EQUIPMENT_ID, machining, "Precision Machining Co.", NOTARIZATION);
        vm.stopPrank();

        // 3. Machining updates metadata
        vm.prank(machining);
        dpp.updateMetadata(EQUIPMENT_ID, "ipfs://QmV_Assembly", NOTARIZATION);

        // 4. Transfer to OEM and advance to Operation
        vm.prank(machining);
        dpp.recordOwnershipTransfer(EQUIPMENT_ID, oem, "AeroEngine OEM Ltd.", NOTARIZATION);
        vm.prank(oem);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.OperationAndUsage, NOTARIZATION);

        // 5. Transfer to MRO for maintenance
        vm.prank(oem);
        dpp.recordOwnershipTransfer(EQUIPMENT_ID, mro, "Global MRO Services", NOTARIZATION);
        vm.prank(oem);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.MaintenanceAndService, NOTARIZATION);
        vm.prank(mro);
        dpp.recordMaintenance(EQUIPMENT_ID, "750hr scheduled inspection, blade tip refurbished", NOTARIZATION);

        // 6. End of life
        vm.prank(mro);
        dpp.updateLifecycleStage(EQUIPMENT_ID, ManufacturingDPP.LifecycleStage.EndOfLifeAndRecycling, NOTARIZATION);

        // Final state verification
        (address finalOwner, ManufacturingDPP.LifecycleStage finalStage,,,) = dpp.getTokenInfo(EQUIPMENT_ID);
        assertEq(finalOwner, mro);
        assertEq(uint8(finalStage), uint8(ManufacturingDPP.LifecycleStage.EndOfLifeAndRecycling));
        console.log("Final owner:", finalOwner);
        console.log("Final stage:", uint8(finalStage), "(EndOfLifeAndRecycling = 4)");
    }

    /* ─────────────────────────────────────────
       CARBON NFT (v2)
    ───────────────────────────────────────── */

    address carbonReporter = address(0xA7);
    uint256 constant CARBON_ID = 100;

    function _setupCarbonReporter() internal {
        bytes32 role = dpp.CARBON_REPORTER_ROLE(); // cache before prank (prank consumed by external call)
        vm.startPrank(admin);
        dpp.grantRole(role, carbonReporter);
        vm.stopPrank();
    }

    function test_MintCarbonNFT_AdminCanMint() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit ManufacturingDPP.CarbonNFTMinted(CARBON_ID, EQUIPMENT_ID, 120_000, 32_000, 72, "Batch-B101");
        dpp.mintCarbonNFT(admin, CARBON_ID, EQUIPMENT_ID, 120_000, 32_000, 72, "Batch-B101", "ipfs://QmCarbon1");
        assertTrue(dpp.exists(CARBON_ID));
        assertEq(uint8(dpp.tokenType(CARBON_ID)), uint8(ManufacturingDPP.TokenType.Carbon));
    }

    function test_MintCarbonNFT_ReporterCanMint() public {
        _setupCarbonReporter();
        vm.prank(carbonReporter);
        dpp.mintCarbonNFT(carbonReporter, CARBON_ID, EQUIPMENT_ID, 80_000, 20_000, 85, "2024-Q1", "ipfs://QmCarbon2");
        assertTrue(dpp.exists(CARBON_ID));
    }

    function test_MintCarbonNFT_RevertStranger() public {
        vm.prank(stranger);
        vm.expectRevert("Only CARBON_REPORTER or ADMIN");
        dpp.mintCarbonNFT(stranger, CARBON_ID, 0, 100_000, 50_000, 50, "2024-Q2", "ipfs://QmCarbon3");
    }

    function test_MintCarbonNFT_RevertInvalidScore() public {
        vm.prank(admin);
        vm.expectRevert("Score must be 0-100");
        dpp.mintCarbonNFT(admin, CARBON_ID, 0, 100_000, 50_000, 101, "2024-Q2", "ipfs://QmCarbon4");
    }

    function test_MintCarbonNFT_RevertLinkedEquipmentNotExist() public {
        vm.prank(admin);
        vm.expectRevert("Linked equipment must exist");
        dpp.mintCarbonNFT(admin, CARBON_ID, 9999, 100_000, 50_000, 60, "2024-Q2", "ipfs://QmCarbon5");
    }

    function test_MintCarbonNFT_StandaloneWithZeroLink() public {
        vm.prank(admin);
        // linkedEquipmentId = 0 means standalone — should not revert
        dpp.mintCarbonNFT(admin, CARBON_ID, 0, 50_000, 10_000, 90, "Standalone", "ipfs://QmCarbon6");
        assertTrue(dpp.exists(CARBON_ID));
    }

    function test_GetCarbonData_ReturnsCorrectFields() public {
        vm.prank(admin);
        dpp.mintCarbonNFT(admin, CARBON_ID, EQUIPMENT_ID, 120_000, 32_000, 72, "Batch-B101", "ipfs://QmCarbon1");

        (uint256 energyWh, uint256 co2Grams, uint8 score, string memory period, uint256 linked,) =
            dpp.getCarbonData(CARBON_ID);

        assertEq(energyWh, 120_000);
        assertEq(co2Grams, 32_000);
        assertEq(score, 72);
        assertEq(period, "Batch-B101");
        assertEq(linked, EQUIPMENT_ID);
    }

    function test_GetCarbonData_RevertNonCarbonToken() public {
        vm.expectRevert("Not a Carbon NFT");
        dpp.getCarbonData(EQUIPMENT_ID); // Equipment token, not Carbon
    }

    function test_UpdateCarbonData_AdminUpdates() public {
        vm.prank(admin);
        dpp.mintCarbonNFT(admin, CARBON_ID, EQUIPMENT_ID, 120_000, 32_000, 72, "Batch-B101", "ipfs://QmCarbon1");

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ManufacturingDPP.CarbonDataUpdated(CARBON_ID, 95_000, 25_000, 80, NOTARIZATION);
        dpp.updateCarbonData(CARBON_ID, 95_000, 25_000, 80, NOTARIZATION);

        (uint256 e, uint256 c, uint8 s,,,) = dpp.getCarbonData(CARBON_ID);
        assertEq(e, 95_000);
        assertEq(c, 25_000);
        assertEq(s, 80);
    }

    function test_UpdateCarbonData_RevertOnNonCarbonToken() public {
        vm.prank(admin);
        vm.expectRevert("Not a Carbon NFT");
        dpp.updateCarbonData(EQUIPMENT_ID, 100_000, 40_000, 60, NOTARIZATION);
    }

    function test_UpdateCarbonData_RevertStranger() public {
        vm.prank(admin);
        dpp.mintCarbonNFT(admin, CARBON_ID, 0, 100_000, 50_000, 60, "2024-Q2", "ipfs://QmCarbon7");
        vm.prank(stranger);
        vm.expectRevert("Only CARBON_REPORTER or ADMIN");
        dpp.updateCarbonData(CARBON_ID, 90_000, 45_000, 65, NOTARIZATION);
    }

    function test_CarbonNFT_TokenTypeIsCarbon() public {
        vm.prank(admin);
        dpp.mintCarbonNFT(admin, CARBON_ID, 0, 100_000, 50_000, 60, "2024-Q2", "ipfs://QmCarbon8");
        assertEq(uint8(dpp.tokenType(CARBON_ID)), uint8(ManufacturingDPP.TokenType.Carbon));
        assertEq(uint8(dpp.tokenType(EQUIPMENT_ID)), uint8(ManufacturingDPP.TokenType.Equipment));
        assertEq(uint8(dpp.tokenType(PART_ID)), uint8(ManufacturingDPP.TokenType.Part));
    }
}
