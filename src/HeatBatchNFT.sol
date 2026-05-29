// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title HeatBatchNFT
 * @notice ERC-721 Digital Product Passport where each token represents one
 *         manufacturing Heat Number (batch). All process parameters, chemical
 *         composition, defect data, and quality scores are stored on-chain.
 *         Token metadata is generated as a base64-encoded JSON data URI —
 *         fully on-chain, no external IPFS dependency required.
 */
contract HeatBatchNFT is ERC721, AccessControl {

    /* ─────────────────────────────────────────────
       ROLES
    ───────────────────────────────────────────── */

    bytes32 public constant FOUNDRY_ROLE = keccak256("FOUNDRY_ROLE");
    bytes32 public constant ADMIN_ROLE   = keccak256("ADMIN_ROLE");

    /* ─────────────────────────────────────────────
       DATA STRUCTURES
    ───────────────────────────────────────────── */

    /**
     * @notice Manufacturing process parameters for a single heat batch.
     * @dev All temperatures in °C, pressures in bar, times in seconds/minutes.
     */
    struct ProcessParams {
        uint16 pouringTemp;       // °C  (e.g. 692)
        uint16 injectionPressure; // bar (e.g. 35)
        uint16 injectionTime;     // seconds (e.g. 30)
        uint8  humidity;          // % RH (e.g. 22)
        uint8  roomTemp;          // °C  (e.g. 25)
        uint16 processDuration;   // minutes (e.g. 45)
    }

    /**
     * @notice Chemical composition stored as integer × 100 to preserve 2 decimal places.
     * @dev  e.g. Si = 7.20% is stored as 720.  Decode: value / 100.0
     */
    struct ChemComposition {
        uint16 si;  // Silicon
        uint16 fe;  // Iron
        uint16 mn;  // Manganese
        uint16 mg;  // Magnesium
        uint16 cu;  // Copper
        uint16 zn;  // Zinc
        uint16 ti;  // Titanium
        uint16 al;  // Aluminium
    }

    /// @notice Boolean defect flags for the batch.
    struct DefectInfo {
        bool distortion;
        bool roughSurface;
        bool shrinkage;
        bool slagInclusion;
    }

    /// @notice Complete on-chain record for one manufacturing heat batch.
    struct HeatBatch {
        string          heatNo;
        uint256         mintTimestamp;
        string          manufacturer;
        ProcessParams   processParams;
        ChemComposition chemComp;
        DefectInfo      defects;
        uint8           qualityScore;   // 0-100
    }

    /* ─────────────────────────────────────────────
       STATE
    ───────────────────────────────────────────── */

    uint256 private _tokenIdCounter;

    /// @notice Full heat batch record keyed by token ID.
    mapping(uint256 => HeatBatch) private _batches;

    /// @notice Maps a heat number string to its token ID for O(1) lookup.
    mapping(string => uint256) public heatNoToTokenId;

    /// @notice Prevents duplicate heat numbers.
    mapping(string => bool) private _heatNoMinted;

    /// @notice Ordered list of all minted token IDs (for dashboard iteration).
    uint256[] private _allTokenIds;

    /* ─────────────────────────────────────────────
       EVENTS
    ───────────────────────────────────────────── */

    event HeatBatchMinted(
        uint256 indexed tokenId,
        string  heatNo,
        string  manufacturer,
        uint8   qualityScore,
        uint256 mintTimestamp
    );

    /* ─────────────────────────────────────────────
       CONSTRUCTOR
    ───────────────────────────────────────────── */

    constructor() ERC721("Heat Batch NFT", "HBNFT") {
        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE,   ADMIN_ROLE);
        _setRoleAdmin(FOUNDRY_ROLE, ADMIN_ROLE);
    }

    /* ─────────────────────────────────────────────
       MINTING
    ───────────────────────────────────────────── */

    /**
     * @notice Mints a new Heat Batch NFT with full manufacturing data stored on-chain.
     * @dev  Access: FOUNDRY_ROLE or ADMIN_ROLE.
     *       Chemical composition values must be passed as integer × 100
     *       (e.g., pass 720 for 7.20% Si).
     * @param to            Recipient of the NFT (usually the manufacturer's wallet).
     * @param heatNo        Unique heat/batch identifier string (e.g. "H001").
     * @param manufacturer  Name of the manufacturing facility.
     * @param pp            Process parameters struct.
     * @param cc            Chemical composition struct (values × 100).
     * @param di            Defect flags struct.
     * @param qualityScore  Overall batch quality score 0-100.
     * @return tokenId      The newly minted token ID.
     */
    function mintHeatBatch(
        address         to,
        string calldata heatNo,
        string calldata manufacturer,
        ProcessParams   calldata pp,
        ChemComposition calldata cc,
        DefectInfo      calldata di,
        uint8           qualityScore
    ) external returns (uint256 tokenId) {
        require(
            hasRole(FOUNDRY_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender),
            "Only FOUNDRY or ADMIN"
        );
        require(bytes(heatNo).length > 0,     "Heat number required");
        require(!_heatNoMinted[heatNo],       "Heat number already minted");
        require(qualityScore <= 100,          "Score must be 0-100");

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _safeMint(to, tokenId);

        _batches[tokenId] = HeatBatch({
            heatNo:        heatNo,
            mintTimestamp: block.timestamp,
            manufacturer:  manufacturer,
            processParams: pp,
            chemComp:      cc,
            defects:       di,
            qualityScore:  qualityScore
        });

        heatNoToTokenId[heatNo] = tokenId;
        _heatNoMinted[heatNo]   = true;
        _allTokenIds.push(tokenId);

        emit HeatBatchMinted(tokenId, heatNo, manufacturer, qualityScore, block.timestamp);
    }

    /* ─────────────────────────────────────────────
       VIEW FUNCTIONS
    ───────────────────────────────────────────── */

    /// @notice Returns the full HeatBatch record for a given token ID.
    function getHeatBatch(uint256 tokenId) external view returns (HeatBatch memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return _batches[tokenId];
    }

    /// @notice Looks up a token ID by heat number string. Returns 0 if not found.
    function getTokenIdByHeatNo(string calldata heatNo) external view returns (uint256) {
        return heatNoToTokenId[heatNo];
    }

    /// @notice Total number of Heat Batch NFTs minted.
    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /// @notice Returns true if the token has been minted.
    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /// @notice Returns the ordered array of all token IDs (for dashboard).
    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    /// @notice Returns the most recent N token IDs (for paginated dashboard).
    function getRecentTokenIds(uint256 count) external view returns (uint256[] memory) {
        uint256 total = _allTokenIds.length;
        uint256 n = count > total ? total : count;
        uint256[] memory result = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            result[i] = _allTokenIds[total - n + i];
        }
        return result;
    }

    /// @notice Role check helper for the frontend.
    function getRoles(address account) external view returns (bool foundry, bool admin) {
        return (hasRole(FOUNDRY_ROLE, account), hasRole(ADMIN_ROLE, account));
    }

    /* ─────────────────────────────────────────────
       ON-CHAIN TOKEN URI (base64 JSON)
    ───────────────────────────────────────────── */

    /**
     * @notice Generates a fully on-chain, base64-encoded JSON metadata URI.
     * @dev  No external IPFS call required — all data is read from contract storage.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        HeatBatch storage b = _batches[tokenId];

        bytes memory json = abi.encodePacked(
            '{"name":"Heat Batch #', b.heatNo, '",',
            '"description":"On-chain Manufacturing Traceability NFT - Heat Batch DPP",',
            '"heatNo":"', b.heatNo, '",',
            '"qualityScore":', Strings.toString(b.qualityScore), ',',
            '"manufacturer":"', b.manufacturer, '",',
            '"mintTimestamp":', Strings.toString(b.mintTimestamp), ',',
            _buildProcessParams(b.processParams),
            _buildChemComp(b.chemComp),
            _buildDefects(b.defects),
            '}'
        );

        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(json)
        ));
    }

    /* ─────────────────────────────────────────────
       INTERNAL — JSON BUILDERS
    ───────────────────────────────────────────── */

    function _buildProcessParams(ProcessParams storage pp) private view returns (bytes memory) {
        return abi.encodePacked(
            '"processParameters":{',
            '"pouringTemp":',       Strings.toString(pp.pouringTemp),       ',',
            '"injectionPressure":', Strings.toString(pp.injectionPressure), ',',
            '"injectionTime":',     Strings.toString(pp.injectionTime),     ',',
            '"humidity":',          Strings.toString(pp.humidity),          ',',
            '"roomTemp":',          Strings.toString(pp.roomTemp),          ',',
            '"processDuration":',   Strings.toString(pp.processDuration),
            '},'
        );
    }

    function _buildChemComp(ChemComposition storage cc) private view returns (bytes memory) {
        return abi.encodePacked(
            '"chemicalComposition":{',
            '"Si":', _dec2(cc.si), ',',
            '"Fe":', _dec2(cc.fe), ',',
            '"Mn":', _dec2(cc.mn), ',',
            '"Mg":', _dec2(cc.mg), ',',
            '"Cu":', _dec2(cc.cu), ',',
            '"Zn":', _dec2(cc.zn), ',',
            '"Ti":', _dec2(cc.ti), ',',
            '"Al":', _dec2(cc.al),
            '},'
        );
    }

    function _buildDefects(DefectInfo storage di) private view returns (bytes memory) {
        return abi.encodePacked(
            '"defects":{',
            '"distortion":',   di.distortion   ? 'true' : 'false', ',',
            '"roughSurface":', di.roughSurface  ? 'true' : 'false', ',',
            '"shrinkage":',    di.shrinkage     ? 'true' : 'false', ',',
            '"slagInclusion":', di.slagInclusion ? 'true' : 'false',
            '}'
        );
    }

    /**
     * @dev Converts an integer stored as value×100 to a decimal string with 2dp.
     *      e.g. 720  => "7.20"
     *           60   => "0.60"
     *           9876 => "98.76"
     */
    function _dec2(uint16 val) internal pure returns (string memory) {
        uint256 whole = val / 100;
        uint256 frac  = val % 100;
        string memory fracStr = frac < 10
            ? string(abi.encodePacked("0", Strings.toString(frac)))
            : Strings.toString(frac);
        return string(abi.encodePacked(Strings.toString(whole), ".", fracStr));
    }

    /* ─────────────────────────────────────────────
       ERC165 OVERRIDE
    ───────────────────────────────────────────── */

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
