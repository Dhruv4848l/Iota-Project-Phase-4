// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EquipmentNFT} from "./EquipmentNFT.sol";

contract MaintenanceNFT is ERC721, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant INSPECTOR_ROLE = keccak256("INSPECTOR_ROLE");

    struct MaintenanceData {
        string preventiveMaintenance;
        string calibrationHistory;
        uint16 downtime;
        uint256 nextServiceDate;
        uint256 equipmentId;
    }

    EquipmentNFT public immutable equipmentContract;

    uint256 private _tokenIdCounter;
    mapping(uint256 => MaintenanceData) private _maintenances;
    mapping(uint256 => string) private _tokenURIs;
    uint256[] private _allTokenIds;

    event MaintenanceMinted(uint256 indexed tokenId, address indexed owner);

    constructor(address equipmentAddr) ERC721("Maintenance DPP NFT", "MTDPP") {
        require(equipmentAddr != address(0), "Invalid Equipment address");
        equipmentContract = EquipmentNFT(equipmentAddr);

        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(INSPECTOR_ROLE, ADMIN_ROLE);
    }

    function mint(address to, MaintenanceData calldata data, string calldata uri) external returns (uint256 tokenId) {
        require(hasRole(INSPECTOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only INSPECTOR or ADMIN");
        if (data.equipmentId > 0) {
            require(equipmentContract.exists(data.equipmentId), "Linked Equipment does not exist");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _maintenances[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit MaintenanceMinted(tokenId, to);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function getMaintenance(uint256 tokenId) external view returns (MaintenanceData memory) {
        require(exists(tokenId), "Token does not exist");
        return _maintenances[tokenId];
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "Token does not exist");

        string memory name = string(abi.encodePacked("Maintenance NFT #", Strings.toString(tokenId)));
        bytes memory json = abi.encodePacked(
            '{"name":"',
            name,
            '",',
            '"description":"Traceability Digital Product Passport for Maintenance.",',
            '"tokenType":"Maintenance",',
            '"customURI":"',
            _tokenURIs[tokenId],
            '"}'
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
