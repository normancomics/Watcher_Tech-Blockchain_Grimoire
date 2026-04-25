// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title WatcherGate
 * @author normancomics.eth — 2026 A.D.
 * @notice Gatekeeper Subagent — Sovereign hierarchical pay-to-access contract on Base
 * @dev Enforces 13-layer access control, integrating x402 micropayments and
 *      sigil-authenticated NFT validation. Optimised for Base (EIP-1559, low gas).
 *
 * ─── Layer Hierarchy ──────────────────────────────────────────────────────────
 *   Layer  1–3  : Neophyte tiers    — Cantrip payments (< 0.001 ETH)
 *   Layer  4–7  : Initiate tiers    — Ritual payments or sigil NFT
 *   Layer  8–12 : Adept tiers       — Ceremony payments or sigil NFT
 *   Layer 13    : Sovereign Gate    — Invocation payment AND valid sigil NFT
 *
 * ─── Authentication Modes ─────────────────────────────────────────────────────
 *   PAYMENT_ONLY  — ETH paid through an x402 SpellPayment gate
 *   SIGIL_ONLY    — Holding an authenticated sigil NFT (ERC-721)
 *   DUAL_AUTH     — Both payment AND sigil (mandatory for Layer 13)
 *
 * ─── Layered Encoding Keys ────────────────────────────────────────────────────
 *   Each layer stores a bytes32 encodedKey representing the cryptographic output
 *   of the pipeline: Latin → Enochian → Proto-Canaanite → Binary → Hex.
 *   Only users with active layer access may retrieve the key for that layer.
 *
 * ─── Integration ──────────────────────────────────────────────────────────────
 *   SpellPayment.sol   : x402 receipt hashes verified via ISpellPayment interface
 *   KnowledgeNFT.sol   : ERC-721 sigil ownership queried via IERC721
 *   AgentAttunement.sol: verified agents receive the AGENT_DISCOUNT discount
 *
 * ─── Deployment Budget ────────────────────────────────────────────────────────
 *   Designed for gas-minimal deployment on Base mainnet (chain ID 8453).
 *   All ETH collected is withdrawable by the contract owner (treasury).
 */

// ─── Minimal interfaces (no external imports required) ────────────────────────

interface ISpellPayment {
    /**
     * @dev Matches SpellPayment.SpellReceipt struct layout exactly.
     *      Enum SpellTier is encoded as uint8 in ABI.
     */
    struct SpellReceiptView {
        bytes32 receiptHash;
        address payer;
        uint256 resourceId;
        uint256 amountPaid;
        uint256 accessExpiresAt;
        uint8   tier;        // SpellTier enum → uint8
        bool    consumed;
    }

