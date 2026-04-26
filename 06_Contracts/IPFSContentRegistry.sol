// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPFSContentRegistry
 * @author normancomics.eth — 2026 A.D.
 * @notice On-chain registry for IPFS/Arweave content with cryptographic
 *         proof of authority and immutability guarantees.
 *
 * Purpose
 * -------
 * The Grimoire stores its esoteric knowledge off-chain on IPFS (and optionally
 * Arweave for permanent storage). This contract acts as the immutable anchor —
 * binding content identifiers (CIDs / transaction IDs) to their authors and
 * providing on-chain proof that a specific piece of content existed at a given
 * block number and was attested by its author.
 *
 * Key features
 * ------------
 *   1. Content registration — any address can register a CID with metadata
 *   2. Proof of Authority  — author signs content off-chain; signature stored on-chain
 *   3. Immutability seal   — once sealed, a content record cannot be altered
 *   4. Arweave fallback    — optional permanent storage transaction ID
 *   5. Domain tagging      — mirrors GrimoireRegistry domains for cross-referencing
 *   6. Attestation voting  — community can attest that content is authentic
 *
 * Security
 * --------
 *   Signatures are ECDSA over keccak256(abi.encodePacked(cid, author, chainId)).
 *   This binds the proof to both the content *and* the chain, preventing replay
 *   attacks on other networks.
 */

// ─── Enums & Structs ──────────────────────────────────────────────────────────

enum ContentDomain {
    PrimordialTraditions,   // 0 — Watchers, Atlantis, Vimana
    NephilimRephaim,        // 1 — Sacred geometry, giant technology
    CanaaniteSevenSages,    // 2 — Baal, Melchizedek, Seven Pillars
    MysterySchools,         // 3 — Hermetic, Pythagorean, Kabbalistic
    ThirteenBloodlines,     // 4 — Venetian, Templar, Rosicrucian
    TechnicalGrimoire,      // 5 — Smart contracts, algorithms
    SovereignAgents         // 6 — AI agent knowledge and protocols
}

enum StorageLayer {
    IPFS,       // Content-addressed via IPFS CIDv1
    Arweave,    // Permanently stored on Arweave (by transaction ID)
    Both        // Mirrored on both IPFS and Arweave
}

struct ContentRecord {
    uint256 id;
    string  cid;              // IPFS CIDv1 (bafyb…) or Arweave TX ID
    string  arweaveTxId;      // Arweave transaction ID (empty if IPFS only)
    StorageLayer storageLayer;
    ContentDomain domain;
    address author;           // Ethereum address of the content author
    bytes32 contentHash;      // keccak256 of the raw content (for integrity checks)
    uint256 registeredAt;     // block.timestamp of registration
    uint256 blockNumber;      // block.number — immutable proof of existence
    bool    sealed;           // Once sealed, the record cannot be modified
    uint256 attestationCount; // Number of attestations from community
    uint256 grimoireEntryId;  // Optional link to GrimoireRegistry entry (0 = none)
}

struct AuthorityProof {
    address author;
    bytes   signature;        // ECDSA signature: sign(keccak256(cid ‖ author ‖ chainId))
    uint256 timestamp;
    bool    verified;         // True once signature has been verified on-chain
}

// ─── IPFSContentRegistry ──────────────────────────────────────────────────────

