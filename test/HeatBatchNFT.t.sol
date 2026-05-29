// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {HeatBatchNFT} from "../src/HeatBatchNFT.sol";

contract HeatBatchNFTTest is Test {
    HeatBatchNFT public nft;

    address admin   = address(0xA1);
    address foundry = address(0xA2);
    address stranger = address(0xA3);

    HeatBatchNFT.ProcessParams defaultPP = HeatBatchNFT.ProcessParams({
        pouringTemp:       692,
        injectionPressure: 35,
        injectionTime:     30,
        humidity:          22,
        roomTemp:          25,
        processDuration:   45
    });

    // Si=7.20, Fe=0.60, Mn=0.30, Mg=0.30, Cu=0.10, Zn=0.10, Ti=0.10, Al=91.20
    HeatBatchNFT.ChemComposition defaultCC = HeatBatchNFT.ChemComposition({
        si: 720, fe: 60, mn: 30, mg: 30, cu: 10, zn: 10, ti: 10, al: 9120
    });

    HeatBatchNFT.DefectInfo noDefects = HeatBatchNFT.DefectInfo({
        distortion: false, roughSurface: false, shrinkage: false, slagInclusion: false
    });

    HeatBatchNFT.DefectInfo withDefects = HeatBatchNFT.DefectInfo({
        distortion: true, roughSurface: false, shrinkage: true, slagInclusion: false
    });

    function setUp() public {
        vm.startPrank(admin);
        nft = new HeatBatchNFT();
        nft.grantRole(nft.FOUNDRY_ROLE(), foundry);
        vm.stopPrank();
    }

    /* ─────────────────────────────────────────
       MINTING
    ───────────────────────────────────────── */

    function test_MintHeatBatch_AdminCanMint() public {
        vm.prank(admin);
        uint256 tokenId = nft.mintHeatBatch(
            admin, "H001", "Precision Foundry Ltd.",
            defaultPP, defaultCC, noDefects, 92
        );
        assertEq(tokenId, 1);
        assertTrue(nft.exists(tokenId));
        assertEq(nft.ownerOf(tokenId), admin);
    }

    function test_MintHeatBatch_FoundryCanMint() public {
        vm.prank(foundry);
        uint256 tokenId = nft.mintHeatBatch(
            foundry, "H002", "Foundry A",
            defaultPP, defaultCC, noDefects, 85
        );
        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), foundry);
    }

    function test_MintHeatBatch_StrangerReverts() public {
        vm.prank(stranger);
        vm.expectRevert("Only FOUNDRY or ADMIN");
        nft.mintHeatBatch(stranger, "H003", "Fake Foundry", defaultPP, defaultCC, noDefects, 50);
    }

    function test_MintHeatBatch_DuplicateHeatNoReverts() public {
        vm.startPrank(admin);
        nft.mintHeatBatch(admin, "H001", "Foundry A", defaultPP, defaultCC, noDefects, 90);
        vm.expectRevert("Heat number already minted");
        nft.mintHeatBatch(admin, "H001", "Foundry B", defaultPP, defaultCC, noDefects, 80);
        vm.stopPrank();
    }

    function test_MintHeatBatch_InvalidScoreReverts() public {
        vm.prank(admin);
        vm.expectRevert("Score must be 0-100");
        nft.mintHeatBatch(admin, "H001", "Foundry", defaultPP, defaultCC, noDefects, 101);
    }

    function test_MintHeatBatch_EmptyHeatNoReverts() public {
        vm.prank(admin);
        vm.expectRevert("Heat number required");
        nft.mintHeatBatch(admin, "", "Foundry", defaultPP, defaultCC, noDefects, 80);
    }

    function test_MintHeatBatch_TokenIdAutoIncrements() public {
        vm.startPrank(admin);
        uint256 id1 = nft.mintHeatBatch(admin, "H001", "F", defaultPP, defaultCC, noDefects, 90);
        uint256 id2 = nft.mintHeatBatch(admin, "H002", "F", defaultPP, defaultCC, noDefects, 85);
        uint256 id3 = nft.mintHeatBatch(admin, "H003", "F", defaultPP, defaultCC, noDefects, 75);
        vm.stopPrank();
        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(id3, 3);
    }

    /* ─────────────────────────────────────────
       DATA RETRIEVAL
    ───────────────────────────────────────── */

    function test_GetHeatBatch_ReturnsCorrectData() public {
        vm.prank(admin);
        nft.mintHeatBatch(admin, "H001", "Precision Foundry Ltd.", defaultPP, defaultCC, withDefects, 82);

        HeatBatchNFT.HeatBatch memory b = nft.getHeatBatch(1);
        assertEq(b.heatNo,       "H001");
        assertEq(b.manufacturer, "Precision Foundry Ltd.");
        assertEq(b.qualityScore, 82);
        assertTrue(b.defects.distortion);
        assertTrue(b.defects.shrinkage);
        assertFalse(b.defects.roughSurface);
        assertFalse(b.defects.slagInclusion);
        assertEq(b.processParams.pouringTemp, 692);
        assertEq(b.chemComp.si, 720);
        assertEq(b.chemComp.al, 9120);
    }

    function test_GetHeatBatch_RevertNonexistent() public {
        vm.expectRevert("Token does not exist");
        nft.getHeatBatch(999);
    }

    function test_GetTokenIdByHeatNo_ReturnsCorrectId() public {
        vm.prank(admin);
        nft.mintHeatBatch(admin, "H001", "F", defaultPP, defaultCC, noDefects, 90);
        assertEq(nft.getTokenIdByHeatNo("H001"), 1);
        assertEq(nft.getTokenIdByHeatNo("H999"), 0); // not found returns 0
    }

    function test_TotalMinted_IncrementsCorrectly() public {
        assertEq(nft.totalMinted(), 0);
        vm.startPrank(admin);
        nft.mintHeatBatch(admin, "H001", "F", defaultPP, defaultCC, noDefects, 90);
        nft.mintHeatBatch(admin, "H002", "F", defaultPP, defaultCC, noDefects, 85);
        vm.stopPrank();
        assertEq(nft.totalMinted(), 2);
    }

    function test_GetAllTokenIds_ReturnsAll() public {
        vm.startPrank(admin);
        nft.mintHeatBatch(admin, "H001", "F", defaultPP, defaultCC, noDefects, 90);
        nft.mintHeatBatch(admin, "H002", "F", defaultPP, defaultCC, noDefects, 85);
        nft.mintHeatBatch(admin, "H003", "F", defaultPP, defaultCC, noDefects, 75);
        vm.stopPrank();
        uint256[] memory ids = nft.getAllTokenIds();
        assertEq(ids.length, 3);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
        assertEq(ids[2], 3);
    }

    function test_GetRecentTokenIds_Paginated() public {
        vm.startPrank(admin);
        nft.mintHeatBatch(admin, "H001", "F", defaultPP, defaultCC, noDefects, 90);
        nft.mintHeatBatch(admin, "H002", "F", defaultPP, defaultCC, noDefects, 85);
        nft.mintHeatBatch(admin, "H003", "F", defaultPP, defaultCC, noDefects, 75);
        vm.stopPrank();
        uint256[] memory recent = nft.getRecentTokenIds(2);
        assertEq(recent.length, 2);
        assertEq(recent[0], 2);
        assertEq(recent[1], 3);
    }

    function test_GetRecentTokenIds_MoreThanTotal() public {
        vm.prank(admin);
        nft.mintHeatBatch(admin, "H001", "F", defaultPP, defaultCC, noDefects, 90);
        uint256[] memory recent = nft.getRecentTokenIds(10);
        assertEq(recent.length, 1); // only 1 minted
    }

    /* ─────────────────────────────────────────
       TOKEN URI
    ───────────────────────────────────────── */

    function test_TokenURI_StartsWithDataURI() public {
        vm.prank(admin);
        nft.mintHeatBatch(admin, "H001", "Foundry", defaultPP, defaultCC, noDefects, 90);
        string memory uri = nft.tokenURI(1);
        // Should start with data:application/json;base64,
        bytes memory uriBytes = bytes(uri);
        bytes memory prefix   = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(uriBytes[i], prefix[i]);
        }
    }

    function test_TokenURI_RevertNonexistent() public {
        vm.expectRevert("Token does not exist");
        nft.tokenURI(999);
    }

    /* ─────────────────────────────────────────
       ROLES
    ───────────────────────────────────────── */

    function test_GetRoles_AdminHasAdminRole() public view {
        (, bool isAdmin) = nft.getRoles(admin);
        assertTrue(isAdmin);
    }

    function test_GetRoles_FoundryHasFoundryRole() public view {
        (bool isFoundry,) = nft.getRoles(foundry);
        assertTrue(isFoundry);
    }

    function test_GetRoles_StrangerHasNoRoles() public view {
        (bool f, bool a) = nft.getRoles(stranger);
        assertFalse(f);
        assertFalse(a);
    }

    /* ─────────────────────────────────────────
       EXISTS
    ───────────────────────────────────────── */

    function test_Exists_TrueAfterMint() public {
        vm.prank(admin);
        nft.mintHeatBatch(admin, "H001", "F", defaultPP, defaultCC, noDefects, 90);
        assertTrue(nft.exists(1));
    }

    function test_Exists_FalseBeforeMint() public view {
        assertFalse(nft.exists(1));
    }

    /* ─────────────────────────────────────────
       EVENTS
    ───────────────────────────────────────── */

    function test_MintHeatBatch_EmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit HeatBatchNFT.HeatBatchMinted(1, "H001", "Foundry A", 92, block.timestamp);
        nft.mintHeatBatch(admin, "H001", "Foundry A", defaultPP, defaultCC, noDefects, 92);
    }

    /* ─────────────────────────────────────────
       INTERFACE SUPPORT
    ───────────────────────────────────────── */

    function test_SupportsInterface_ERC721() public view {
        assertTrue(nft.supportsInterface(0x80ac58cd));
    }

    function test_SupportsInterface_AccessControl() public view {
        assertTrue(nft.supportsInterface(0x7965db0b));
    }
}