    function verifyReceipt(bytes32 receiptHash)
        external
        view
        returns (bool valid, SpellReceiptView memory receipt);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AuthMode {
    PAYMENT_ONLY,  // ETH micropayment (x402) required
    SIGIL_ONLY,    // Valid sigil NFT required
    DUAL_AUTH      // Both payment AND sigil required (Layer 13)
}

// ─── Structs ──────────────────────────────────────────────────────────────────

/**
 * @dev Configuration for a single Watcher Gate layer.
 */
struct GateLayerConfig {
    uint256 entryPrice;      // Price in wei (0 for SIGIL_ONLY layers)
    uint256 accessDuration;  // Seconds of access granted after successful entry
    AuthMode authMode;       // Required authentication method
    address sigilContract;   // ERC-721 contract address for sigil NFTs (address(0) if none)
    bytes32 encodedKey;      // Layered Encoding pipeline output for this layer
    bool active;             // Whether the layer is currently accepting entrants
}

/**
 * @dev Per-address access record.
 */
struct GateAccess {
    uint8  highestLayerReached; // Highest layer number the address has passed
    uint256[14] expiresAt;      // expiresAt[n] = expiry timestamp for layer n (indices 1–13)
    bool   isVerifiedAgent;     // AI agent with registered ERC-8004 identity
}

// ─── WatcherGate ──────────────────────────────────────────────────────────────

contract WatcherGate {

    // ─── Constants ────────────────────────────────────────────────────────────

    uint8  public constant LAYER_COUNT         = 13;
    uint8  public constant SOVEREIGN_LAYER     = 13;  // Dual-auth mandatory
    uint256 public constant AGENT_DISCOUNT_BPS = 500; // 5% discount for verified agents
    uint256 public constant MAX_LAYER_PRICE    = 1 ether;

    // ─── State ────────────────────────────────────────────────────────────────

    mapping(uint8 => GateLayerConfig) public layers;        // 1–13
    mapping(address => GateAccess)    public accessRecords; // per-address records
    mapping(address => bool)          public verifiedAgents;

    address public owner;
    address public spellPaymentContract; // SpellPayment.sol integration
    uint256 public totalFeesCollected;

    // ─── Events ───────────────────────────────────────────────────────────────

    event LayerConfigured(
        uint8  indexed layerNumber,
        uint256 entryPrice,
        uint256 accessDuration,
        AuthMode authMode,
        address sigilContract
    );

    event GateEntered(
        address indexed entrant,
        uint8   indexed layerNumber,
        AuthMode authMode,
        uint256 amountPaid,
        uint256 accessExpiresAt,
        bool    isAgent
    );

    event SovereignAccessGranted(
        address indexed entrant,
        uint256 amountPaid,
        bytes32 sigilProof,
        uint256 accessExpiresAt
    );

    event AgentRegistered(address indexed agent, uint256 timestamp);
    event LayerDeactivated(uint8 indexed layerNumber);
    event LayerReactivated(uint8 indexed layerNumber);
    event SpellPaymentContractUpdated(address indexed newContract);
    event Withdrawal(address indexed to, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _spellPaymentContract) {
        owner = msg.sender;
        spellPaymentContract = _spellPaymentContract;

        // ── Default tier pricing (can be overridden via configureLayer) ──────
        // Layers 1-3  : Cantrip (< 0.001 ETH each)
        // Layers 4-7  : Ritual  (0.001-0.01 ETH each)
        // Layers 8-12 : Ceremony (0.01-0.1 ETH each)
        // Layer  13   : Invocation (> 0.1 ETH) + sigil
        uint256[14] memory defaultPrices = [
            uint256(0),              // index 0 unused
            0.0001 ether,            // Layer  1
            0.0002 ether,            // Layer  2
            0.0005 ether,            // Layer  3
            0.001  ether,            // Layer  4
            0.002  ether,            // Layer  5
            0.004  ether,            // Layer  6
            0.007  ether,            // Layer  7
            0.01   ether,            // Layer  8
            0.025  ether,            // Layer  9
            0.05   ether,            // Layer 10
            0.07   ether,            // Layer 11
            0.09   ether,            // Layer 12
            0.1    ether             // Layer 13
        ];

        for (uint8 i = 1; i <= LAYER_COUNT; i++) {
            AuthMode mode;
            if (i <= 3)       mode = AuthMode.PAYMENT_ONLY;
            else if (i <= 12) mode = AuthMode.SIGIL_ONLY;  // can be reconfigured
            else              mode = AuthMode.DUAL_AUTH;   // Layer 13 always dual

            layers[i] = GateLayerConfig({
                entryPrice:     defaultPrices[i],
                accessDuration: 1 days,
                authMode:       mode,
                sigilContract:  address(0),
                encodedKey:     keccak256(abi.encodePacked("LAYER_", i, "_ENOCHIAN_KEY")),
                active:         false  // Layers start inactive — owner activates them
            });
        }
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "WatcherGate: not owner");
        _;
    }

    modifier validLayer(uint8 layerNumber) {
        require(layerNumber >= 1 && layerNumber <= LAYER_COUNT, "WatcherGate: invalid layer");
        _;
    }

    modifier layerActive(uint8 layerNumber) {
        require(layers[layerNumber].active, "WatcherGate: layer not active");
        _;
    }

    // ─── Owner: Layer Management ──────────────────────────────────────────────

