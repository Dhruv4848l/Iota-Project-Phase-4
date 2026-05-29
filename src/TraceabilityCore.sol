// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract TraceabilityCore is ERC721, AccessControl {
    /* ─────────────────────────────────────────────
       ROLES
    ───────────────────────────────────────────── */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDRY_ROLE = keccak256("FOUNDRY_ROLE");
    bytes32 public constant OEM_ROLE = keccak256("OEM_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE");
    bytes32 public constant INSPECTOR_ROLE = keccak256("INSPECTOR_ROLE");
    bytes32 public constant COMMERCIAL_ROLE = keccak256("COMMERCIAL_ROLE");

    /* ─────────────────────────────────────────────
       ENUMS & STRUCTS
    ───────────────────────────────────────────── */
    enum TokenType {
        Equipment,
        Process,
        Product,
        Manpower,
        QualityCertificate,
        Maintenance,
        BusinessValue
    }

    struct EquipmentData {
        string machineId;
        string machineType;
        string manufacturer;
        string modelNumber;
        string serialNumber;
        uint256 installationDate;
        string calibrationStatus;
        string maintenanceHash;
        string location;
    }

    struct ProcessData {
        string heatNo;
        uint16 viscosityPri;
        uint16 viscosityBack;
        uint16 densityPri;
        uint16 densityBack;
        uint16 waxTemp;
        uint16 injectionPressure;
        uint16 injectionTime;
        uint16 pouringTemp;
        uint16 preheatingTemp;
        uint16 pouringSpeed;
        uint8 humidity;
        uint8 roomTemp;
        uint16 processDuration;
        uint256 equipmentId;
        uint256 manpowerId;
    }

    struct ProductData {
        string partName;
        string alloyGrade;
        string castingId;
        uint256 processId;
        string dppHash;
    }

    struct ManpowerData {
        string operatorId;
        string shift;
        string skillCategory;
        string trainingCert;
        string digitalSignature;
    }

    struct QualityData {
        uint8 qualityScore;
        string defectPrediction;
        string inspectionResult;
        bool distortion;
        bool roughSurface;
        bool shrinkage;
        bool slagInclusion;
        uint256 productId;
    }

    struct MaintenanceData {
        string preventiveMaintenance;
        string calibrationHistory;
        uint16 downtime;
        uint256 nextServiceDate;
        uint256 equipmentId;
    }

    struct BusinessData {
        string customerOrder;
        string invoice;
        uint256 revenue;
        uint256 dispatchDate;
        string supplyChainTrace;
        uint256 productId;
    }

    /* ─────────────────────────────────────────────
       STATE
    ───────────────────────────────────────────── */
    uint256 private _tokenIdCounter;

    mapping(uint256 => TokenType) private _tokenTypes;
    mapping(uint256 => string) private _tokenURIs;

    mapping(uint256 => EquipmentData) private _equipments;
    mapping(uint256 => ProcessData) private _processes;
    mapping(uint256 => ProductData) private _products;
    mapping(uint256 => ManpowerData) private _manpowers;
    mapping(uint256 => QualityData) private _qualities;
    mapping(uint256 => MaintenanceData) private _maintenances;
    mapping(uint256 => BusinessData) private _businesses;

    uint256[] private _allTokenIds;

    /* ─────────────────────────────────────────────
       EVENTS
    ───────────────────────────────────────────── */
    event TokenMinted(uint256 indexed tokenId, TokenType indexed tokenType, address indexed owner);

    /* ─────────────────────────────────────────────
       CONSTRUCTOR
    ───────────────────────────────────────────── */
    constructor() ERC721("Manufacturing Lifecycle DPP", "MLDPP") {
        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(FOUNDRY_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OEM_ROLE, ADMIN_ROLE);
        _setRoleAdmin(SUPERVISOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(INSPECTOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(COMMERCIAL_ROLE, ADMIN_ROLE);
    }

    /* ─────────────────────────────────────────────
       MINTING FUNCTIONS
    ───────────────────────────────────────────── */
    function mintEquipment(address to, EquipmentData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(FOUNDRY_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only FOUNDRY or ADMIN");
        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _tokenTypes[tokenId] = TokenType.Equipment;
        _equipments[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit TokenMinted(tokenId, TokenType.Equipment, to);
    }

    function mintProcess(address to, ProcessData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(FOUNDRY_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only FOUNDRY or ADMIN");
        if (data.equipmentId > 0) {
            require(_ownerOf(data.equipmentId) != address(0), "Linked Equipment does not exist");
            require(_tokenTypes[data.equipmentId] == TokenType.Equipment, "Not an Equipment token");
        }
        if (data.manpowerId > 0) {
            require(_ownerOf(data.manpowerId) != address(0), "Linked Manpower does not exist");
            require(_tokenTypes[data.manpowerId] == TokenType.Manpower, "Not a Manpower token");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _tokenTypes[tokenId] = TokenType.Process;
        _processes[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit TokenMinted(tokenId, TokenType.Process, to);
    }

    function mintProduct(address to, ProductData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(OEM_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only OEM or ADMIN");
        if (data.processId > 0) {
            require(_ownerOf(data.processId) != address(0), "Linked Process does not exist");
            require(_tokenTypes[data.processId] == TokenType.Process, "Not a Process token");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _tokenTypes[tokenId] = TokenType.Product;
        _products[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit TokenMinted(tokenId, TokenType.Product, to);
    }

    function mintManpower(address to, ManpowerData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(SUPERVISOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only SUPERVISOR or ADMIN");
        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _tokenTypes[tokenId] = TokenType.Manpower;
        _manpowers[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit TokenMinted(tokenId, TokenType.Manpower, to);
    }

    function mintQuality(address to, QualityData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(INSPECTOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only INSPECTOR or ADMIN");
        if (data.productId > 0) {
            require(_ownerOf(data.productId) != address(0), "Linked Product does not exist");
            require(_tokenTypes[data.productId] == TokenType.Product, "Not a Product token");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _tokenTypes[tokenId] = TokenType.QualityCertificate;
        _qualities[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit TokenMinted(tokenId, TokenType.QualityCertificate, to);
    }

    function mintMaintenance(address to, MaintenanceData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(INSPECTOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only INSPECTOR or ADMIN");
        if (data.equipmentId > 0) {
            require(_ownerOf(data.equipmentId) != address(0), "Linked Equipment does not exist");
            require(_tokenTypes[data.equipmentId] == TokenType.Equipment, "Not an Equipment token");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _tokenTypes[tokenId] = TokenType.Maintenance;
        _maintenances[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit TokenMinted(tokenId, TokenType.Maintenance, to);
    }

    function mintBusiness(address to, BusinessData calldata data, string calldata uri)
        external
        returns (uint256 tokenId)
    {
        require(hasRole(COMMERCIAL_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only COMMERCIAL or ADMIN");
        if (data.productId > 0) {
            require(_ownerOf(data.productId) != address(0), "Linked Product does not exist");
            require(_tokenTypes[data.productId] == TokenType.Product, "Not a Product token");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _tokenTypes[tokenId] = TokenType.BusinessValue;
        _businesses[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit TokenMinted(tokenId, TokenType.BusinessValue, to);
    }

    /* ─────────────────────────────────────────────
       READ/GETTER FUNCTIONS
    ───────────────────────────────────────────── */
    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function tokenType(uint256 tokenId) external view returns (TokenType) {
        require(exists(tokenId), "Token does not exist");
        return _tokenTypes[tokenId];
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function getEquipment(uint256 tokenId) external view returns (EquipmentData memory) {
        require(exists(tokenId), "Token does not exist");
        require(_tokenTypes[tokenId] == TokenType.Equipment, "Not an Equipment token");
        return _equipments[tokenId];
    }

    function getProcess(uint256 tokenId) external view returns (ProcessData memory) {
        require(exists(tokenId), "Token does not exist");
        require(_tokenTypes[tokenId] == TokenType.Process, "Not a Process token");
        return _processes[tokenId];
    }

    function getProduct(uint256 tokenId) external view returns (ProductData memory) {
        require(exists(tokenId), "Token does not exist");
        require(_tokenTypes[tokenId] == TokenType.Product, "Not a Product token");
        return _products[tokenId];
    }

    function getManpower(uint256 tokenId) external view returns (ManpowerData memory) {
        require(exists(tokenId), "Token does not exist");
        require(_tokenTypes[tokenId] == TokenType.Manpower, "Not a Manpower token");
        return _manpowers[tokenId];
    }

    function getQuality(uint256 tokenId) external view returns (QualityData memory) {
        require(exists(tokenId), "Token does not exist");
        require(_tokenTypes[tokenId] == TokenType.QualityCertificate, "Not a Quality token");
        return _qualities[tokenId];
    }

    function getMaintenance(uint256 tokenId) external view returns (MaintenanceData memory) {
        require(exists(tokenId), "Token does not exist");
        require(_tokenTypes[tokenId] == TokenType.Maintenance, "Not a Maintenance token");
        return _maintenances[tokenId];
    }

    function getBusiness(uint256 tokenId) external view returns (BusinessData memory) {
        require(exists(tokenId), "Token does not exist");
        require(_tokenTypes[tokenId] == TokenType.BusinessValue, "Not a Business token");
        return _businesses[tokenId];
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

    /* ─────────────────────────────────────────────
       ON-CHAIN METADATA GENERATOR (tokenURI)
    ───────────────────────────────────────────── */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "Token does not exist");

        string memory name = string(abi.encodePacked("Lifecycle NFT #", Strings.toString(tokenId)));
        string memory typeName = _getTypeName(_tokenTypes[tokenId]);

        // Standard JSON payload
        bytes memory json = abi.encodePacked(
            '{"name":"',
            name,
            '",',
            '"description":"Traceability Digital Product Passport of type ',
            typeName,
            '.",',
            '"tokenType":"',
            typeName,
            '",',
            '"customURI":"',
            _tokenURIs[tokenId],
            '"}'
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    function _getTypeName(TokenType t) internal pure returns (string memory) {
        if (t == TokenType.Equipment) return "Equipment";
        if (t == TokenType.Process) return "Process";
        if (t == TokenType.Product) return "Product";
        if (t == TokenType.Manpower) return "Manpower";
        if (t == TokenType.QualityCertificate) return "QualityCertificate";
        if (t == TokenType.Maintenance) return "Maintenance";
        return "BusinessValue";
    }

    /* ─────────────────────────────────────────────
       ERC165 OVERRIDE
    ───────────────────────────────────────────── */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
