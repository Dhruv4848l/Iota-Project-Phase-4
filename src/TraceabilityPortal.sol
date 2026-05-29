// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EquipmentNFT} from "./EquipmentNFT.sol";
import {ProcessNFT} from "./ProcessNFT.sol";
import {ProductNFT} from "./ProductNFT.sol";
import {ManpowerNFT} from "./ManpowerNFT.sol";
import {QualityNFT} from "./QualityNFT.sol";
import {MaintenanceNFT} from "./MaintenanceNFT.sol";
import {BusinessNFT} from "./BusinessNFT.sol";

contract TraceabilityPortal is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDRY_ROLE = keccak256("FOUNDRY_ROLE");
    bytes32 public constant OEM_ROLE = keccak256("OEM_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE");
    bytes32 public constant INSPECTOR_ROLE = keccak256("INSPECTOR_ROLE");
    bytes32 public constant COMMERCIAL_ROLE = keccak256("COMMERCIAL_ROLE");

    EquipmentNFT public immutable equipmentContract;
    ProcessNFT public immutable processContract;
    ProductNFT public immutable productContract;
    ManpowerNFT public immutable manpowerContract;
    QualityNFT public immutable qualityContract;
    MaintenanceNFT public immutable maintenanceContract;
    BusinessNFT public immutable businessContract;

    // Linkage mappings
    mapping(uint256 => uint256[]) private _productToQuality;
    mapping(uint256 => uint256[]) private _productToBusiness;
    mapping(uint256 => uint256[]) private _equipmentToMaintenance;

    struct FullPassport {
        ProductNFT.ProductData product;
        ProcessNFT.ProcessData process;
        EquipmentNFT.EquipmentData equipment;
        ManpowerNFT.ManpowerData manpower;
        QualityNFT.QualityData[] qualityRecords;
        MaintenanceNFT.MaintenanceData[] maintenanceRecords;
        BusinessNFT.BusinessData[] businessRecords;
        bool exists;
    }

    event EquipmentRegistered(uint256 indexed tokenId, address indexed owner);
    event ProcessRegistered(uint256 indexed tokenId, address indexed owner);
    event ProductRegistered(uint256 indexed tokenId, address indexed owner);
    event ManpowerRegistered(uint256 indexed tokenId, address indexed owner);
    event QualityRegistered(uint256 indexed tokenId, address indexed owner);
    event MaintenanceRegistered(uint256 indexed tokenId, address indexed owner);
    event BusinessRegistered(uint256 indexed tokenId, address indexed owner);

    constructor(
        address equipmentAddr,
        address processAddr,
        address productAddr,
        address manpowerAddr,
        address qualityAddr,
        address maintenanceAddr,
        address businessAddr
    ) {
        require(equipmentAddr != address(0), "Invalid Equipment address");
        require(processAddr != address(0), "Invalid Process address");
        require(productAddr != address(0), "Invalid Product address");
        require(manpowerAddr != address(0), "Invalid Manpower address");
        require(qualityAddr != address(0), "Invalid Quality address");
        require(maintenanceAddr != address(0), "Invalid Maintenance address");
        require(businessAddr != address(0), "Invalid Business address");

        equipmentContract = EquipmentNFT(equipmentAddr);
        processContract = ProcessNFT(processAddr);
        productContract = ProductNFT(productAddr);
        manpowerContract = ManpowerNFT(manpowerAddr);
        qualityContract = QualityNFT(qualityAddr);
        maintenanceContract = MaintenanceNFT(maintenanceAddr);
        businessContract = BusinessNFT(businessAddr);

        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(FOUNDRY_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OEM_ROLE, ADMIN_ROLE);
        _setRoleAdmin(SUPERVISOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(INSPECTOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(COMMERCIAL_ROLE, ADMIN_ROLE);
    }

    /* ─────────────────────────────────────────────
       ORCHESTRATED MINTING FUNCTIONS
    ───────────────────────────────────────────── */
    function mintEquipment(address to, EquipmentNFT.EquipmentData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(FOUNDRY_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only FOUNDRY or ADMIN");
        tokenId = equipmentContract.mint(to, data, uri);
        emit EquipmentRegistered(tokenId, to);
    }

    function mintProcess(address to, ProcessNFT.ProcessData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(FOUNDRY_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only FOUNDRY or ADMIN");
        tokenId = processContract.mint(to, data, uri);
        emit ProcessRegistered(tokenId, to);
    }

    function mintProduct(address to, ProductNFT.ProductData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(OEM_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only OEM or ADMIN");
        tokenId = productContract.mint(to, data, uri);
        emit ProductRegistered(tokenId, to);
    }

    function mintManpower(address to, ManpowerDataCalldata calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(SUPERVISOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only SUPERVISOR or ADMIN");

        ManpowerNFT.ManpowerData memory mpData = ManpowerNFT.ManpowerData({
            operatorId: data.operatorId,
            shift: data.shift,
            skillCategory: data.skillCategory,
            trainingCert: data.trainingCert,
            digitalSignature: data.digitalSignature
        });

        tokenId = manpowerContract.mint(to, mpData, uri);
        emit ManpowerRegistered(tokenId, to);
    }

    // Helper structs to prevent stack-too-deep / compiler issues in portal signatures if any
    struct ManpowerDataCalldata {
        string operatorId;
        string shift;
        string skillCategory;
        string trainingCert;
        string digitalSignature;
    }

    function mintQuality(address to, QualityNFT.QualityData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(INSPECTOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only INSPECTOR or ADMIN");
        tokenId = qualityContract.mint(to, data, uri);
        _productToQuality[data.productId].push(tokenId);
        emit QualityRegistered(tokenId, to);
    }

    function mintMaintenance(address to, MaintenanceNFT.MaintenanceData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(INSPECTOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only INSPECTOR or ADMIN");
        tokenId = maintenanceContract.mint(to, data, uri);
        _equipmentToMaintenance[data.equipmentId].push(tokenId);
        emit MaintenanceRegistered(tokenId, to);
    }

    function mintBusiness(address to, BusinessNFT.BusinessData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(COMMERCIAL_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only COMMERCIAL or ADMIN");
        tokenId = businessContract.mint(to, data, uri);
        _productToBusiness[data.productId].push(tokenId);
        emit BusinessRegistered(tokenId, to);
    }

    /* ─────────────────────────────────────────────
       DYNAMIC RESOLUTION
    ───────────────────────────────────────────── */
    function getFullPassport(uint256 productId) external view returns (FullPassport memory passport) {
        if (!productContract.exists(productId)) {
            passport.exists = false;
            return passport;
        }
        passport.exists = true;
        passport.product = productContract.getProduct(productId);

        uint256 processId = passport.product.processId;
        if (processId > 0 && processContract.exists(processId)) {
            passport.process = processContract.getProcess(processId);

            uint256 equipmentId = passport.process.equipmentId;
            if (equipmentId > 0 && equipmentContract.exists(equipmentId)) {
                passport.equipment = equipmentContract.getEquipment(equipmentId);

                // Get maintenance records for this equipment
                uint256[] memory maintIds = _equipmentToMaintenance[equipmentId];
                passport.maintenanceRecords = new MaintenanceNFT.MaintenanceData[](maintIds.length);
                for (uint256 i = 0; i < maintIds.length; i++) {
                    passport.maintenanceRecords[i] = maintenanceContract.getMaintenance(maintIds[i]);
                }
            }

            uint256 manpowerId = passport.process.manpowerId;
            if (manpowerId > 0 && manpowerContract.exists(manpowerId)) {
                passport.manpower = manpowerContract.getManpower(manpowerId);
            }
        }

        // Get quality records for this product
        uint256[] memory qualIds = _productToQuality[productId];
        passport.qualityRecords = new QualityNFT.QualityData[](qualIds.length);
        for (uint256 i = 0; i < qualIds.length; i++) {
            passport.qualityRecords[i] = qualityContract.getQuality(qualIds[i]);
        }

        // Get business records for this product
        uint256[] memory busIds = _productToBusiness[productId];
        passport.businessRecords = new BusinessNFT.BusinessData[](busIds.length);
        for (uint256 i = 0; i < busIds.length; i++) {
            passport.businessRecords[i] = businessContract.getBusiness(busIds[i]);
        }
    }

    function getRoles(address account)
        external
        view
        returns (bool admin, bool foundry, bool oem, bool supervisor, bool inspector, bool commercial)
    {
        return (
            hasRole(ADMIN_ROLE, account),
            hasRole(FOUNDRY_ROLE, account),
            hasRole(OEM_ROLE, account),
            hasRole(SUPERVISOR_ROLE, account),
            hasRole(INSPECTOR_ROLE, account),
            hasRole(COMMERCIAL_ROLE, account)
        );
    }
}
