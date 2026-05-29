// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ProductNFT} from "./ProductNFT.sol";

contract BusinessNFT is ERC721, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant COMMERCIAL_ROLE = keccak256("COMMERCIAL_ROLE");

    struct BusinessData {
        string customerOrder;
        string invoice;
        uint256 revenue;
        uint256 dispatchDate;
        string supplyChainTrace;
        uint256 productId;
    }

    ProductNFT public immutable productContract;

    uint256 private _tokenIdCounter;
    mapping(uint256 => BusinessData) private _businesses;
    mapping(uint256 => string) private _tokenURIs;
    uint256[] private _allTokenIds;

    event BusinessMinted(uint256 indexed tokenId, address indexed owner);

    constructor(address productAddr) ERC721("Business Value DPP NFT", "BSDPP") {
        require(productAddr != address(0), "Invalid Product address");
        productContract = ProductNFT(productAddr);

        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(COMMERCIAL_ROLE, ADMIN_ROLE);
    }

    function mint(address to, BusinessData calldata data, string calldata uri) external returns (uint256 tokenId) {
        require(hasRole(COMMERCIAL_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only COMMERCIAL or ADMIN");
        if (data.productId > 0) {
            require(productContract.exists(data.productId), "Linked Product does not exist");
        }

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);
        _businesses[tokenId] = data;
        _tokenURIs[tokenId] = uri;
        _allTokenIds.push(tokenId);

        emit BusinessMinted(tokenId, to);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function getBusiness(uint256 tokenId) external view returns (BusinessData memory) {
        require(exists(tokenId), "Token does not exist");
        return _businesses[tokenId];
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "Token does not exist");

        string memory name = string(abi.encodePacked("Business Value NFT #", Strings.toString(tokenId)));
        bytes memory json = abi.encodePacked(
            '{"name":"',
            name,
            '",',
            '"description":"Traceability Digital Product Passport for Business Value.",',
            '"tokenType":"BusinessValue",',
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