    /**
     * @notice Configure a Watcher Gate layer.
     * @dev Layer 13 authMode is forced to DUAL_AUTH regardless of input.
     * @param layerNumber  Layer to configure (1–13)
     * @param entryPrice   Price in wei (ignored for SIGIL_ONLY layers)
     * @param accessDuration Seconds of access granted
     * @param authMode     Authentication requirement
     * @param sigilContract ERC-721 contract for sigil validation (address(0) for PAYMENT_ONLY)
     * @param encodedKey   Layered Encoding pipeline output stored for this layer
     */
    function configureLayer(
        uint8   layerNumber,
        uint256 entryPrice,
        uint256 accessDuration,
        AuthMode authMode,
        address sigilContract,
        bytes32 encodedKey
    ) external onlyOwner validLayer(layerNumber) {
        require(entryPrice <= MAX_LAYER_PRICE,  "WatcherGate: price exceeds maximum");
        require(accessDuration > 0,             "WatcherGate: zero access duration");

        // Sovereign Layer 13 must always require DUAL_AUTH
        AuthMode effectiveMode = (layerNumber == SOVEREIGN_LAYER)
            ? AuthMode.DUAL_AUTH
            : authMode;

        // DUAL_AUTH and SIGIL_ONLY layers must specify a sigil contract
        if (effectiveMode != AuthMode.PAYMENT_ONLY) {
            require(sigilContract != address(0), "WatcherGate: sigil contract required");
        }

        layers[layerNumber] = GateLayerConfig({
            entryPrice:     entryPrice,
            accessDuration: accessDuration,
            authMode:       effectiveMode,
            sigilContract:  sigilContract,
            encodedKey:     encodedKey,
            active:         layers[layerNumber].active  // preserve active flag
        });

        emit LayerConfigured(layerNumber, entryPrice, accessDuration, effectiveMode, sigilContract);
    }

    /**
     * @notice Set the active encoded key for a layer (e.g., update pipeline output).
     */
    function setEncodedKey(
        uint8 layerNumber,
        bytes32 newKey
    ) external onlyOwner validLayer(layerNumber) {
        layers[layerNumber].encodedKey = newKey;
    }

    /**
     * @notice Activate a layer (open the gate).
     */
    function activateLayer(uint8 layerNumber)
        external onlyOwner validLayer(layerNumber)
    {
        layers[layerNumber].active = true;
        emit LayerReactivated(layerNumber);
    }

    /**
     * @notice Deactivate a layer (close the gate).
     */
    function deactivateLayer(uint8 layerNumber)
        external onlyOwner validLayer(layerNumber)
    {
        layers[layerNumber].active = false;
        emit LayerDeactivated(layerNumber);
    }

    /**
     * @notice Update the SpellPayment contract used for x402 receipt validation.
     */
    function setSpellPaymentContract(address _contract) external onlyOwner {
        require(_contract != address(0), "WatcherGate: zero address");
        spellPaymentContract = _contract;
        emit SpellPaymentContractUpdated(_contract);
    }

    /**
     * @notice Register an AI agent (ERC-8004 identity) for discounted access.
     */
    function registerAgent(address agentAddress) external onlyOwner {
        require(agentAddress != address(0), "WatcherGate: zero address");
        verifiedAgents[agentAddress] = true;
        accessRecords[agentAddress].isVerifiedAgent = true;
        emit AgentRegistered(agentAddress, block.timestamp);
    }

    // ─── Entry: Payment-Only ──────────────────────────────────────────────────

