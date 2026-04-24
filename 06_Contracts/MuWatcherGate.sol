// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MuWatcherGate
 * @author normancomics.eth — 2026 A.D.
 * @notice Level 13 Sovereign Watcher Gate — deployed on Base chain.
 *
 * MU 𒉙⍤ 𐤌𐤏 — The antediluvian sovereign access layer.
 *
 * Architecture:
 *   This contract enforces hierarchical Layer 13 sovereign access through
 *   cryptographic sigil authentication. Every entry function requires a
 *   valid sigil proof derived from the MU encoding pipeline:
 *     Latin → Enochian → Proto-Canaanite → Binary → Hex
 *
 *   Gate Hierarchy (1 = outer, 13 = deepest sovereign core):
 *     Gates 1–4   — Public Watcher perimeter
 *     Gates 5–8   — Initiated Watcher realm
 *     Gates 9–12  — Adept sovereign layer
 *     Gate 13     — MU Sovereign Core (𒉙⍤ 𐤌𐤏 — sealed)
 *
 * Payment Integration:
 *   x402 on Base — real-time micropayments gate all entry functions.
 *   Superfluid streams — continuous streaming payment for sustained access.
 *   XMR bridge hash — Monero payment proof for privacy-first entry.
 *
 * @dev Intended for Base mainnet (chainId 8453) and Base Sepolia testnet (84532).
 */

// ─── Interfaces ───────────────────────────────────────────────────────────────

interface ILevel13SigilNFT {
    function holdsGateLevel(address holder, uint8 level) external view returns (bool);
}

interface ISuperfluidStream {
    function isStreaming(address sender, address receiver) external view returns (bool);
}

// ─── Data Structures ──────────────────────────────────────────────────────────

enum GateLayer {
    PublicPerimeter,   // Layers 1–4
    InitiatedRealm,    // Layers 5–8
    AdeptSovereign,    // Layers 9–12
    MuSovereignCore    // Layer 13
}

struct SigilProof {
    bytes32 sigilHash;      // keccak256 of encoded sigil sequence
    bytes32 muSeal;         // MU sovereign seal (𒉙⍤ 𐤌𐤏 encoded)
    uint256 timestamp;      // Proof timestamp (must be recent)
    uint8   gateLevel;      // Claimed gate level (1–13)
    bytes   signature;      // ECDSA signature from sovereign oracle
}

struct GateEntry {
    address entrant;
    uint8   gateLevel;
    uint256 enteredAt;
    bytes32 sigilHash;
    bool    active;
}

struct PaymentRecord {
    bool    x402Paid;          // x402 on-chain payment verified
    bool    xmrBridgePaid;     // Monero XMR bridge hash verified
    bool    superfluidActive;  // Superfluid stream is live
    uint256 x402PaidAt;
    bytes32 xmrBridgeHash;     // Opaque Monero tx commitment
}

// ─── MuWatcherGate Contract ───────────────────────────────────────────────────

