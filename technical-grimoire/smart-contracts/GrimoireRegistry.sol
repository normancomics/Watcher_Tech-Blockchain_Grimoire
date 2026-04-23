// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GrimoireRegistry
 * @notice Main knowledge registry for the Watcher Tech Blockchain Grimoire
 * @dev Central registry contract that manages esoteric knowledge entries,
 *      access control, contributor reputation, and cross-references
 *      between knowledge domains.
 *
 * Architecture:
 *   - Knowledge entries are stored as IPFS CIDs (content-addressed)
 *   - Entries are categorized by esoteric domain
 *   - Access control is hierarchical (public / initiated / adept / master)
 *   - Contributors build reputation through peer review
 *   - Cross-references enable knowledge graph traversal
 *
 * Esoteric Domains:
 *   0: PrimordialTraditions  (Watchers, Atlantis, Vimana)
 *   1: NephilimRephaim       (Sacred geometry, giant tech)
 *   2: CanaaniteSevenSages   (Baal, Melchizedek, Seven Pillars)
 *   3: MysterySchools        (Hermetic, Pythagorean, Kabbalistic)
 *   4: ThirteenBloodlines    (Venetian, Templar, Rosicrucian)
 *   5: TechnicalGrimoire     (Algorithms, contracts, mathematics)
 *   6: SovereignAgents       (AI agent knowledge)
 */

// ─── Enums and Structs ────────────────────────────────────────────────────────

enum EsotericDomain {
    PrimordialTraditions,
    NephilimRephaim,
    CanaaniteSevenSages,
    MysterySchools,
    ThirteenBloodlines,
    TechnicalGrimoire,
    SovereignAgents
}

enum AccessLevel {
    Public,     // Anyone can read
    Initiated,  // Must hold Grimoire token
    Adept,      // Must have reputation >= 100
    Master      // Must be approved by Grand Council
}

struct KnowledgeEntry {
    uint256 id;
    string title;
    string ipfsCID;             // IPFS content hash (points to markdown/JSON)
    EsotericDomain domain;
    AccessLevel accessLevel;
    address contributor;
    uint256 timestamp;
    uint256 views;
    uint256 upvotes;
    uint256 downvotes;
    bool verified;              // Peer-reviewed and approved
    uint256[] crossReferences;  // IDs of related entries
}

struct Contributor {
    address addr;
    uint256 reputation;
    uint256 entriesSubmitted;
    uint256 entriesVerified;
    bool isMaster;
    bytes32 initiationHash;     // Hash of initiation ceremony
}

// ─── Main Registry Contract ───────────────────────────────────────────────────

