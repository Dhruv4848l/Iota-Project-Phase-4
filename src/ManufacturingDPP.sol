// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ManufacturingDPP
 * @author IOTA DPP Development Team
 * @notice Digital Product Passport (DPP) ERC-721 contract tailored for an investment casting foundry supplying aerospace components (e.g., turbine blades)[cite: 2].
 *
 * @dev Implements a single reusable hierarchical contract for tracking all equipment and parts across the entire product lifecycle: Manufacturing → Supply Chain → Operation → Maintenance → End-of-Life[cite: 3].
 *
 * Key Architectural Features:
 * - Strict role-based access control (RBAC) ensuring data integrity at each lifecycle stage[cite: 4].
 * - Dynamic metadata management stored via IPFS, updatable by authorized stakeholders as the physical part moves through its lifecycle[cite: 4].
 * - Immutable on-chain audit trails via events integrated with IOTA Notarization hashes[cite: 4].
 */
contract ManufacturingDPP is ERC721, AccessControl {
    /* =============================================
       ROLES & ACCESS CONTROL DEFINITIONS
    ============================================= */

    /// @notice Core operational role for the investment casting foundry team, enabling initial manufacturing and inspection data entry[cite: 4].
    bytes32 public constant FOUNDRY_ROLE = keccak256("FOUNDRY_ROLE");

    /// @notice Role assigned to external machining and finishing vendors to update parts during the assembly phase[cite: 5].
    bytes32 public constant MACHINING_ROLE = keccak256("MACHINING_ROLE");

    /// @notice Role for the Original Equipment Manufacturer (OEM) or Aerospace manufacturer to manage integration and operational status[cite: 6].
    bytes32 public constant OEM_ROLE = keccak256("OEM_ROLE");

    /// @notice Role restricted to Maintenance, Repair & Overhaul (MRO) providers for logging repairs and end-of-life status[cite: 7].
    bytes32 public constant MRO_ROLE = keccak256("MRO_ROLE");

    /// @notice Super-admin role (typically the foundry owner or consortium admin) capable of assigning roles and overriding stage controls[cite: 8].
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /* =============================================
       HIERARCHY MAPPINGS
    ============================================= */

    /// @notice Maps a child part's token ID directly to its parent equipment's token ID (ChildrenID => ParentID)[cite: 9].
    mapping(uint256 => uint256) public parentOf;

    /// @notice Maintains a list of all child part token IDs associated with a parent equipment token ID (ParentID => uint256[childrenID])[cite: 10].
    mapping(uint256 => uint256[]) public childrenOf;

    /* =============================================
       METADATA STORAGE
    ============================================= */

    /// @notice Stores the current IPFS URI containing the token's dynamic JSON metadata[cite: 11].
    /// @dev This URI is designed to be intentionally mutable via `updateMetadata()` to reflect lifecycle progression, restricted by RBAC[cite: 11].
    mapping(uint256 => string) public tokenUris;

    /* =============================================
       LIFECYCLE TRACKING
    ============================================= */

    /// @notice Discrete lifecycle stages mapping to the overarching IIoT architecture diagram[cite: 12].
    enum LifecycleStage {
        ManufacturingAndInspection, // Foundry baseline creation
        AssemblyAndIntegration, // Machining and vendor integrations
        OperationAndUsage, // OEM deployment
        MaintenanceAndService, // MRO upkeep
        EndOfLifeAndRecycling // Decommissioning
    }

    /// @notice Tracks the current real-world lifecycle stage of each tokenized part/equipment[cite: 12].
    mapping(uint256 => LifecycleStage) public currentStage;

    /* =============================================
       EVENTS (ON-CHAIN AUDIT TRAIL)
    ============================================= */

    /**
     * @notice Emitted when physical ownership and custody of a DPP token is transferred between stakeholders[cite: 13, 14].
     * @param tokenId The ID of the equipment/part being transferred[cite: 13].
     * @param from The previous owner's wallet address[cite: 13].
     * @param to The new owner's wallet address[cite: 13].
     * @param newOwner A human-readable name or company identifier for the new owner[cite: 13].
     * @param notarizationHash The associated IOTA Notarization object ID / transaction hash providing immutable off-chain verification[cite: 13].
     */
    event OwnershipTransferred(
        uint256 indexed tokenId, address from, address to, string newOwner, bytes32 notarizationHash
    );

    /**
     * @notice Emitted to log maintenance, repair, or overhaul activities[cite: 15].
     * @param tokenId The ID of the serviced equipment/part[cite: 15].
     * @param details A description of the maintenance performed[cite: 15].
     * @param notarizationHash The IOTA Notarization hash verifying the maintenance record[cite: 15].
     */
    event MaintenanceLogged(uint256 indexed tokenId, string details, bytes32 notarizationHash);

    /**
     * @notice Emitted when critical certification documentation (e.g., NDT, QA, FAA) is attached to the part[cite: 16].
     * @param tokenId The ID of the equipment/part[cite: 16].
     * @param certType The specific type of certification (e.g., "NDT", "X-Ray")[cite: 16].
     * @param documentHash The IPFS hash linking to the actual certification document[cite: 16].
     * @param notarizationHash The IOTA Notarization hash[cite: 16].
     */
    event CertificationAdded(uint256 indexed tokenId, string certType, string documentHash, bytes32 notarizationHash);

    /**
     * @notice Emitted when a token's physical counterpart advances to a new lifecycle stage[cite: 17].
     * @param tokenId The ID of the equipment/part[cite: 17].
     * @param newStage The newly updated lifecycle stage[cite: 17].
     * @param notarizationHash The IOTA Notarization hash[cite: 17].
     */
    event LifecycleStageUpdated(uint256 indexed tokenId, LifecycleStage newStage, bytes32 notarizationHash);

    /**
     * @notice Emitted when a specific manufacturing or casting process step is completed and recorded[cite: 18].
     * @param tokenId The ID of the equipment/part being cast[cite: 18].
     * @param step The specific process step name (e.g., "Wax Pattern Creation")[cite: 18].
     * @param details The parameters, results, or tolerances of the completed step[cite: 18].
     * @param notarizationHash The IOTA Notarization hash[cite: 18].
     */
    event ProcessStepRecorded(uint256 indexed tokenId, string step, string details, bytes32 notarizationHash);

    /**
     * @notice Emitted whenever the dynamic metadata (IPFS URI) for a token is refreshed[cite: 19].
     * @param tokenId The ID of the equipment/part[cite: 19].
     * @param newURI The updated IPFS URI pointing to the fresh JSON metadata[cite: 19].
     * @param notarizationHash The IOTA Notarization hash[cite: 19].
     */
    event MetadataUpdated(uint256 indexed tokenId, string newURI, bytes32 notarizationHash);

    /* =============================================
       MODIFIERS
    ============================================= */

    /// @notice Restricts execution to any wallet holding at least one operational role (FOUNDRY, MACHINING, OEM, MRO, or ADMIN)[cite: 20].
    modifier onlyAuthorized() {
        _onlyAuthorized();
        _;
    }

    /// @notice Ensures the requested token ID has been minted and currently exists[cite: 21, 22].
    modifier tokenExists(uint256 tokenId) {
        _tokenExists(tokenId);
        _;
    }

    function _tokenExists(uint256 tokenId) private view {
        require(exists(tokenId), "Token does not exist");
    }

    function _onlyAuthorized() private view {
        require(
            hasRole(FOUNDRY_ROLE, msg.sender) || hasRole(MACHINING_ROLE, msg.sender) || hasRole(OEM_ROLE, msg.sender)
                || hasRole(MRO_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender),
            "Unauthorized"
        );
    }

    /* =============================================
       CONSTRUCTOR
    ============================================= */

    /**
     * @notice Initializes the ERC721 token and configures the role hierarchy[cite: 24].
     * @dev Sets up the initial RBAC state:
     * - Grants `ADMIN_ROLE` to the contract deployer[cite: 24].
     * - Designates `ADMIN_ROLE` as the administrator for all other roles (including itself), enabling admins to grant/revoke permissions[cite: 25, 26].
     */
    constructor() ERC721("IOTA Manufacturing DPP", "DPP") {
        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(FOUNDRY_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MACHINING_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OEM_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MRO_ROLE, ADMIN_ROLE);
    }

    /* =============================================
       MINTING FUNCTIONS
    ============================================= */

    /**
     * @notice Mints the main, top-level equipment token (e.g., an assembled turbine engine or primary blade)[cite: 26].
     * @dev Access: Caller MUST possess the `ADMIN_ROLE`[cite: 26].
     * State Changes:
     * - Initializes the token with the provided URI[cite: 27].
     * - Defaults the lifecycle stage to `ManufacturingAndInspection`[cite: 27].
     * @param to The address that will receive initial ownership of the token[cite: 26].
     * @param equipmentId The unique token ID to assign to this equipment[cite: 26].
     * @param initialURI The IPFS URI containing the initial JSON metadata payload[cite: 26].
     */
    function mintEquipment(address to, uint256 equipmentId, string calldata initialURI) external onlyRole(ADMIN_ROLE) {
        _safeMint(to, equipmentId);
        tokenUris[equipmentId] = initialURI;
        currentStage[equipmentId] = LifecycleStage.ManufacturingAndInspection;
    }

    /**
     * @notice Mints a sub-part token and explicitly links it to an existing parent equipment token to create a hierarchy[cite: 28].
     * @dev Access: Caller MUST possess the `ADMIN_ROLE`[cite: 29].
     * Requirements: The parent `equipmentId` MUST already exist[cite: 29].
     * @param to The address that will receive initial ownership of the sub-part token[cite: 28].
     * @param partId The unique token ID for the new part[cite: 28].
     * @param equipmentId The parent equipment token ID this part belongs to[cite: 28].
     * @param initialURI The IPFS URI containing the part's JSON metadata payload[cite: 28].
     */
    function mintPart(address to, uint256 partId, uint256 equipmentId, string calldata initialURI)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(exists(equipmentId), "Equipment must exist");
        _safeMint(to, partId);
        tokenUris[partId] = initialURI;
        parentOf[partId] = equipmentId;
        childrenOf[equipmentId].push(partId);
    }

    /* =============================================
       CORE LIFECYCLE FUNCTIONS
    ============================================= */

    /**
     * @notice Updates the token's dynamic metadata to reflect physical changes, verified by a notarization hash[cite: 31].
     * @dev Access: Highly restricted based on the token's `currentStage`[cite: 32]:
     * - `ManufacturingAndInspection`: Requires `FOUNDRY_ROLE` or `ADMIN_ROLE`[cite: 32].
     * - `AssemblyAndIntegration`: Requires `MACHINING_ROLE` or `ADMIN_ROLE`[cite: 33].
     * - `OperationAndUsage`: Requires `OEM_ROLE` or `ADMIN_ROLE`[cite: 34].
     * - `MaintenanceAndService` / `EndOfLifeAndRecycling`: Requires `MRO_ROLE` or `ADMIN_ROLE`[cite: 35].
     * @param tokenId The ID of the token to update[cite: 31].
     * @param newURI The new IPFS URI containing the updated JSON metadata[cite: 31].
     * @param notarizationHash The IOTA Notarization hash confirming the update off-chain[cite: 31].
     */
    function updateMetadata(uint256 tokenId, string calldata newURI, bytes32 notarizationHash)
        external
        tokenExists(tokenId)
    {
        LifecycleStage stage = currentStage[tokenId];
        bool isAdmin = hasRole(ADMIN_ROLE, msg.sender);

        if (stage == LifecycleStage.ManufacturingAndInspection) {
            require(isAdmin || hasRole(FOUNDRY_ROLE, msg.sender), "Only FOUNDRY or ADMIN");
        } else if (stage == LifecycleStage.AssemblyAndIntegration) {
            require(isAdmin || hasRole(MACHINING_ROLE, msg.sender), "Only MACHINING or ADMIN");
        } else if (stage == LifecycleStage.OperationAndUsage) {
            require(isAdmin || hasRole(OEM_ROLE, msg.sender), "Only OEM or ADMIN");
        } else if (stage == LifecycleStage.MaintenanceAndService || stage == LifecycleStage.EndOfLifeAndRecycling) {
            require(isAdmin || hasRole(MRO_ROLE, msg.sender), "Only MRO or ADMIN");
        }

        tokenUris[tokenId] = newURI;
        emit MetadataUpdated(tokenId, newURI, notarizationHash);
    }

    /**
     * @notice Facilitates the transfer of physical custody and on-chain ownership between supply chain stakeholders[cite: 37].
     * @dev Access: Caller MUST be the current `ownerOf(tokenId)`[cite: 38].
     * @param tokenId The ID of the token being transferred[cite: 37].
     * @param to The target address receiving the token[cite: 37].
     * @param newOwner The human-readable entity name of the new owner[cite: 37].
     * @param notarizationHash The IOTA Notarization hash linking the physical custody transfer[cite: 37].
     */
    function recordOwnershipTransfer(uint256 tokenId, address to, string calldata newOwner, bytes32 notarizationHash)
        external
        tokenExists(tokenId)
    {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(to != address(0), "Cannot transfer to zero address");
        _transfer(msg.sender, to, tokenId);
        emit OwnershipTransferred(tokenId, msg.sender, to, newOwner, notarizationHash);
    }

    /**
     * @notice Appends a permanent record of maintenance or repair activities for a given part[cite: 39].
     * @dev Access: Caller MUST possess the `MRO_ROLE`[cite: 39].
     * @param tokenId The ID of the token being serviced[cite: 39].
     * @param details A textual description of the maintenance procedure[cite: 39].
     * @param notarizationHash The IOTA Notarization hash of the maintenance log[cite: 39].
     */
    function recordMaintenance(uint256 tokenId, string calldata details, bytes32 notarizationHash)
        external
        onlyRole(MRO_ROLE)
        tokenExists(tokenId)
    {
        emit MaintenanceLogged(tokenId, details, notarizationHash);
    }

    /**
     * @notice Attaches critical compliance and testing documentation (e.g., Non-Destructive Testing) to the passport[cite: 41].
     * @dev Access: Caller MUST possess at least one operational role (`onlyAuthorized` modifier)[cite: 42].
     * @param tokenId The ID of the token receiving the certification[cite: 41].
     * @param certType The type classification of the document[cite: 41].
     * @param documentHash The IPFS hash serving as an immutable pointer to the document[cite: 41].
     * @param notarizationHash The IOTA Notarization hash verifying the document's authenticity[cite: 41].
     */
    function addCertification(
        uint256 tokenId,
        string calldata certType,
        string calldata documentHash,
        bytes32 notarizationHash
    ) external onlyAuthorized tokenExists(tokenId) {
        emit CertificationAdded(tokenId, certType, documentHash, notarizationHash);
    }

    /**
     * @notice Transitions the token into a new lifecycle stage as the physical part moves through the supply chain[cite: 43].
     * @dev Access: Highly restricted based on the token's current, active stage[cite: 44]:
     * - Moving FROM `ManufacturingAndInspection`: Requires `FOUNDRY_ROLE`, `MACHINING_ROLE`, or `ADMIN_ROLE`[cite: 45].
     * - Moving FROM `AssemblyAndIntegration`: Requires `OEM_ROLE` or `ADMIN_ROLE`[cite: 46].
     * - Moving FROM `OperationAndUsage`: Requires `OEM_ROLE`, `MRO_ROLE`, or `ADMIN_ROLE`[cite: 47].
     * - Moving FROM `MaintenanceAndService` / `EndOfLifeAndRecycling`: Requires `MRO_ROLE` or `ADMIN_ROLE`[cite: 48].
     * @param tokenId The ID of the token to transition[cite: 43].
     * @param newStage The designated target `LifecycleStage`[cite: 43].
     * @param notarizationHash The IOTA Notarization hash validating the stage transition[cite: 43].
     */
    function updateLifecycleStage(uint256 tokenId, LifecycleStage newStage, bytes32 notarizationHash)
        external
        tokenExists(tokenId)
    {
        LifecycleStage current = currentStage[tokenId];
        require(newStage != current, "Already at this stage");
        bool isAdmin = hasRole(ADMIN_ROLE, msg.sender);

        if (current == LifecycleStage.ManufacturingAndInspection) {
            require(
                isAdmin || hasRole(FOUNDRY_ROLE, msg.sender) || hasRole(MACHINING_ROLE, msg.sender),
                "Only FOUNDRY, MACHINING or ADMIN"
            );
        } else if (current == LifecycleStage.AssemblyAndIntegration) {
            require(isAdmin || hasRole(OEM_ROLE, msg.sender), "Only OEM or ADMIN");
        } else if (current == LifecycleStage.OperationAndUsage) {
            require(isAdmin || hasRole(OEM_ROLE, msg.sender) || hasRole(MRO_ROLE, msg.sender), "Only OEM, MRO or ADMIN");
        } else if (current == LifecycleStage.MaintenanceAndService || current == LifecycleStage.EndOfLifeAndRecycling) {
            require(isAdmin || hasRole(MRO_ROLE, msg.sender), "Only MRO or ADMIN");
        }

        currentStage[tokenId] = newStage;
        emit LifecycleStageUpdated(tokenId, newStage, notarizationHash);
    }

    /**
     * @notice Immutably logs specific manufacturing events executed at the foundry level[cite: 50].
     * @dev Access: Caller MUST possess the `FOUNDRY_ROLE`[cite: 50].
     * @param tokenId The ID of the token undergoing the process[cite: 50].
     * @param step The descriptive name of the process step[cite: 50].
     * @param details Process parameters, constraints, or logged results[cite: 50].
     * @param notarizationHash The IOTA Notarization hash validating the machine telemetry off-chain[cite: 50].
     */
    function recordProcessStep(uint256 tokenId, string calldata step, string calldata details, bytes32 notarizationHash)
        external
        onlyRole(FOUNDRY_ROLE)
        tokenExists(tokenId)
    {
        emit ProcessStepRecorded(tokenId, step, details, notarizationHash);
    }

    /* =============================================
       VIEW FUNCTIONS
    ============================================= */

    /**
     * @notice Determines if a given token ID has been minted and exists on-chain[cite: 52].
     * @param tokenId The unique token ID to query[cite: 52].
     * @return true if the token is currently allocated to an owner (address is not zero)[cite: 52].
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @notice Retrieves the entire array of child part token IDs nested under a parent equipment token[cite: 53].
     * @param equipmentId The parent equipment token ID[cite: 53].
     * @return An array of `uint256` token IDs representing the child components[cite: 53].
     */
    function getChildren(uint256 equipmentId) external view returns (uint256[] memory) {
        return childrenOf[equipmentId];
    }

    /**
     * @notice Counts the total number of sub-parts directly linked to a parent equipment token[cite: 54].
     * @param equipmentId The parent equipment token ID[cite: 54].
     * @return The total length of the child array[cite: 54].
     */
    function getChildCount(uint256 equipmentId) external view returns (uint256) {
        return childrenOf[equipmentId].length;
    }

    /**
     * @notice Audits all access control roles currently assigned to a specific wallet address[cite: 55].
     * @param account The wallet address to inspect[cite: 55].
     * @return foundry Boolean indicating if the address holds the `FOUNDRY_ROLE`[cite: 55].
     * @return machining Boolean indicating if the address holds the `MACHINING_ROLE`[cite: 55].
     * @return oem Boolean indicating if the address holds the `OEM_ROLE`[cite: 55].
     * @return mro Boolean indicating if the address holds the `MRO_ROLE`[cite: 55].
     * @return admin Boolean indicating if the address holds the `ADMIN_ROLE`[cite: 55].
     */
    function getRoles(address account)
        external
        view
        returns (bool foundry, bool machining, bool oem, bool mro, bool admin)
    {
        return (
            hasRole(FOUNDRY_ROLE, account),
            hasRole(MACHINING_ROLE, account),
            hasRole(OEM_ROLE, account),
            hasRole(MRO_ROLE, account),
            hasRole(ADMIN_ROLE, account)
        );
    }

    /**
     * @notice Provides a comprehensive state snapshot for a specific token in a single query[cite: 58].
     * @dev Reverts if the `tokenId` does not exist[cite: 59].
     * @param tokenId The ID of the token to inspect[cite: 58].
     * @return owner The wallet address of the current token holder[cite: 58].
     * @return stage The token's current `LifecycleStage`[cite: 58].
     * @return uri The current IPFS URI housing the dynamic metadata[cite: 58].
     * @return parent The token ID of the parent equipment (returns `0` if it is a root token)[cite: 58].
     * @return childCount The integer sum of nested child parts[cite: 58].
     */
    function getTokenInfo(uint256 tokenId)
        external
        view
        returns (address owner, LifecycleStage stage, string memory uri, uint256 parent, uint256 childCount)
    {
        require(exists(tokenId), "Token does not exist");
        return
            (ownerOf(tokenId), currentStage[tokenId], tokenUris[tokenId], parentOf[tokenId], childrenOf[tokenId].length);
    }

    /* =============================================
       ERC721 OVERRIDES
    ============================================= */

    /**
     * @notice Standard ERC721 override to fetch the token's metadata location[cite: 61].
     * @dev Reverts if the token has not been minted[cite: 61].
     * @param tokenId The ID of the queried token[cite: 61].
     * @return The IPFS string URI mapped to `tokenUris[tokenId]`[cite: 61].
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "Token does not exist");
        return tokenUris[tokenId];
    }

    /**
     * @notice Standard override to declare support for integrated interfaces (ERC721 and AccessControl)[cite: 62].
     * @param interfaceId The interface identifier to verify[cite: 62].
     * @return true if the requested interface is supported by the contract[cite: 62].
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
