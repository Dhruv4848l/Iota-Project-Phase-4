// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ManpowerNFT is ERC721, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE");

    struct ManpowerData {
        string operatorId;
        string shift;
        string skillCategory;
        string trainingCert;
        string digitalSignature;
    }

    uint256 private _tokenIdCounter;
    mapping(uint256 => ManpowerData) private _manpowers;
    mapping(uint256 => string) private _tokenURIs;
    uint256[] private _allTokenIds;

    event ManpowerMinted(uint256 indexed tokenId, address indexed owner);

    constructor() ERC721("Manpower DPP NFT", "MPDPP") {
        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(SUPERVISOR_ROLE, ADMIN_ROLE);
    }

    function mint(address to, ManpowerData calldata data, string calldata uri) external returns (uint256 tokenId) {
        require(hasRole(SUPERVISOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only SUPERVISOR or ADMIN");
        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _manpowers[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit ManpowerMinted(tokenId, to);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function getManpower(uint256 tokenId) external view returns (ManpowerData memory) {
        require(exists(tokenId), "Token does not exist");
        return _manpowers[tokenId];
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "Token does not exist");

        string memory name = string(abi.encodePacked("Manpower NFT #", Strings.toString(tokenId)));
        bytes memory json = abi.encodePacked(
            '{"name":"',
            name,
            '",',
            '"description":"Traceability Digital Product Passport for Manpower.",',
            '"tokenType":"Manpower",',
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
