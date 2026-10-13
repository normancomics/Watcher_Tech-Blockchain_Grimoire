// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title WatcherGateV2
 * @author normancomics.eth — 2026 A.D.
 * @notice Gatekeeper Subagent — Sovereign hierarchical pay-to-access contract on Base
 * @dev v2 of WatcherGate.sol. Deployed and referenced independently from the
 *      original WatcherGate.sol / SpellPayment.sol — this is an additive
 *      upgrade, not an in-place replacement, so existing v1 deployments and
 *      tests are unaffected. Pairs with SpellPaymentV2.sol.
 *
 * ─── What changed vs. WatcherGate.sol (v1) ────────────────────────────────────
 *   1. Price-enforced single-use receipts : enterGateWithX402Receipt and
 *      enterGateWithX402AndSigil now call consumeReceipt() on SpellPaymentV2
 *      after verifying, so a receipt can never be replayed across multiple
 *      gate entries (v1 verified but never consumed — a receipt stayed valid
 *      and reusable until its 1-day expiry).
 *   2. Sigil levels : GateLayerConfig gains `requiredSigilTier`. A layer may
 *      now require not just *any* sigil from its configured ERC-721 contract,
 *      but one whose tokenTier() meets or exceeds a configured minimum — using
 *      SigilNFT.sol's existing public `tokenTier` mapping, no changes needed
 *      there.
 *   3. Key commitments : setEncodedKey's instant, unannounced key swap is
 *      replaced with commitKeyUpdate() / revealKeyUpdate() — a commit-reveal
 *      scheme with a timelock, so entrants can observe a pending key change
 *      before it takes effect instead of trusting the owner not to silently
 *      swap the promised key.
 *   4. Pause : owner can halt new gate entries in an emergency without
 *      disabling view functions or withdrawals.
 *   5. Two-step ownership : transferOwnership + acceptOwnership
 *      (Ownable2Step pattern) instead of single-step transfer.
 *
 * ─── Layer Hierarchy (unchanged from v1) ──────────────────────────────────────
 *   Layer  1–3  : Neophyte tiers    — Cantrip payments (< 0.001 ETH)
 *   Layer  4–7  : Initiate tiers    — Ritual payments or sigil NFT
 *   Layer  8–12 : Adept tiers       — Ceremony payments or sigil NFT
 *   Layer 13    : Sovereign Gate    — Invocation payment AND valid sigil NFT
 *
 * ─── Authentication Modes (unchanged from v1) ─────────────────────────────────
 *   PAYMENT_ONLY  — ETH paid through an x402 SpellPaymentV2 gate
 *   SIGIL_ONLY    — Holding an authenticated sigil NFT (ERC-721) of sufficient tier
 *   DUAL_AUTH     — Both payment AND sigil (mandatory for Layer 13)
 *
 * ─── Integration ───────────────────────────────────────────────────────────────
 *   SpellPaymentV2.sol          : x402 receipt hashes verified + consumed via ISpellPaymentV2
 *   SigilNFT.sol                : ERC-721 sigil ownership + tier queried via ISigilNFT
 *   GrimoireERC8004Registry.sol : ERC-8004 agent identity registry
 */

// ─── Minimal interfaces ───────────────────────────────────────────────────────

interface ISpellPaymentV2 {
    struct SpellReceiptView {
        bytes32 receiptHash;
        address payer;
        uint256 layerNumber;
        uint256 amountPaid;
        uint256 accessExpiresAt;
        uint8   tier;
        uint8   currency;
        bool    consumed;
    }

    function verifyReceipt(bytes32 receiptHash)
        external view
        returns (bool valid, SpellReceiptView memory receipt);

    function consumeReceipt(bytes32 receiptHash) external;
}

interface ISigilNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    /// @dev Matches SigilNFT.sol's public `tokenTier` mapping getter.
    function tokenTier(uint256 tokenId) external view returns (uint8);
}

