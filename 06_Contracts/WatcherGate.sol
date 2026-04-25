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
 *   SpellPayment.sol            : x402 receipt hashes verified via ISpellPayment
 *   SigilNFT.sol / KnowledgeNFT: ERC-721 sigil ownership queried via IERC721
 *   GrimoireERC8004Registry.sol : ERC-8004 agent identity registry
 */

// ─── Minimal interfaces ───────────────────────────────────────────────────────

interface ISpellPayment {
    struct SpellReceiptView {
        bytes32 receiptHash;
        address payer;
        uint256 layerNumber;
        uint256 amountPaid;
        uint256 accessExpiresAt;
        uint8   tier;
        bool    consumed;
    }

    function verifyReceipt(bytes32 receiptHash)
        external view
        returns (bool valid, SpellReceiptView memory receipt);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
}

interface IERC8004Registry {
    function registerAgent(address agentAddress, string calldata agentURI) external;
    function getAgentURI(address agentAddress) external view returns (string memory);
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AuthMode {
    PAYMENT_ONLY,  // ETH micropayment (x402) required
    SIGIL_ONLY,    // Valid sigil NFT required
    DUAL_AUTH      // Both payment AND sigil required (Layer 13)
}

// ─── Structs ──────────────────────────────────────────────────────────────────

struct GateLayerConfig {
    uint256 entryPrice;
    uint256 accessDuration;
    AuthMode authMode;
    address sigilContract;
    bytes32 encodedKey;
    bool active;
}

struct GateAccess {
    uint8  highestLayerReached;
    uint256[14] expiresAt;
    bool   isVerifiedAgent;
}

// ─── WatcherGate ──────────────────────────────────────────────────────────────

contract WatcherGate {

    // ─── Reentrancy guard ─────────────────────────────────────────────────────

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED     = 2;

    modifier nonReentrant() {
        require(_reentrancyStatus != _ENTERED, "WatcherGate: reentrant call");
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // ─── Constants ────────────────────────────────────────────────────────────

    uint8  public constant LAYER_COUNT         = 13;
    uint8  public constant SOVEREIGN_LAYER     = 13;
    uint256 public constant AGENT_DISCOUNT_BPS = 500;
    uint256 public constant MAX_LAYER_PRICE    = 1 ether;

    // ─── State ────────────────────────────────────────────────────────────────

    mapping(uint8 => GateLayerConfig) public layers;
    mapping(address => GateAccess)    public accessRecords;
    mapping(address => bool)          public verifiedAgents;

    address public owner;
    address public spellPaymentContract;
    address public erc8004Registry;
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
    event ERC8004RegistrySet(address indexed registry);
    event Withdrawal(address indexed to, uint256 amount);
    event AccessExtended(address indexed entrant, uint8 indexed layerNumber, uint256 newExpiry);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _spellPaymentContract) {
        owner = msg.sender;
        spellPaymentContract = _spellPaymentContract;
        _reentrancyStatus = _NOT_ENTERED;

        uint256[14] memory defaultPrices = [
            uint256(0),
            0.0001 ether,
            0.0002 ether,
            0.0005 ether,
            0.001  ether,
            0.002  ether,
            0.004  ether,
            0.007  ether,
            0.01   ether,
            0.025  ether,
            0.05   ether,
            0.07   ether,
            0.09   ether,
            0.1    ether
        ];

        for (uint8 i = 1; i <= LAYER_COUNT; i++) {
            AuthMode mode;
            if (i <= 3)      mode = AuthMode.PAYMENT_ONLY;
            else if (i <= 12) mode = AuthMode.SIGIL_ONLY;
            else              mode = AuthMode.DUAL_AUTH;

            layers[i] = GateLayerConfig({
                entryPrice:     defaultPrices[i],
                accessDuration: 1 days,
                authMode:       mode,
                sigilContract:  address(0),
                encodedKey:     keccak256(abi.encodePacked("LAYER_", i, "_ENOCHIAN_KEY")),
                active:         false
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

    function configureLayer(
        uint8   layerNumber,
        uint256 entryPrice,
        uint256 accessDuration,
        AuthMode authMode,
        address sigilContract,
        bytes32 encodedKey
    ) external onlyOwner validLayer(layerNumber) {
        require(entryPrice <= MAX_LAYER_PRICE, "WatcherGate: price exceeds maximum");
        require(accessDuration > 0,            "WatcherGate: zero access duration");

        AuthMode effectiveMode = (layerNumber == SOVEREIGN_LAYER)
            ? AuthMode.DUAL_AUTH
            : authMode;

        if (effectiveMode != AuthMode.PAYMENT_ONLY) {
            require(sigilContract != address(0), "WatcherGate: sigil contract required");
        }

        layers[layerNumber] = GateLayerConfig({
            entryPrice:     entryPrice,
            accessDuration: accessDuration,
            authMode:       effectiveMode,
            sigilContract:  sigilContract,
            encodedKey:     encodedKey,
            active:         layers[layerNumber].active
        });

        emit LayerConfigured(layerNumber, entryPrice, accessDuration, effectiveMode, sigilContract);
    }

    function setEncodedKey(uint8 layerNumber, bytes32 newKey)
        external onlyOwner validLayer(layerNumber)
    {
        layers[layerNumber].encodedKey = newKey;
    }

    function activateLayer(uint8 layerNumber)
        external onlyOwner validLayer(layerNumber)
    {
        layers[layerNumber].active = true;
        emit LayerReactivated(layerNumber);
    }

    function deactivateLayer(uint8 layerNumber)
        external onlyOwner validLayer(layerNumber)
    {
        layers[layerNumber].active = false;
        emit LayerDeactivated(layerNumber);
    }

    function setSpellPaymentContract(address _contract) external onlyOwner {
        require(_contract != address(0), "WatcherGate: zero address");
        spellPaymentContract = _contract;
        emit SpellPaymentContractUpdated(_contract);
    }

    /**
     * @notice Set the ERC-8004 identity registry.
     */
    function setERC8004Registry(address _registry) external onlyOwner {
        require(_registry != address(0), "WatcherGate: zero address");
        erc8004Registry = _registry;
        emit ERC8004RegistrySet(_registry);
    }

    function registerAgent(address agentAddress) external onlyOwner {
        require(agentAddress != address(0), "WatcherGate: zero address");
        verifiedAgents[agentAddress] = true;
        accessRecords[agentAddress].isVerifiedAgent = true;
        emit AgentRegistered(agentAddress, block.timestamp);
    }

    // ─── Entry: Payment-Only ──────────────────────────────────────────────────

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

        uint256 excess = msg.value - effectivePrice;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "WatcherGate: refund failed");
        }
    }

    /**
     * @notice Enter a PAYMENT_ONLY gate using a pre-validated x402 receipt.
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

        require(valid,                                       "WatcherGate: invalid or expired receipt");
        require(receipt.payer == msg.sender,                 "WatcherGate: receipt not for caller");
        require(receipt.layerNumber == uint256(layerNumber), "WatcherGate: receipt layer mismatch");
        require(receipt.accessExpiresAt > block.timestamp,   "WatcherGate: receipt access expired");

        _grantAccessUntil(msg.sender, layerNumber, 0, AuthMode.PAYMENT_ONLY, receipt.accessExpiresAt);
    }

    // ─── Entry: Sigil-Only ────────────────────────────────────────────────────

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

    function enterGateWithDualAuth(uint8 layerNumber, uint256 tokenId)
        external payable
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.DUAL_AUTH,  "WatcherGate: dual-auth not available");
        require(layer.sigilContract != address(0),     "WatcherGate: sigil contract not set");

        uint256 effectivePrice = _applyAgentDiscount(layer.entryPrice, msg.sender);
        require(msg.value >= effectivePrice, "WatcherGate: insufficient payment for sovereign layer");

        _validateSigilOwnership(msg.sender, layer.sigilContract, tokenId);

        _grantAccess(msg.sender, layerNumber, effectivePrice, AuthMode.DUAL_AUTH);

        bytes32 sigilProof = keccak256(
            abi.encodePacked(msg.sender, layer.sigilContract, tokenId, block.timestamp)
        );
        uint256 storedExpiry = accessRecords[msg.sender].expiresAt[layerNumber];
        emit SovereignAccessGranted(msg.sender, effectivePrice, sigilProof, storedExpiry);

        uint256 excess = msg.value - effectivePrice;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "WatcherGate: refund failed");
        }
    }

    /**
     * @notice Enter a DUAL_AUTH gate using an x402 receipt instead of direct ETH.
     * @dev Validates both a SpellPayment receipt AND a sigil NFT simultaneously.
     *      Useful when the user has already cast a spell and holds a receipt.
     * @param layerNumber  Target layer (must be DUAL_AUTH)
     * @param receiptHash  Valid x402 SpellPayment receipt hash
     * @param tokenId      Sigil NFT token ID in the layer's configured ERC-721 contract
     */
    function enterGateWithX402AndSigil(
        uint8   layerNumber,
        bytes32 receiptHash,
        uint256 tokenId
    )
        external
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        require(spellPaymentContract != address(0), "WatcherGate: no SpellPayment configured");
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.DUAL_AUTH, "WatcherGate: dual-auth not available");
        require(layer.sigilContract != address(0),    "WatcherGate: sigil contract not set");

        // 1. Validate x402 receipt
        (bool valid, ISpellPayment.SpellReceiptView memory receipt) =
            ISpellPayment(spellPaymentContract).verifyReceipt(receiptHash);

        require(valid,                                       "WatcherGate: invalid or expired receipt");
        require(receipt.payer == msg.sender,                 "WatcherGate: receipt not for caller");
        require(receipt.layerNumber == uint256(layerNumber), "WatcherGate: receipt layer mismatch");
        require(receipt.accessExpiresAt > block.timestamp,   "WatcherGate: receipt access expired");

        // 2. Validate sigil NFT ownership
        _validateSigilOwnership(msg.sender, layer.sigilContract, tokenId);

        // 3. Grant access using receipt expiry
        _grantAccessUntil(msg.sender, layerNumber, 0, AuthMode.DUAL_AUTH, receipt.accessExpiresAt);

        bytes32 sigilProof = keccak256(
            abi.encodePacked(msg.sender, layer.sigilContract, tokenId, block.timestamp)
        );
        uint256 storedExpiry = accessRecords[msg.sender].expiresAt[layerNumber];
        emit SovereignAccessGranted(msg.sender, receipt.amountPaid, sigilProof, storedExpiry);
    }

