// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ProcessNFT} from "./ProcessNFT.sol";

contract ProductNFT is ERC721, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OEM_ROLE = keccak256("OEM_ROLE");

    struct ProductData {
        string partName;
        string alloyGrade;
        string castingId;
        uint256 processId;
        string dppHash;
    }

    ProcessNFT public immutable processContract;

    uint256 private _tokenIdCounter;
    mapping(uint256 => ProductData) private _products;
    mapping(uint256 => string) private _tokenURIs;
    uint256[] private _allTokenIds;

    event ProductMinted(uint256 indexed tokenId, address indexed owner);

    constructor(address processAddr) ERC721("Product DPP NFT", "PDDPP") {
        require(processAddr != address(0), "Invalid Process address");
        processContract = ProcessNFT(processAddr);

        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OEM_ROLE, ADMIN_ROLE);
    }

    function mint(address to, ProductData calldata data, string calldata uri) external returns (uint256 tokenId) {
        require(hasRole(OEM_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only OEM or ADMIN");
        if (data.processId > 0) {
            require(processContract.exists(data.processId), "Linked Process does not exist");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _products[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit ProductMinted(tokenId, to);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function getProduct(uint256 tokenId) external view returns (ProductData memory) {
        require(exists(tokenId), "Token does not exist");
        return _products[tokenId];
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "Token does not exist");

        string memory name = string(abi.encodePacked("Product NFT #", Strings.toString(tokenId)));
        bytes memory json = abi.encodePacked(
            '{"name":"',
            name,
            '",',
            '"description":"Traceability Digital Product Passport for Product.",',
            '"tokenType":"Product",',
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