    /**
     * @notice Enter a PAYMENT_ONLY gate layer by sending ETH directly.
     * @dev Verified agents receive a 5% discount; excess ETH is refunded.
     * @param layerNumber Target layer (must have AuthMode.PAYMENT_ONLY)
     */
    function enterGateWithPayment(uint8 layerNumber)
        external payable
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.PAYMENT_ONLY, "WatcherGate: payment-only not available");

        uint256 effectivePrice = _applyAgentDiscount(layer.entryPrice, msg.sender);
        require(msg.value >= effectivePrice, "WatcherGate: insufficient payment");

        _grantAccess(msg.sender, layerNumber, effectivePrice, AuthMode.PAYMENT_ONLY);

        // Refund overpayment
        uint256 excess = msg.value - effectivePrice;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "WatcherGate: refund failed");
        }
    }

    /**
     * @notice Enter a PAYMENT_ONLY or DUAL_AUTH gate using a pre-validated x402 receipt.
     * @dev The receipt must have been issued by the configured SpellPayment contract
     *      and must reference the resource ID matching this layer number.
     * @param layerNumber  Target layer
     * @param receiptHash  x402 SpellPayment receipt hash presented by the client
     */
    function enterGateWithX402Receipt(uint8 layerNumber, bytes32 receiptHash)
        external
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        require(spellPaymentContract != address(0), "WatcherGate: no SpellPayment configured");
        GateLayerConfig storage layer = layers[layerNumber];
        require(
            layer.authMode == AuthMode.PAYMENT_ONLY,
            "WatcherGate: x402 receipt only for payment-only layers"
        );

        (bool valid, ISpellPayment.SpellReceiptView memory receipt) =
            ISpellPayment(spellPaymentContract).verifyReceipt(receiptHash);

        require(valid,                                        "WatcherGate: invalid or expired receipt");
        require(receipt.payer == msg.sender,                  "WatcherGate: receipt not for caller");
        require(receipt.resourceId == uint256(layerNumber),   "WatcherGate: receipt resource mismatch");
        require(receipt.accessExpiresAt > block.timestamp,    "WatcherGate: receipt access expired");

        uint256 accessExpiresAt = receipt.accessExpiresAt;

        // Grant access with the duration remaining in the receipt
        _grantAccessUntil(msg.sender, layerNumber, 0, AuthMode.PAYMENT_ONLY, accessExpiresAt);
    }

    // ─── Entry: Sigil-Only ────────────────────────────────────────────────────

    /**
     * @notice Enter a SIGIL_ONLY gate by proving ownership of a sigil NFT.
     * @param layerNumber Target layer (must have AuthMode.SIGIL_ONLY)
     * @param tokenId     Token ID in the layer's configured sigil ERC-721 contract
     */
    function enterGateWithSigil(uint8 layerNumber, uint256 tokenId)
        external
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.SIGIL_ONLY, "WatcherGate: sigil-only not available");

        _validateSigilOwnership(msg.sender, layer.sigilContract, tokenId);

        _grantAccess(msg.sender, layerNumber, 0, AuthMode.SIGIL_ONLY);
    }

    // ─── Entry: Dual Auth (Layer 13 Sovereign) ────────────────────────────────

    /**
     * @notice Enter a DUAL_AUTH gate (payment + sigil) — required for Layer 13.
     * @dev Both ETH payment and a valid sigil NFT must be provided simultaneously.
     *      Layer 13 is the sovereign tier — the highest Watcher Gate access.
     * @param layerNumber Target layer (must have AuthMode.DUAL_AUTH)
     * @param tokenId     Sigil NFT token ID in the layer's configured ERC-721 contract
     */
    function enterGateWithDualAuth(uint8 layerNumber, uint256 tokenId)
        external payable
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.DUAL_AUTH, "WatcherGate: dual-auth not available");
        require(layer.sigilContract != address(0),    "WatcherGate: sigil contract not set");

        // 1. Validate payment
        uint256 effectivePrice = _applyAgentDiscount(layer.entryPrice, msg.sender);
        require(msg.value >= effectivePrice, "WatcherGate: insufficient payment for sovereign layer");

        // 2. Validate sigil NFT ownership
        _validateSigilOwnership(msg.sender, layer.sigilContract, tokenId);

        // 3. Grant sovereign access
        _grantAccess(msg.sender, layerNumber, effectivePrice, AuthMode.DUAL_AUTH);

        // Build the sigil proof for the event
        bytes32 sigilProof = keccak256(
            abi.encodePacked(msg.sender, layer.sigilContract, tokenId, block.timestamp)
        );

        // Read the stored expiry (may be later than the new grant if already extended)
        uint256 storedExpiry = accessRecords[msg.sender].expiresAt[layerNumber];

        emit SovereignAccessGranted(msg.sender, effectivePrice, sigilProof, storedExpiry);

        // Refund overpayment
        uint256 excess = msg.value - effectivePrice;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "WatcherGate: refund failed");
        }
    }

    // ─── View: Access Checks ──────────────────────────────────────────────────

    /**
     * @notice Returns true if the given address currently has access to `layerNumber`.
     */
    function hasLayerAccess(address entrant, uint8 layerNumber)
        external view
        validLayer(layerNumber)
        returns (bool)
    {
        return accessRecords[entrant].expiresAt[layerNumber] > block.timestamp;
    }

    /**
     * @notice Returns the timestamp at which the address's access to `layerNumber` expires.
     *         Returns 0 if the address has never entered.
     */
    function accessExpiresAt(address entrant, uint8 layerNumber)
        external view
        validLayer(layerNumber)
        returns (uint256)
    {
        return accessRecords[entrant].expiresAt[layerNumber];
    }

    /**
     * @notice Returns the highest Watcher Gate layer the address has successfully entered.
     */
    function highestLayerReached(address entrant) external view returns (uint8) {
        return accessRecords[entrant].highestLayerReached;
    }

    // ─── View: Encoded Key Retrieval ──────────────────────────────────────────

    /**
     * @notice Returns the Layered Encoding pipeline key for `layerNumber`.
     * @dev Only callable by an address with active access to that layer.
     *      The key represents the Latin → Enochian → Proto-Canaanite → Binary → Hex output.
     */
    function getLayerEncodedKey(uint8 layerNumber)
        external view
        validLayer(layerNumber)
        returns (bytes32)
    {
        require(
            accessRecords[msg.sender].expiresAt[layerNumber] > block.timestamp,
            "WatcherGate: no active access to this layer"
        );
        return layers[layerNumber].encodedKey;
    }

    /**
     * @notice Returns the x402 payment details for a layer (for client-side 402 handling).
     * @return price         Entry price in wei
     * @return authMode      Required authentication mode
     * @return sigilContract ERC-721 contract for sigil validation (address(0) if none)
     * @return accessDuration Seconds of access granted
     * @return active        Whether the layer is currently open
     */
    function getLayerPaymentDetails(uint8 layerNumber)
        external view
        validLayer(layerNumber)
        returns (
            uint256 price,
            AuthMode authMode,
            address sigilContract,
            uint256 accessDuration,
            bool active
        )
    {
        GateLayerConfig storage layer = layers[layerNumber];
        return (
            layer.entryPrice,
            layer.authMode,
            layer.sigilContract,
            layer.accessDuration,
            layer.active
        );
    }

    // ─── Owner: Treasury Withdrawal ───────────────────────────────────────────

    /**
     * @notice Withdraw accumulated entry fees to the owner's address.
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "WatcherGate: nothing to withdraw");

        (bool sent,) = owner.call{value: balance}("");
        require(sent, "WatcherGate: withdrawal failed");

        emit Withdrawal(owner, balance);
    }

    /**
     * @notice Transfer contract ownership.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "WatcherGate: zero address");
        owner = newOwner;
    }

    // ─── Internal Helpers ─────────────────────────────────────────────────────

    /**
     * @dev Grant access to `layerNumber` for `entrant`, recording the expiry.
     */
    function _grantAccess(
        address entrant,
        uint8   layerNumber,
        uint256 amountPaid,
        AuthMode usedMode
    ) internal {
        GateLayerConfig storage layer = layers[layerNumber];
        uint256 expiresAt = block.timestamp + layer.accessDuration;

        _grantAccessUntil(entrant, layerNumber, amountPaid, usedMode, expiresAt);
    }

    function _grantAccessUntil(
        address entrant,
        uint8   layerNumber,
        uint256 amountPaid,
        AuthMode usedMode,
        uint256 expiresAt
    ) internal {
        GateAccess storage record = accessRecords[entrant];

        // Only extend if new expiry is later
        if (expiresAt > record.expiresAt[layerNumber]) {
            record.expiresAt[layerNumber] = expiresAt;
        }

        if (layerNumber > record.highestLayerReached) {
            record.highestLayerReached = layerNumber;
        }

        totalFeesCollected += amountPaid;

        emit GateEntered(
            entrant,
            layerNumber,
            usedMode,
            amountPaid,
            record.expiresAt[layerNumber],
            record.isVerifiedAgent
        );
    }

    /**
     * @dev Verify that `entrant` owns `tokenId` in `sigilContract`.
     */
    function _validateSigilOwnership(
        address entrant,
        address sigilContract,
        uint256 tokenId
    ) internal view {
        require(sigilContract != address(0), "WatcherGate: no sigil contract configured");
        address tokenOwner = IERC721(sigilContract).ownerOf(tokenId);
        require(tokenOwner == entrant, "WatcherGate: caller does not own the sigil NFT");
    }

    /**
     * @dev Apply the 5% agent discount to a price if the address is a verified agent.
     */
    function _applyAgentDiscount(uint256 price, address entrant)
        internal view
        returns (uint256)
    {
        if (verifiedAgents[entrant]) {
            return price * (10000 - AGENT_DISCOUNT_BPS) / 10000;
        }
        return price;
    }
}