contract IPFSContentRegistry {

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant MAX_ATTESTATIONS_PER_ADDRESS = 1;
    uint256 public constant SEAL_ATTESTATION_THRESHOLD   = 5; // 5 attestations auto-seals

    // ─── State ────────────────────────────────────────────────────────────────

    mapping(uint256 => ContentRecord)  public contents;
    mapping(uint256 => AuthorityProof) public proofs;
    mapping(string  => uint256)        public cidToId;          // CID → content ID
    mapping(address => uint256[])      public authorContents;   // author → content IDs
    mapping(uint256 => ContentDomain)  public domainOf;
    mapping(ContentDomain => uint256[]) public domainContents;

    /// @dev attestations[contentId][attester] = true if already attested
    mapping(uint256 => mapping(address => bool)) public hasAttested;

    uint256 public contentCount;
    address public owner;

    // ─── Events ───────────────────────────────────────────────────────────────

    event ContentRegistered(
        uint256 indexed contentId,
        address indexed author,
        string          cid,
        ContentDomain   domain,
        StorageLayer    storageLayer,
        uint256         blockNumber
    );

    event ProofSubmitted(
        uint256 indexed contentId,
        address indexed author,
        bool            verified,
        uint256         timestamp
    );

    event ContentSealed(
        uint256 indexed contentId,
        address         sealedBy,
        uint256         timestamp
    );

    event ContentAttested(
        uint256 indexed contentId,
        address indexed attester,
        uint256         newCount
    );

    event ArweaveLinked(
        uint256 indexed contentId,
        string          arweaveTxId,
        uint256         timestamp
    );

    event GrimoireEntryLinked(
        uint256 indexed contentId,
        uint256 indexed grimoireEntryId
    );

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "IPFSContentRegistry: not owner");
        _;
    }

    modifier notSealed(uint256 contentId) {
        require(!contents[contentId].sealed, "IPFSContentRegistry: content is sealed");
        _;
    }

    modifier exists(uint256 contentId) {
        require(contents[contentId].id != 0, "IPFSContentRegistry: content not found");
        _;
    }

    // ─── Content Registration ─────────────────────────────────────────────────

    /**
     * @notice Register an IPFS (or Arweave) content identifier on-chain.
     * @dev Creates an immutable proof-of-existence record anchored to the
     *      current block number.
     *
     * @param cid          IPFS CIDv1 or Arweave TX ID of the content
     * @param contentHash  keccak256 hash of the raw content bytes (integrity proof)
     * @param domain       Esoteric domain classification
     * @param storageLayer Where the content is stored
     * @return contentId   The assigned content record identifier
     */
    function registerContent(
        string calldata cid,
        bytes32 contentHash,
        ContentDomain domain,
        StorageLayer storageLayer
    ) external returns (uint256 contentId) {
        require(bytes(cid).length > 0,     "IPFSContentRegistry: CID required");
        require(contentHash != bytes32(0), "IPFSContentRegistry: content hash required");
        require(cidToId[cid] == 0,         "IPFSContentRegistry: CID already registered");

        contentId = ++contentCount;

        contents[contentId] = ContentRecord({
            id:               contentId,
            cid:              cid,
            arweaveTxId:      "",
            storageLayer:     storageLayer,
            domain:           domain,
            author:           msg.sender,
            contentHash:      contentHash,
            registeredAt:     block.timestamp,
            blockNumber:      block.number,
            sealed:           false,
            attestationCount: 0,
            grimoireEntryId:  0
        });

        cidToId[cid] = contentId;
        authorContents[msg.sender].push(contentId);
        domainContents[domain].push(contentId);
        domainOf[contentId] = domain;

        emit ContentRegistered(
            contentId,
            msg.sender,
            cid,
            domain,
            storageLayer,
            block.number
        );
    }

    // ─── Proof of Authority ───────────────────────────────────────────────────

    /**
     * @notice Submit an ECDSA proof that the caller authored a piece of content.
     * @dev The signature must be over:
     *        keccak256(abi.encodePacked(cid, author, block.chainid))
     *      This binds the proof to both the content and the chain.
     *
     * @param contentId  The registered content record
     * @param signature  65-byte ECDSA signature from the author's key
     */
    function submitAuthorityProof(
        uint256 contentId,
        bytes calldata signature
    ) external exists(contentId) {
        ContentRecord storage record = contents[contentId];
        require(record.author == msg.sender, "IPFSContentRegistry: not the author");
        require(signature.length == 65,      "IPFSContentRegistry: invalid signature length");

        // Reconstruct the message the author should have signed
        bytes32 message = keccak256(
            abi.encodePacked(record.cid, msg.sender, block.chainid)
        );
        bytes32 ethMessage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        address recovered = _recoverSigner(ethMessage, signature);
        bool verified = (recovered == msg.sender);

        proofs[contentId] = AuthorityProof({
            author:    msg.sender,
            signature: signature,
            timestamp: block.timestamp,
            verified:  verified
        });

        emit ProofSubmitted(contentId, msg.sender, verified, block.timestamp);
    }

    // ─── Attestation ──────────────────────────────────────────────────────────

    /**
     * @notice Attest that a piece of content is authentic and valuable.
     * @dev Each address can attest to a given content record only once.
     *      When SEAL_ATTESTATION_THRESHOLD attestations are reached, the
     *      record is automatically sealed (immutable).
     *
     * @param contentId  The content record to attest to
     */
    function attestContent(uint256 contentId) external exists(contentId) {
        require(
            !hasAttested[contentId][msg.sender],
            "IPFSContentRegistry: already attested"
        );
        require(
            contents[contentId].author != msg.sender,
            "IPFSContentRegistry: cannot self-attest"
        );

        hasAttested[contentId][msg.sender] = true;
        contents[contentId].attestationCount++;

        emit ContentAttested(contentId, msg.sender, contents[contentId].attestationCount);

        // Auto-seal when threshold is met
        if (contents[contentId].attestationCount >= SEAL_ATTESTATION_THRESHOLD) {
            _seal(contentId, address(0));
        }
    }

    // ─── Sealing ──────────────────────────────────────────────────────────────

    /**
     * @notice Manually seal a content record to make it immutable.
     * @dev Only the author or the contract owner can seal a record.
     *      Once sealed the record cannot be updated (CID, hash, domain).
     *
     * @param contentId  The content record to seal
     */
    function sealContent(uint256 contentId)
        external
        exists(contentId)
        notSealed(contentId)
    {
        ContentRecord storage record = contents[contentId];
        require(
            msg.sender == record.author || msg.sender == owner,
            "IPFSContentRegistry: not author or owner"
        );

        _seal(contentId, msg.sender);
    }

    // ─── Arweave Integration ──────────────────────────────────────────────────

    /**
     * @notice Link an Arweave transaction ID to an existing content record.
     * @dev Upgrades the storage layer to Both (IPFS + Arweave) when called.
     *      Can only be called by the content author and only while unsealed.
     *
     * @param contentId    The registered content record
     * @param arweaveTxId  Arweave transaction ID (43-character base64url string)
     */
    function linkArweave(
        uint256 contentId,
        string calldata arweaveTxId
    ) external exists(contentId) notSealed(contentId) {
        ContentRecord storage record = contents[contentId];
        require(record.author == msg.sender, "IPFSContentRegistry: not the author");
        require(bytes(arweaveTxId).length > 0, "IPFSContentRegistry: TX ID required");

        record.arweaveTxId  = arweaveTxId;
        record.storageLayer = StorageLayer.Both;

        emit ArweaveLinked(contentId, arweaveTxId, block.timestamp);
    }

    // ─── GrimoireRegistry Cross-Reference ────────────────────────────────────

    /**
     * @notice Link an IPFS content record to a GrimoireRegistry entry.
     * @dev Creates a bidirectional cross-reference between the decentralised
     *      content and its on-chain Grimoire knowledge entry.
     *
     * @param contentId      The content record
     * @param grimoireEntryId  The corresponding GrimoireRegistry entry ID
     */
    function linkGrimoireEntry(
        uint256 contentId,
        uint256 grimoireEntryId
    ) external exists(contentId) {
        ContentRecord storage record = contents[contentId];
        require(record.author == msg.sender, "IPFSContentRegistry: not the author");
        require(grimoireEntryId > 0, "IPFSContentRegistry: invalid entry ID");

        record.grimoireEntryId = grimoireEntryId;

        emit GrimoireEntryLinked(contentId, grimoireEntryId);
    }

    /**
     * @notice Get a content record by its ID
     * @dev Explicit getter that returns the full ContentRecord struct.
     */
    function getContent(uint256 contentId) external view returns (ContentRecord memory) {
        require(contents[contentId].id != 0, "IPFSContentRegistry: content not found");
        return contents[contentId];
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    /**
     * @notice Get all content records registered by a specific author.
     */
    function getAuthorContents(address author) external view returns (uint256[] memory) {
        return authorContents[author];
    }

    /**
     * @notice Get all content records in a specific domain.
     */
    function getDomainContents(ContentDomain domain) external view returns (uint256[] memory) {
        return domainContents[domain];
    }

    /**
     * @notice Verify that a CID is registered and optionally sealed.
     * @param cid     The IPFS CID to look up
     * @return found  True if the CID is registered
     * @return id     The content record ID (0 if not found)
     * @return sealed True if the record has been sealed
     */
    function verifyCID(
        string calldata cid
    ) external view returns (bool found, uint256 id, bool sealed) {
        id = cidToId[cid];
        found = id != 0;
        sealed = found && contents[id].sealed;
    }

    /**
     * @notice Check whether the stored authority proof for a content record is valid.
     * @dev Returns false if no proof has been submitted yet.
     */
    function hasValidProof(uint256 contentId) external view returns (bool) {
        return proofs[contentId].verified;
    }

    /**
     * @notice Return registry statistics.
     */
    function getStats() external view returns (
        uint256 total,
        uint256 sealed,
        uint256 withProofs
    ) {
        for (uint256 i = 1; i <= contentCount; i++) {
            total++;
            if (contents[i].sealed)              sealed++;
            if (proofs[i].verified)              withProofs++;
        }
    }

    // ─── Internal Functions ───────────────────────────────────────────────────

    function _seal(uint256 contentId, address sealer) internal {
        contents[contentId].sealed = true;
        emit ContentSealed(contentId, sealer, block.timestamp);
    }

    function _recoverSigner(
        bytes32 messageHash,
        bytes calldata signature
    ) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8   v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        return ecrecover(messageHash, v, r, s);
    }
}