interface IERC8004Registry {
    function registerAgent(address agentAddress, string calldata agentURI) external;
    function getAgentURI(address agentAddress) external view returns (string memory);
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AuthMode {
    PAYMENT_ONLY,  // ETH micropayment (x402) required
    SIGIL_ONLY,    // Valid sigil NFT of sufficient tier required
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
    uint8  requiredSigilTier; // 0 = any tier accepted; otherwise minimum SigilNFT tier
}

struct GateAccess {
    uint8  highestLayerReached;
    uint256[14] expiresAt;
    bool   isVerifiedAgent;
}

// ─── WatcherGateV2 ─────────────────────────────────────────────────────────────

contract WatcherGateV2 {

    // ─── Reentrancy guard ─────────────────────────────────────────────────────

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED     = 2;

    modifier nonReentrant() {
        require(_reentrancyStatus != _ENTERED, "WatcherGateV2: reentrant call");
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // ─── Constants ────────────────────────────────────────────────────────────

    uint8  public constant LAYER_COUNT          = 13;
    uint8  public constant SOVEREIGN_LAYER      = 13;
    uint256 public constant AGENT_DISCOUNT_BPS  = 500;
    uint256 public constant MAX_LAYER_PRICE     = 1 ether;

    /// @notice Minimum delay between committing a new encoded key and revealing it.
    uint256 public constant KEY_REVEAL_DELAY = 1 hours;

    // ─── State ────────────────────────────────────────────────────────────────

    mapping(uint8 => GateLayerConfig) public layers;
    mapping(address => GateAccess)    public accessRecords;
    mapping(address => bool)          public verifiedAgents;

    /// @notice Pending key commitment per layer: keccak256(abi.encodePacked(newKey, salt)).
    mapping(uint8 => bytes32) public pendingKeyCommitment;
    /// @notice Timestamp at which each layer's pending key commitment was made.
    mapping(uint8 => uint256) public keyCommitAt;

    address public owner;
    address public pendingOwner;
    address public spellPaymentContract;
    address public erc8004Registry;
    uint256 public totalFeesCollected;
    bool    public paused;

    // ─── Events ───────────────────────────────────────────────────────────────

    event LayerConfigured(
        uint8  indexed layerNumber,
        uint256 entryPrice,
        uint256 accessDuration,
        AuthMode authMode,
        address sigilContract,
        uint8  requiredSigilTier
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
    event KeyUpdateCommitted(uint8 indexed layerNumber, bytes32 commitHash, uint256 revealableAt);
    event KeyUpdateRevealed(uint8 indexed layerNumber, bytes32 newKey);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
                entryPrice:         defaultPrices[i],
                accessDuration:     1 days,
                authMode:           mode,
                sigilContract:      address(0),
                encodedKey:         keccak256(abi.encodePacked("LAYER_", i, "_ENOCHIAN_KEY")),
                active:             false,
                requiredSigilTier:  0
            });
        }
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "WatcherGateV2: not owner");
        _;
    }

    modifier validLayer(uint8 layerNumber) {
        require(layerNumber >= 1 && layerNumber <= LAYER_COUNT, "WatcherGateV2: invalid layer");
        _;
    }

    modifier layerActive(uint8 layerNumber) {
        require(layers[layerNumber].active, "WatcherGateV2: layer not active");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "WatcherGateV2: paused");
        _;
    }

    // ─── Owner: Layer Management ──────────────────────────────────────────────

    function configureLayer(
        uint8   layerNumber,
        uint256 entryPrice,
        uint256 accessDuration,
        AuthMode authMode,
        address sigilContract,
        bytes32 encodedKey,
        uint8   requiredSigilTier
    ) external onlyOwner validLayer(layerNumber) {
        require(entryPrice <= MAX_LAYER_PRICE, "WatcherGateV2: price exceeds maximum");
        require(accessDuration > 0,            "WatcherGateV2: zero access duration");

        AuthMode effectiveMode = (layerNumber == SOVEREIGN_LAYER)
            ? AuthMode.DUAL_AUTH
            : authMode;

        if (effectiveMode != AuthMode.PAYMENT_ONLY) {
            require(sigilContract != address(0), "WatcherGateV2: sigil contract required");
        }

        layers[layerNumber] = GateLayerConfig({
            entryPrice:         entryPrice,
            accessDuration:     accessDuration,
            authMode:           effectiveMode,
            sigilContract:      sigilContract,
            encodedKey:         encodedKey,
            active:             layers[layerNumber].active,
            requiredSigilTier:  requiredSigilTier
        });

        emit LayerConfigured(layerNumber, entryPrice, accessDuration, effectiveMode, sigilContract, requiredSigilTier);
    }

    // ─── Owner: Key Commitments (commit-reveal) ───────────────────────────────

    /**
     * @notice Commit to a future encoded-key change for a layer without
     *         revealing the new key yet.
     * @dev commitHash = keccak256(abi.encodePacked(newKey, salt)). The key can
     *      only be revealed (and take effect) after KEY_REVEAL_DELAY has
     *      elapsed, giving entrants a transparent window to observe the
     *      pending change before it applies.
     */
    function commitKeyUpdate(uint8 layerNumber, bytes32 commitHash)
        external onlyOwner validLayer(layerNumber)
    {
        require(commitHash != bytes32(0), "WatcherGateV2: empty commitment");
        pendingKeyCommitment[layerNumber] = commitHash;
        keyCommitAt[layerNumber] = block.timestamp;
        emit KeyUpdateCommitted(layerNumber, commitHash, block.timestamp + KEY_REVEAL_DELAY);
    }

    /**
     * @notice Reveal a previously committed encoded-key change and apply it.
     * @dev Reverts if the reveal delay hasn't elapsed, or if (newKey, salt)
     *      doesn't match the committed hash.
     */
    function revealKeyUpdate(uint8 layerNumber, bytes32 newKey, bytes32 salt)
        external onlyOwner validLayer(layerNumber)
    {
        bytes32 commitHash = pendingKeyCommitment[layerNumber];
        require(commitHash != bytes32(0), "WatcherGateV2: no pending commitment");
        require(
            block.timestamp >= keyCommitAt[layerNumber] + KEY_REVEAL_DELAY,
            "WatcherGateV2: reveal too early"
        );
        require(
            keccak256(abi.encodePacked(newKey, salt)) == commitHash,
            "WatcherGateV2: commitment mismatch"
        );

        layers[layerNumber].encodedKey = newKey;
        delete pendingKeyCommitment[layerNumber];
        delete keyCommitAt[layerNumber];

        emit KeyUpdateRevealed(layerNumber, newKey);
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
        require(_contract != address(0), "WatcherGateV2: zero address");
        spellPaymentContract = _contract;
        emit SpellPaymentContractUpdated(_contract);
    }

    function setERC8004Registry(address _registry) external onlyOwner {
        require(_registry != address(0), "WatcherGateV2: zero address");
        erc8004Registry = _registry;
        emit ERC8004RegistrySet(_registry);
    }

    function registerAgent(address agentAddress) external onlyOwner {
        require(agentAddress != address(0), "WatcherGateV2: zero address");
        verifiedAgents[agentAddress] = true;
        accessRecords[agentAddress].isVerifiedAgent = true;
        emit AgentRegistered(agentAddress, block.timestamp);
    }

    // ─── Owner: Pause ──────────────────────────────────────────────────────────

    /**
     * @notice Pause new gate entries in an emergency.
     * @dev View functions and withdraw() remain available while paused, so
     *      existing entrants and the treasury are never locked out.
     */
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ─── Ownership (two-step) ──────────────────────────────────────────────────

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "WatcherGateV2: zero address");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "WatcherGateV2: not pending owner");
        address previousOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, owner);
    }

    // ─── Entry: Payment-Only ──────────────────────────────────────────────────

    function enterGateWithPayment(uint8 layerNumber)
        external payable
        whenNotPaused
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.PAYMENT_ONLY, "WatcherGateV2: payment-only not available");

        uint256 effectivePrice = _applyAgentDiscount(layer.entryPrice, msg.sender);
        require(msg.value >= effectivePrice, "WatcherGateV2: insufficient payment");

        _grantAccess(msg.sender, layerNumber, effectivePrice, AuthMode.PAYMENT_ONLY);

        uint256 excess = msg.value - effectivePrice;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "WatcherGateV2: refund failed");
        }
    }

    /**
     * @notice Enter a PAYMENT_ONLY gate using a pre-validated x402 receipt.
     * @dev Unlike v1, the receipt is consumed here, making it single-use —
     *      it can never be presented again to enter any layer.
     */
    function enterGateWithX402Receipt(uint8 layerNumber, bytes32 receiptHash)
        external
        whenNotPaused
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        require(spellPaymentContract != address(0), "WatcherGateV2: no SpellPayment configured");
        GateLayerConfig storage layer = layers[layerNumber];
        require(
            layer.authMode == AuthMode.PAYMENT_ONLY,
            "WatcherGateV2: x402 receipt only for payment-only layers"
        );

        (bool valid, ISpellPaymentV2.SpellReceiptView memory receipt) =
            ISpellPaymentV2(spellPaymentContract).verifyReceipt(receiptHash);

        require(valid,                                       "WatcherGateV2: invalid or expired receipt");
        require(receipt.payer == msg.sender,                 "WatcherGateV2: receipt not for caller");
        require(receipt.layerNumber == uint256(layerNumber), "WatcherGateV2: receipt layer mismatch");
        require(receipt.accessExpiresAt > block.timestamp,   "WatcherGateV2: receipt access expired");

        // Consume before granting access (checks-effects-interactions):
        // a receipt can only ever unlock one gate entry.
        ISpellPaymentV2(spellPaymentContract).consumeReceipt(receiptHash);

        _grantAccessUntil(msg.sender, layerNumber, 0, AuthMode.PAYMENT_ONLY, receipt.accessExpiresAt);
    }

    // ─── Entry: Sigil-Only ────────────────────────────────────────────────────

    function enterGateWithSigil(uint8 layerNumber, uint256 tokenId)
        external
        whenNotPaused
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.SIGIL_ONLY, "WatcherGateV2: sigil-only not available");

        _validateSigilOwnership(msg.sender, layer.sigilContract, tokenId, layer.requiredSigilTier);

        _grantAccess(msg.sender, layerNumber, 0, AuthMode.SIGIL_ONLY);
    }

    // ─── Entry: Dual Auth (Layer 13 Sovereign) ────────────────────────────────

    function enterGateWithDualAuth(uint8 layerNumber, uint256 tokenId)
        external payable
        whenNotPaused
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.DUAL_AUTH,  "WatcherGateV2: dual-auth not available");
        require(layer.sigilContract != address(0),     "WatcherGateV2: sigil contract not set");

        uint256 effectivePrice = _applyAgentDiscount(layer.entryPrice, msg.sender);
        require(msg.value >= effectivePrice, "WatcherGateV2: insufficient payment for sovereign layer");

        _validateSigilOwnership(msg.sender, layer.sigilContract, tokenId, layer.requiredSigilTier);

        _grantAccess(msg.sender, layerNumber, effectivePrice, AuthMode.DUAL_AUTH);

        bytes32 sigilProof = keccak256(
            abi.encodePacked(msg.sender, layer.sigilContract, tokenId, block.timestamp)
        );
        uint256 storedExpiry = accessRecords[msg.sender].expiresAt[layerNumber];
        emit SovereignAccessGranted(msg.sender, effectivePrice, sigilProof, storedExpiry);

        uint256 excess = msg.value - effectivePrice;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "WatcherGateV2: refund failed");
        }
    }

    /**
     * @notice Enter a DUAL_AUTH gate using an x402 receipt instead of direct ETH.
     * @dev As with enterGateWithX402Receipt, the receipt is consumed here.
     */
    function enterGateWithX402AndSigil(
        uint8   layerNumber,
        bytes32 receiptHash,
        uint256 tokenId
    )
        external
        whenNotPaused
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        require(spellPaymentContract != address(0), "WatcherGateV2: no SpellPayment configured");
        GateLayerConfig storage layer = layers[layerNumber];
        require(layer.authMode == AuthMode.DUAL_AUTH, "WatcherGateV2: dual-auth not available");
        require(layer.sigilContract != address(0),    "WatcherGateV2: sigil contract not set");

        (bool valid, ISpellPaymentV2.SpellReceiptView memory receipt) =
            ISpellPaymentV2(spellPaymentContract).verifyReceipt(receiptHash);

        require(valid,                                       "WatcherGateV2: invalid or expired receipt");
        require(receipt.payer == msg.sender,                 "WatcherGateV2: receipt not for caller");
        require(receipt.layerNumber == uint256(layerNumber), "WatcherGateV2: receipt layer mismatch");
        require(receipt.accessExpiresAt > block.timestamp,   "WatcherGateV2: receipt access expired");

        _validateSigilOwnership(msg.sender, layer.sigilContract, tokenId, layer.requiredSigilTier);

        // Consume before granting access.
        ISpellPaymentV2(spellPaymentContract).consumeReceipt(receiptHash);

        _grantAccessUntil(msg.sender, layerNumber, 0, AuthMode.DUAL_AUTH, receipt.accessExpiresAt);

        bytes32 sigilProof = keccak256(
            abi.encodePacked(msg.sender, layer.sigilContract, tokenId, block.timestamp)
        );
        uint256 storedExpiry = accessRecords[msg.sender].expiresAt[layerNumber];
        emit SovereignAccessGranted(msg.sender, receipt.amountPaid, sigilProof, storedExpiry);
    }

    // ─── Extend Access ────────────────────────────────────────────────────────

    function extendAccess(uint8 layerNumber)
        external payable
        whenNotPaused
        validLayer(layerNumber)
        layerActive(layerNumber)
    {
        GateLayerConfig storage layer = layers[layerNumber];
        require(
            layer.authMode == AuthMode.PAYMENT_ONLY,
            "WatcherGateV2: extend only for payment-only layers"
        );
        require(
            accessRecords[msg.sender].expiresAt[layerNumber] > block.timestamp,
            "WatcherGateV2: no active access to extend"
        );

        uint256 effectivePrice = _applyAgentDiscount(layer.entryPrice, msg.sender);
        require(msg.value >= effectivePrice, "WatcherGateV2: insufficient payment");

        GateAccess storage record = accessRecords[msg.sender];
        uint256 newExpiry = record.expiresAt[layerNumber] + layer.accessDuration;
        record.expiresAt[layerNumber] = newExpiry;
        totalFeesCollected += effectivePrice;

        emit AccessExtended(msg.sender, layerNumber, newExpiry);

        uint256 excess = msg.value - effectivePrice;
        if (excess > 0) {
            (bool refunded,) = msg.sender.call{value: excess}("");
            require(refunded, "WatcherGateV2: refund failed");
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
            "WatcherGateV2: no active access to this layer"
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
            bool active,
            uint8  requiredSigilTier
        )
    {
        GateLayerConfig storage layer = layers[layerNumber];
        return (
            layer.entryPrice,
            layer.authMode,
            layer.sigilContract,
            layer.accessDuration,
            layer.active,
            layer.requiredSigilTier
        );
    }

    // ─── ERC-8004 Self-Registration ───────────────────────────────────────────

    function selfRegisterAsAgent() external {
        require(erc8004Registry != address(0), "WatcherGateV2: no ERC-8004 registry set");
        require(!verifiedAgents[msg.sender],   "WatcherGateV2: already a verified agent");

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
     * @dev Deliberately not gated by whenNotPaused — pausing halts new entries,
     *      not the owner's ability to retrieve already-collected funds.
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "WatcherGateV2: nothing to withdraw");

        (bool sent,) = owner.call{value: balance}("");
        require(sent, "WatcherGateV2: withdrawal failed");

        emit Withdrawal(owner, balance);
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

    /**
     * @dev Verify that `entrant` owns `tokenId` in `sigilContract` AND that
     *      the token's tier meets or exceeds `requiredSigilTier` (0 = any tier).
     */
    function _validateSigilOwnership(
        address entrant,
        address sigilContract,
        uint256 tokenId,
        uint8   requiredSigilTier
    ) internal view {
        require(sigilContract != address(0), "WatcherGateV2: no sigil contract configured");
        address tokenOwner = ISigilNFT(sigilContract).ownerOf(tokenId);
        require(tokenOwner == entrant, "WatcherGateV2: caller does not own the sigil NFT");

        if (requiredSigilTier > 0) {
            uint8 heldTier = ISigilNFT(sigilContract).tokenTier(tokenId);
            require(heldTier >= requiredSigilTier, "WatcherGateV2: sigil tier too low");
        }
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
