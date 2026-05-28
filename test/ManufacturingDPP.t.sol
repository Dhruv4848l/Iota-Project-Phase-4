// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {ManufacturingDPP} from "../src/ManufacturingDPP.sol";

contract ManufacturingDPPTest is Test {
    ManufacturingDPP public dpp;

    // Test accounts
    address admin    = address(0xA1);
    address foundry  = address(0xA2);
    address machining = address(0xA3);
    address oem      = address(0xA4);
    address mro      = address(0xA5);
    address stranger = address(0xA6);

    bytes32 constant NOTARIZATION = bytes32(uint256(0xDEAD));
    string  constant URI_V1 = "ipfs://QmV1";
    string  constant URI_V2 = "ipfs://QmV2";

    uint256 constant EQUIPMENT_ID = 1;
    uint256 constant PART_ID      = 2;

    function setUp() public {
        vm.startPrank(admin);
        dpp = new ManufacturingDPP();

        // Grant roles
        dpp.grantRole(dpp.FOUNDRY_ROLE(),   foundry);
        dpp.grantRole(dpp.MACHINING_ROLE(), machining);
        dpp.grantRole(dpp.OEM_ROLE(),       oem);
        dpp.grantRole(dpp.MRO_ROLE(),       mro);

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
            uint8(dpp.currentStage(EQUIPMENT_ID)),
            uint8(ManufacturingDPP.LifecycleStage.ManufacturingAndInspection)
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
            EQUIPMENT_ID,
            ManufacturingDPP.LifecycleStage.AssemblyAndIntegration,
            NOTARIZATION
        );
        dpp.updateLifecycleStage(
            EQUIPMENT_ID,
            ManufacturingDPP.LifecycleStage.AssemblyAndIntegration,
            NOTARIZATION
        );
        assertEq(
            uint8(dpp.currentStage(EQUIPMENT_ID)),
            uint8(ManufacturingDPP.LifecycleStage.AssemblyAndIntegration)
        );
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
        dpp.updateLifecycleStage(
            EQUIPMENT_ID,
            ManufacturingDPP.LifecycleStage.ManufacturingAndInspection,
            NOTARIZATION
        );
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
        emit ManufacturingDPP.ProcessStepRecorded(EQUIPMENT_ID, "Wax Pattern Creation", "Tolerance: +/-0.05mm", NOTARIZATION);
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
        (, , , , bool isAdmin) = dpp.getRoles(admin);
        assertTrue(isAdmin);
    }

    function test_GetRoles_FoundryHasFoundryRole() public view {
        (bool isFoundry, , , , ) = dpp.getRoles(foundry);
        assertTrue(isFoundry);
    }

    function test_GetRoles_StrangerHasNoRoles() public view {
        (bool f, bool m, bool o, bool mr, bool a) = dpp.getRoles(stranger);
        assertFalse(f);
        assertFalse(m);
        assertFalse(o);
        assertFalse(mr);
        assertFalse(a);
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
        dpp.recordProcessStep(EQUIPMENT_ID, "Investment Casting",   "Temp: 1450C, Vacuum: 1e-4 torr",  NOTARIZATION);
        dpp.addCertification(EQUIPMENT_ID, "NDT",   "ipfs://QmNDTCert",  NOTARIZATION);
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
        (address finalOwner, ManufacturingDPP.LifecycleStage finalStage, , , ) = dpp.getTokenInfo(EQUIPMENT_ID);
        assertEq(finalOwner, mro);
        assertEq(uint8(finalStage), uint8(ManufacturingDPP.LifecycleStage.EndOfLifeAndRecycling));
        console.log("Final owner:", finalOwner);
        console.log("Final stage:", uint8(finalStage), "(EndOfLifeAndRecycling = 4)");
    }
}
