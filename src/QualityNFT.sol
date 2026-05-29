// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ProductNFT} from "./ProductNFT.sol";

contract QualityNFT is ERC721, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant INSPECTOR_ROLE = keccak256("INSPECTOR_ROLE");

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

    ProductNFT public immutable productContract;

    uint256 private _tokenIdCounter;
    mapping(uint256 => QualityData) private _qualities;
    mapping(uint256 => string) private _tokenURIs;
    uint256[] private _allTokenIds;

    event QualityMinted(uint256 indexed tokenId, address indexed owner);

    constructor(address productAddr) ERC721("Quality Certificate DPP NFT", "QLDPP") {
        require(productAddr != address(0), "Invalid Product address");
        productContract = ProductNFT(productAddr);

        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(INSPECTOR_ROLE, ADMIN_ROLE);
    }

    function mint(address to, QualityData calldata data, string calldata uri) external returns (uint256 tokenId) {
        require(hasRole(INSPECTOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only INSPECTOR or ADMIN");
        if (data.productId > 0) {
            require(productContract.exists(data.productId), "Linked Product does not exist");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _qualities[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit QualityMinted(tokenId, to);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function getQuality(uint256 tokenId) external view returns (QualityData memory) {
        require(exists(tokenId), "Token does not exist");
        return _qualities[tokenId];
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "Token does not exist");

        string memory name = string(abi.encodePacked("Quality Cert NFT #", Strings.toString(tokenId)));
        bytes memory json = abi.encodePacked(
            '{"name":"',
            name,
            '",',
            '"description":"Traceability Digital Product Passport for Quality Certificate.",',
            '"tokenType":"QualityCertificate",',
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