    // ─── Extend Access ────────────────────────────────────────────────────────

    /**
     * @notice Extend (renew) active access to a PAYMENT_ONLY layer by paying again.
     * @dev Caller must already have active (unexpired) access to the layer.
     *      Adds another accessDuration from the current expiry.
     * @param layerNumber Target layer to renew
     */
    function extendAccess(uint8 layerNumber)
        external payable
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(
            layer.authMode == AuthMode.PAYMENT_ONLY,
            "WatcherGate: extend only for payment-only layers"
        );
        require(
            accessRecords[msg.sender].expiresAt[layerNumber] > block.timestamp,
            "WatcherGate: no active access to extend"
        );

        uint256 effectivePrice = _applyAgentDiscount(layer.entryPrice, msg.sender);
        require(msg.value >= effectivePrice, "WatcherGate: insufficient payment");

        GateAccess storage record = accessRecords[msg.sender];
        uint256 newExpiry = record.expiresAt[layerNumber] + layer.accessDuration;
        record.expiresAt[layerNumber] = newExpiry;
        totalFeesCollected += effectivePrice;

        emit AccessExtended(msg.sender, layerNumber, newExpiry);

        uint256 excess = msg.value - effectivePrice;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "WatcherGate: refund failed");
        }
    }

    // ─── View: Access Checks ──────────────────────────────────────────────────

    function hasLayerAccess(address entrant, uint8 layerNumber)
        external view validLayer(layerNumber)
        returns (bool)
    {
        return accessRecords[entrant].expiresAt[layerNumber] > block.timestamp;
    }

    function accessExpiresAt(address entrant, uint8 layerNumber)
        external view validLayer(layerNumber)
        returns (uint256)
    {
        return accessRecords[entrant].expiresAt[layerNumber];
    }

    function highestLayerReached(address entrant) external view returns (uint8) {
        return accessRecords[entrant].highestLayerReached;
    }

    /**
     * @notice Bulk access status query for all 13 layers.
     * @param entrant Address to query
     * @return active   active[n] = true if layer n+1 is currently accessible
     * @return expiries expiries[n] = expiry timestamp for layer n+1 (0 if never entered)
     * @dev Indices 0-12 correspond to layers 1-13.
     */
    function getAccessStatus(address entrant)
        external view
        returns (bool[14] memory active, uint256[14] memory expiries)
    {
        GateAccess storage record = accessRecords[entrant];
        for (uint8 i = 1; i <= LAYER_COUNT; i++) {
            expiries[i] = record.expiresAt[i];
            active[i]   = record.expiresAt[i] > block.timestamp;
        }
    }

    // ─── View: Encoded Key Retrieval ──────────────────────────────────────────

    function getLayerEncodedKey(uint8 layerNumber)
        external view validLayer(layerNumber)
        returns (bytes32)
    {
        require(
            accessRecords[msg.sender].expiresAt[layerNumber] > block.timestamp,
            "WatcherGate: no active access to this layer"
        );
        return layers[layerNumber].encodedKey;
    }

    function getLayerPaymentDetails(uint8 layerNumber)
        external view validLayer(layerNumber)
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

    // ─── ERC-8004 Self-Registration ───────────────────────────────────────────

    /**
     * @notice Allow a caller to self-register as an ERC-8004 agent.
     * @dev Registers msg.sender in the configured ERC-8004 registry with a
     *      placeholder URI. The caller becomes a verified agent in WatcherGate.
     *      The registry URI should be updated post-IPFS upload via setAgentURI.
     */
    function selfRegisterAsAgent() external {
        require(erc8004Registry != address(0), "WatcherGate: no ERC-8004 registry set");
        require(!verifiedAgents[msg.sender],   "WatcherGate: already a verified agent");

        verifiedAgents[msg.sender] = true;
        accessRecords[msg.sender].isVerifiedAgent = true;

        IERC8004Registry(erc8004Registry).registerAgent(
            msg.sender,
            "ipfs://PENDING_AGENT_CARD_CID"
        );

        emit AgentRegistered(msg.sender, block.timestamp);
    }

    // ─── Owner: Treasury Withdrawal ───────────────────────────────────────────

    /**
     * @notice Withdraw accumulated entry fees to the owner's address.
     * @dev Protected by reentrancy guard. Uses call (not transfer).
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "WatcherGate: nothing to withdraw");

        (bool sent,) = owner.call{value: balance}("");
        require(sent, "WatcherGate: withdrawal failed");

        emit Withdrawal(owner, balance);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "WatcherGate: zero address");
        owner = newOwner;
    }

    // ─── Internal Helpers ─────────────────────────────────────────────────────

    function _grantAccess(
        address entrant,
        uint8   layerNumber,
        uint256 amountPaid,
        AuthMode usedMode
    ) internal {
        uint256 expiresAt = block.timestamp + layers[layerNumber].accessDuration;
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

    function _validateSigilOwnership(
        address entrant,
        address sigilContract,
        uint256 tokenId
    ) internal view {
        require(sigilContract != address(0), "WatcherGate: no sigil contract configured");
        address tokenOwner = IERC721(sigilContract).ownerOf(tokenId);
        require(tokenOwner == entrant, "WatcherGate: caller does not own the sigil NFT");
    }

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