contract GrimoireRegistry {
    
    // ─── Constants ────────────────────────────────────────────────────────────
    
    uint256 public constant ADEPT_REPUTATION_THRESHOLD = 100;
    uint256 public constant MASTER_REPUTATION_THRESHOLD = 500;
    uint256 public constant VERIFICATION_QUORUM = 3;    // 3 peer reviews needed
    uint256 public constant MAX_CROSS_REFERENCES = 20;
    
    // ─── State ────────────────────────────────────────────────────────────────
    
    mapping(uint256 => KnowledgeEntry) public entries;
    mapping(address => Contributor) public contributors;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => uint256) public verificationCount;
    mapping(EsotericDomain => uint256[]) public domainEntries;
    
    address[] public masterCouncil;
    uint256 public entryCount;
    address public owner;
    
    // ─── Events ───────────────────────────────────────────────────────────────
    
    event EntrySubmitted(
        uint256 indexed entryId,
        address indexed contributor,
        EsotericDomain domain,
        string title,
        string ipfsCID
    );
    
    event EntryVerified(
        uint256 indexed entryId,
        address indexed verifier,
        uint256 verificationCount
    );
    
    event EntryVoted(
        uint256 indexed entryId,
        address indexed voter,
        bool upvote
    );
    
    event ContributorInitiated(
        address indexed contributor,
        bytes32 initiationHash,
        uint256 timestamp
    );
    
    event MasterPromoted(
        address indexed contributor,
        uint256 reputation,
        uint256 timestamp
    );
    
    event CrossReferenceAdded(
        uint256 indexed entryId,
        uint256 indexed referencedEntryId
    );
    
    // ─── Constructor ──────────────────────────────────────────────────────────
    
    constructor() {
        owner = msg.sender;
        
        // Register deployer as first contributor and master
        contributors[msg.sender] = Contributor({
            addr: msg.sender,
            reputation: MASTER_REPUTATION_THRESHOLD,
            entriesSubmitted: 0,
            entriesVerified: 0,
            isMaster: true,
            initiationHash: keccak256(abi.encodePacked("GENESIS_INITIATION", msg.sender))
        });
        
        masterCouncil.push(msg.sender);
    }
    
    // ─── Initiation ───────────────────────────────────────────────────────────
    
    /**
     * @notice Initiate as a knowledge contributor
     * @dev Initiation hash proves commitment to the Grimoire's principles
     * @param initiationPhrase A secret phrase that proves esoteric knowledge
     */
    function initiate(string calldata initiationPhrase) external {
        require(contributors[msg.sender].addr == address(0), "Already initiated");
        
        bytes32 initiationHash = keccak256(
            abi.encodePacked(initiationPhrase, msg.sender, block.timestamp)
        );
        
        contributors[msg.sender] = Contributor({
            addr: msg.sender,
            reputation: 10,     // Starting reputation
            entriesSubmitted: 0,
            entriesVerified: 0,
            isMaster: false,
            initiationHash: initiationHash
        });
        
        emit ContributorInitiated(msg.sender, initiationHash, block.timestamp);
    }
    
    // ─── Knowledge Submission ─────────────────────────────────────────────────
    
    /**
     * @notice Submit a new knowledge entry to the Grimoire
     * @param title Human-readable title of the entry
     * @param ipfsCID IPFS content identifier (CIDv1 preferred)
     * @param domain Esoteric domain classification
     * @param accessLevel Required access level to read
     * @return entryId The assigned entry ID
     */
    function submitEntry(
        string calldata title,
        string calldata ipfsCID,
        EsotericDomain domain,
        AccessLevel accessLevel
    ) external returns (uint256 entryId) {
        require(contributors[msg.sender].addr != address(0), "Must be initiated");
        require(bytes(title).length > 0, "Title required");
        require(bytes(ipfsCID).length > 0, "IPFS CID required");
        
        entryId = ++entryCount;
        
        entries[entryId] = KnowledgeEntry({
            id: entryId,
            title: title,
            ipfsCID: ipfsCID,
            domain: domain,
            accessLevel: accessLevel,
            contributor: msg.sender,
            timestamp: block.timestamp,
            views: 0,
            upvotes: 0,
            downvotes: 0,
            verified: false,
            crossReferences: new uint256[](0)
        });
        
        domainEntries[domain].push(entryId);
        contributors[msg.sender].entriesSubmitted++;
        
        emit EntrySubmitted(entryId, msg.sender, domain, title, ipfsCID);
    }
    
    // ─── Peer Review / Verification ───────────────────────────────────────────
    
    /**
     * @notice Verify an entry as accurate and valuable
     * @dev Requires adept-level reputation; 3 verifications = auto-verify
     */
    function verifyEntry(uint256 entryId) external {
        Contributor storage reviewer = contributors[msg.sender];
        require(reviewer.reputation >= ADEPT_REPUTATION_THRESHOLD, "Insufficient reputation");
        require(!hasVoted[entryId][msg.sender], "Already reviewed this entry");
        require(entries[entryId].contributor != msg.sender, "Cannot verify own entry");
        
        hasVoted[entryId][msg.sender] = true;
        verificationCount[entryId]++;
        reviewer.entriesVerified++;
        reviewer.reputation += 5;  // Reward for peer review
        
        if (verificationCount[entryId] >= VERIFICATION_QUORUM) {
            entries[entryId].verified = true;
            // Reward the original contributor
            contributors[entries[entryId].contributor].reputation += 20;
        }
        
        emit EntryVerified(entryId, msg.sender, verificationCount[entryId]);
    }
    
    // ─── Voting ───────────────────────────────────────────────────────────────
    
    /**
     * @notice Vote on entry quality (upvote or downvote)
     */
    function voteOnEntry(uint256 entryId, bool upvote) external {
        require(contributors[msg.sender].addr != address(0), "Must be initiated");
        require(!hasVoted[entryId][msg.sender], "Already voted");
        require(entries[entryId].contributor != msg.sender, "Cannot vote on own entry");
        
        hasVoted[entryId][msg.sender] = true;
        
        if (upvote) {
            entries[entryId].upvotes++;
            contributors[entries[entryId].contributor].reputation += 1;
        } else {
            entries[entryId].downvotes++;
            if (contributors[entries[entryId].contributor].reputation > 0) {
                contributors[entries[entryId].contributor].reputation--;
            }
        }
        
        emit EntryVoted(entryId, msg.sender, upvote);
    }
    
    // ─── Cross-References ─────────────────────────────────────────────────────
    
    /**
     * @notice Add a cross-reference between knowledge entries
     */
    function addCrossReference(
        uint256 entryId, 
        uint256 referencedEntryId
    ) external {
        require(entries[entryId].contributor == msg.sender, "Only contributor can cross-reference");
        require(entries[referencedEntryId].id != 0, "Referenced entry does not exist");
        require(
            entries[entryId].crossReferences.length < MAX_CROSS_REFERENCES,
            "Max cross-references reached"
        );
        
        entries[entryId].crossReferences.push(referencedEntryId);
        emit CrossReferenceAdded(entryId, referencedEntryId);
    }
    
    // ─── Master Council ───────────────────────────────────────────────────────
    
    /**
     * @notice Promote an adept to master status
     * @dev Only existing masters can promote; requires threshold reputation
     */
    function promoteMaster(address candidate) external {
        require(contributors[msg.sender].isMaster, "Only masters can promote");
        
        Contributor storage contrib = contributors[candidate];
        require(contrib.reputation >= MASTER_REPUTATION_THRESHOLD, "Insufficient reputation");
        require(!contrib.isMaster, "Already a master");
        
        contrib.isMaster = true;
        masterCouncil.push(candidate);
        
        emit MasterPromoted(candidate, contrib.reputation, block.timestamp);
    }
    
    // ─── View Functions ───────────────────────────────────────────────────────
    
    /**
     * @notice Get entries for a specific domain
     */
    function getDomainEntries(
        EsotericDomain domain
    ) external view returns (uint256[] memory) {
        return domainEntries[domain];
    }
    
    /**
     * @notice Get cross-references for an entry
     */
    function getCrossReferences(
        uint256 entryId
    ) external view returns (uint256[] memory) {
        return entries[entryId].crossReferences;
    }
    
    /**
     * @notice Check if an address has access to an entry
     */
    function hasAccess(
        address reader,
        uint256 entryId,
        bool holdsGrimoireToken
    ) external view returns (bool) {
        KnowledgeEntry storage entry = entries[entryId];
        AccessLevel level = entry.accessLevel;
        
        if (level == AccessLevel.Public) return true;
        if (level == AccessLevel.Initiated) return holdsGrimoireToken;
        if (level == AccessLevel.Adept) {
            return contributors[reader].reputation >= ADEPT_REPUTATION_THRESHOLD;
        }
        if (level == AccessLevel.Master) return contributors[reader].isMaster;
        
        return false;
    }
    
    /**
     * @notice Get registry statistics
     */
    function getStats() external view returns (
        uint256 totalEntries,
        uint256 verifiedEntries,
        uint256 totalContributors,
        uint256 masterCount
    ) {
        uint256 verified = 0;
        for (uint256 i = 1; i <= entryCount; i++) {
            if (entries[i].verified) verified++;
        }
        
        return (entryCount, verified, 0, masterCouncil.length);
    }
}