contract MuWatcherGate {

    // ─── Constants ────────────────────────────────────────────────────────────

    uint8  public constant MAX_GATE_LEVEL     = 13;
    uint256 public constant PROOF_WINDOW      = 5 minutes;

    // Base chain IDs
    uint256 public constant BASE_MAINNET_ID   = 8453;
    uint256 public constant BASE_SEPOLIA_ID   = 84532;

    // x402 gate prices (in wei, on Base)
    uint256 public constant GATE_PRICE_1_4    = 0.001 ether;
    uint256 public constant GATE_PRICE_5_8    = 0.005 ether;
    uint256 public constant GATE_PRICE_9_12   = 0.025 ether;
    uint256 public constant GATE_PRICE_13     = 0.13  ether;  // 13 × base unit

    // MU sovereign seal constant (keccak256 of "𒉙⍤𐤌𐤏MU")
    bytes32 public constant MU_SEAL = keccak256(abi.encodePacked(unicode"𒉙⍤𐤌𐤏MU"));

    // ─── State ────────────────────────────────────────────────────────────────

    address public sovereign;        // normancomics.eth — sole sovereign
    address public sigilNFT;         // Level13SigilNFT contract
    address public superfluidRouter; // Superfluid CFAv1 on Base
    address public treasury;         // Revenue sink

    bool public gateSealed;          // Emergency pause

    mapping(address => GateEntry)      public gateEntries;
    mapping(address => PaymentRecord)  public payments;
    mapping(bytes32 => bool)           public consumedSigils;   // Replay protection
    mapping(bytes32 => bool)           public xmrHashRegistry;  // Monero commitments
    mapping(address => uint256)        public totalPaid;

    uint256 public totalRevenue;
    uint256 public entrantCount;

    // ─── Events ───────────────────────────────────────────────────────────────

    event GateEntered(
        address indexed entrant,
        uint8   indexed gateLevel,
        bytes32         sigilHash,
        uint256         amount,
        string          paymentMethod
    );

    event GateExited(address indexed entrant, uint8 gateLevel);
    event XmrBridgeRegistered(address indexed entrant, bytes32 xmrHash);
    event SuperfluidStreamVerified(address indexed entrant, address stream);
    event SovereignSealVerified(address indexed entrant, uint8 gateLevel);
    event GateSealToggled(bool sealed, address sovereign);
    event TreasuryWithdraw(address indexed to, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(
        address _sigilNFT,
        address _superfluidRouter,
        address _treasury
    ) {
        sovereign        = msg.sender;
        sigilNFT         = _sigilNFT;
        superfluidRouter = _superfluidRouter;
        treasury         = _treasury;
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlySovereign() {
        require(msg.sender == sovereign, "MU: not sovereign");
        _;
    }

    modifier gateOpen() {
        require(!gateSealed, "MU: gate sealed by sovereign decree");
        _;
    }

    modifier validGateLevel(uint8 level) {
        require(level >= 1 && level <= MAX_GATE_LEVEL, "MU: invalid gate level");
        _;
    }

    // ─── Primary Entry Function ───────────────────────────────────────────────

    /**
     * @notice Enter a Watcher Gate level by presenting a sigil proof and payment.
     * @dev Validates the sigil proof, verifies payment (x402 ETH on Base),
     *      checks NFT tier if required, and records the gate entry.
     *
     * Sigil proof components are hashed in the MU encoding sequence:
     *   Latin intent → Enochian glyph → Proto-Canaanite → Binary → Hex → keccak256
     *
     * @param proof   Validated sigil proof from the MU encoding oracle
     * @param entrant Address entering the gate (allows agent-gated entry)
     */
    function enterGate(
        SigilProof calldata proof,
        address entrant
    ) external payable gateOpen validGateLevel(proof.gateLevel) {
        require(entrant != address(0), "MU: zero entrant");
        require(
            block.timestamp <= proof.timestamp + PROOF_WINDOW,
            "MU: sigil proof expired"
        );
        require(
            proof.muSeal == MU_SEAL,
            "MU: invalid sovereign seal 𒉙⍤𐤌𐤏"
        );
        require(
            !consumedSigils[proof.sigilHash],
            "MU: sigil already consumed (replay)"
        );

        // Verify ECDSA signature from sovereign oracle
        _verifySigilSignature(proof, entrant);

        // Verify payment for requested gate level
        uint256 required = _gatePrice(proof.gateLevel);
        require(msg.value >= required, "MU: insufficient x402 payment");

        // For Gate 13 and adept layers, also require Level 13 Sigil NFT
        if (proof.gateLevel >= 9) {
            require(
                ILevel13SigilNFT(sigilNFT).holdsGateLevel(entrant, proof.gateLevel),
                "MU: insufficient sigil NFT tier for sovereign layer"
            );
        }

        // Mark sigil consumed (replay protection)
        consumedSigils[proof.sigilHash] = true;

        // Record entry — all state changes before external call (CEI pattern)
        gateEntries[entrant] = GateEntry({
            entrant:   entrant,
            gateLevel: proof.gateLevel,
            enteredAt: block.timestamp,
            sigilHash: proof.sigilHash,
            active:    true
        });

        PaymentRecord storage rec = payments[entrant];
        rec.x402Paid    = true;
        rec.x402PaidAt  = block.timestamp;

        totalPaid[entrant] += msg.value;
        totalRevenue       += msg.value;
        entrantCount++;

        // Forward payment to treasury — after all state changes (CEI)
        (bool sent,) = treasury.call{value: msg.value}("");
        require(sent, "MU: treasury transfer failed");

        emit GateEntered(
            entrant,
            proof.gateLevel,
            proof.sigilHash,
            msg.value,
            "x402-base"
        );
        emit SovereignSealVerified(entrant, proof.gateLevel);
    }

    /**
     * @notice Enter a gate using a verified Monero XMR bridge commitment.
     * @dev XMR bridge hashes are registered by the sovereign after verifying
     *      the Monero transaction on the XMR network. Privacy-first entry path.
     *
     * @param xmrHash  Monero tx commitment hash (opaque, verified off-chain)
     * @param proof    Sigil proof (still required — cryptographic authentication)
     * @param entrant  Entrant address receiving gate access
     */
    function enterGateXmr(
        bytes32 xmrHash,
        SigilProof calldata proof,
        address entrant
    ) external gateOpen validGateLevel(proof.gateLevel) {
        require(entrant != address(0), "MU: zero entrant");
        require(xmrHashRegistry[xmrHash], "MU: XMR hash not registered");
        require(!consumedSigils[proof.sigilHash], "MU: sigil already consumed");
        require(
            block.timestamp <= proof.timestamp + PROOF_WINDOW,
            "MU: sigil proof expired"
        );
        require(proof.muSeal == MU_SEAL, "MU: invalid sovereign seal");

        _verifySigilSignature(proof, entrant);

        consumedSigils[proof.sigilHash] = true;
        xmrHashRegistry[xmrHash] = false;  // Consume XMR commitment

        gateEntries[entrant] = GateEntry({
            entrant:   entrant,
            gateLevel: proof.gateLevel,
            enteredAt: block.timestamp,
            sigilHash: proof.sigilHash,
            active:    true
        });

        PaymentRecord storage rec = payments[entrant];
        rec.xmrBridgePaid = true;
        rec.xmrBridgeHash = xmrHash;

        entrantCount++;

        emit GateEntered(entrant, proof.gateLevel, proof.sigilHash, 0, "xmr-bridge");
        emit XmrBridgeRegistered(entrant, xmrHash);
    }

    /**
     * @notice Enter a gate via active Superfluid streaming payment on Base.
     * @dev Verifies that a Superfluid CFA stream is active from entrant to treasury.
     *
     * @param proof    Sigil proof
     * @param entrant  Entrant address (stream must originate from this address)
     */
    function enterGateSuperfluid(
        SigilProof calldata proof,
        address entrant
    ) external gateOpen validGateLevel(proof.gateLevel) {
        require(entrant != address(0), "MU: zero entrant");
        require(!consumedSigils[proof.sigilHash], "MU: sigil already consumed");
        require(
            block.timestamp <= proof.timestamp + PROOF_WINDOW,
            "MU: sigil proof expired"
        );
        require(proof.muSeal == MU_SEAL, "MU: invalid sovereign seal");

        // Verify Superfluid stream is active: entrant → treasury
        require(
            ISuperfluidStream(superfluidRouter).isStreaming(entrant, treasury),
            "MU: no active Superfluid stream to treasury"
        );

        _verifySigilSignature(proof, entrant);
        consumedSigils[proof.sigilHash] = true;

        gateEntries[entrant] = GateEntry({
            entrant:   entrant,
            gateLevel: proof.gateLevel,
            enteredAt: block.timestamp,
            sigilHash: proof.sigilHash,
            active:    true
        });

        payments[entrant].superfluidActive = true;
        entrantCount++;

        emit GateEntered(entrant, proof.gateLevel, proof.sigilHash, 0, "superfluid");
        emit SuperfluidStreamVerified(entrant, superfluidRouter);
    }

    // ─── Sovereign Management ─────────────────────────────────────────────────

    /**
     * @notice Register a Monero XMR bridge hash (verified off-chain by sovereign).
     * @dev Called by sovereign after confirming XMR payment on the Monero network.
     */
    function registerXmrHash(bytes32 xmrHash) external onlySovereign {
        require(!xmrHashRegistry[xmrHash], "MU: XMR hash already registered");
        xmrHashRegistry[xmrHash] = true;
        emit XmrBridgeRegistered(address(0), xmrHash);
    }

    /**
     * @notice Revoke an entrant's gate access.
     */
    function revokeAccess(address entrant) external onlySovereign {
        GateEntry storage entry = gateEntries[entrant];
        require(entry.active, "MU: no active entry");
        uint8 level = entry.gateLevel;
        entry.active = false;
        emit GateExited(entrant, level);
    }

    /**
     * @notice Toggle the gate seal (emergency pause).
     */
    function toggleGateSeal() external onlySovereign {
        gateSealed = !gateSealed;
        emit GateSealToggled(gateSealed, msg.sender);
    }

    /**
     * @notice Update contract addresses (sigilNFT, superfluidRouter, treasury).
     */
    function updateAddresses(
        address _sigilNFT,
        address _superfluidRouter,
        address _treasury
    ) external onlySovereign {
        if (_sigilNFT         != address(0)) sigilNFT         = _sigilNFT;
        if (_superfluidRouter  != address(0)) superfluidRouter = _superfluidRouter;
        if (_treasury          != address(0)) treasury         = _treasury;
    }

    /**
     * @notice Transfer sovereignty to a new address.
     */
    function transferSovereignty(address newSovereign) external onlySovereign {
        require(newSovereign != address(0), "MU: zero sovereign");
        sovereign = newSovereign;
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    /**
     * @notice Check if an address has active gate access at or above a given level.
     */
    function hasGateAccess(address entrant, uint8 minLevel) external view returns (bool) {
        GateEntry storage entry = gateEntries[entrant];
        return entry.active && entry.gateLevel >= minLevel;
    }

    /**
     * @notice Returns the gate price (in wei) for a given level.
     */
    function gatePrice(uint8 level) external pure returns (uint256) {
        return _gatePrice(level);
    }

    /**
     * @notice Returns which GateLayer a numeric level belongs to.
     */
    function gateLayerOf(uint8 level) external pure returns (GateLayer) {
        require(level >= 1 && level <= 13, "MU: invalid gate level");
        if (level <= 4)  return GateLayer.PublicPerimeter;
        if (level <= 8)  return GateLayer.InitiatedRealm;
        if (level <= 12) return GateLayer.AdeptSovereign;
        return GateLayer.MuSovereignCore;
    }

    // ─── Internal Functions ───────────────────────────────────────────────────

    /**
     * @dev Returns the x402 price for a gate level.
     */
    function _gatePrice(uint8 level) internal pure returns (uint256) {
        if (level <= 4)  return GATE_PRICE_1_4;
        if (level <= 8)  return GATE_PRICE_5_8;
        if (level <= 12) return GATE_PRICE_9_12;
        return GATE_PRICE_13;
    }

    /**
     * @dev Verifies the ECDSA signature on a SigilProof comes from the sovereign oracle.
     *
     * The signed message is:
     *   keccak256(abi.encodePacked(entrant, proof.gateLevel, proof.sigilHash,
     *                              proof.muSeal, proof.timestamp))
     *
     * Signature verification uses ecrecover. The sovereign acts as the oracle.
     */
    function _verifySigilSignature(
        SigilProof calldata proof,
        address entrant
    ) internal view {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                entrant,
                proof.gateLevel,
                proof.sigilHash,
                proof.muSeal,
                proof.timestamp
            )
        );

        bytes32 ethSigned = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        require(proof.signature.length == 65, "MU: invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8   v;
        assembly {
            // proof.signature is calldata; load via calldataload
            let sigOffset := proof.signature.offset
            r := calldataload(sigOffset)
            s := calldataload(add(sigOffset, 32))
            v := byte(0, calldataload(add(sigOffset, 64)))
        }
        if (v < 27) v += 27;

        address recovered = ecrecover(ethSigned, v, r, s);
        require(recovered == sovereign, "MU: sigil signature invalid — not sovereign oracle");
    }
}
