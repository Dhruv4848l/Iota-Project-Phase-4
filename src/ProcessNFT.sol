// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EquipmentNFT} from "./EquipmentNFT.sol";
import {ManpowerNFT} from "./ManpowerNFT.sol";

contract ProcessNFT is ERC721, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDRY_ROLE = keccak256("FOUNDRY_ROLE");

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

    EquipmentNFT public immutable equipmentContract;
    ManpowerNFT public immutable manpowerContract;

    uint256 private _tokenIdCounter;
    mapping(uint256 => ProcessData) private _processes;
    mapping(uint256 => string) private _tokenURIs;
    uint256[] private _allTokenIds;

    event ProcessMinted(uint256 indexed tokenId, address indexed owner);

    constructor(address equipmentAddr, address manpowerAddr) ERC721("Process DPP NFT", "PRDPP") {
        require(equipmentAddr != address(0), "Invalid Equipment address");
        require(manpowerAddr != address(0), "Invalid Manpower address");
        equipmentContract = EquipmentNFT(equipmentAddr);
        manpowerContract = ManpowerNFT(manpowerAddr);

        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(FOUNDRY_ROLE, ADMIN_ROLE);
    }

    function mint(address to, ProcessData calldata data, string calldata uri) external returns (uint256 tokenId) {
        require(hasRole(FOUNDRY_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only FOUNDRY or ADMIN");
        if (data.equipmentId > 0) {
            require(equipmentContract.exists(data.equipmentId), "Linked Equipment does not exist");
        }
        if (data.manpowerId > 0) {
            require(manpowerContract.exists(data.manpowerId), "Linked Manpower does not exist");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _processes[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit ProcessMinted(tokenId, to);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function getProcess(uint256 tokenId) external view returns (ProcessData memory) {
        require(exists(tokenId), "Token does not exist");
        return _processes[tokenId];
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "Token does not exist");

        string memory name = string(abi.encodePacked("Process NFT #", Strings.toString(tokenId)));
        bytes memory json = abi.encodePacked(
            '{"name":"',
            name,
            '",',
            '"description":"Traceability Digital Product Passport for Process.",',
            '"tokenType":"Process",',
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
