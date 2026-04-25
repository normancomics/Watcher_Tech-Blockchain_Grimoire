// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SpellPayment
 * @author normancomics.eth — 2026 A.D.
 * @notice x402 receipt issuer for WatcherGate — cast a spell, get a receipt hash
 * @dev Implements the x402 "Payment Required" pattern on-chain.
 *      Receipts are single-use proofs that a payer sent ETH for a given layer.
 *
 * Spell Taxonomy:
 *   CANTRIP   — Layers 1-3  (micro payment, < 0.001 ETH)
 *   RITUAL    — Layers 4-7  (standard payment, 0.001-0.01 ETH)
 *   CEREMONY  — Layers 8-12 (premium payment, 0.01-0.1 ETH)
 *   INVOCATION— Layer 13    (sovereign payment, ≥ 0.1 ETH)
 */

// ─── Enums & Structs ─────────────────────────────────────────────────────────

enum SpellTier {
    CANTRIP,     // Layers 1-3
    RITUAL,      // Layers 4-7
    CEREMONY,    // Layers 8-12
    INVOCATION   // Layer 13
}

struct SpellReceipt {
    bytes32 receiptHash;
    address payer;
    uint256 layerNumber;   // WatcherGate layer this receipt unlocks
    uint256 amountPaid;
    uint256 accessExpiresAt;
    SpellTier tier;
    bool consumed;
}

// ─── SpellPayment ─────────────────────────────────────────────────────────────

contract SpellPayment {

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant CANTRIP_MAX   = 0.001 ether;
    uint256 public constant RITUAL_MAX    = 0.01  ether;
    uint256 public constant CEREMONY_MAX  = 0.1   ether;

    uint256 public constant ACCESS_DURATION = 1 days;

    // ─── State ────────────────────────────────────────────────────────────────

    mapping(bytes32 => SpellReceipt) public receipts;
    mapping(uint8 => uint256)        public layerPrice;   // optional per-layer price hint

    address public owner;
    address public watcherGate;

    // ─── Events ───────────────────────────────────────────────────────────────

    event SpellCast(
        bytes32 indexed receiptHash,
        address indexed payer,
        uint256 indexed layerNumber,
        uint256         amountPaid,
        SpellTier       tier
    );

    event ReceiptConsumed(bytes32 indexed receiptHash, address indexed consumer);
    event WatcherGateSet(address indexed watcherGate);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _watcherGate) {
        owner       = msg.sender;
        watcherGate = _watcherGate;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "SpellPayment: not owner");
        _;
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    /**
     * @notice Set (or update) the WatcherGate contract address post-deploy.
     */
    function setWatcherGate(address _watcherGate) external onlyOwner {
        require(_watcherGate != address(0), "SpellPayment: zero address");
        watcherGate = _watcherGate;
        emit WatcherGateSet(_watcherGate);
    }

    // ─── Spell Casting ────────────────────────────────────────────────────────

    /**
     * @notice Cast a spell — pay ETH and receive a receipt hash proving payment.
     * @dev The receipt hash is the x402 proof presented to WatcherGate.
     *      accessExpiresAt is fixed at block.timestamp + 1 day per spec.
     * @param layerNumber  WatcherGate layer (1-13)
     * @return receiptHash  Unique proof of payment — present to WatcherGate
     */
    function castSpell(uint256 layerNumber)
        external payable
        returns (bytes32 receiptHash)
    {
        require(layerNumber >= 1 && layerNumber <= 13, "SpellPayment: invalid layer");
        require(msg.value > 0, "SpellPayment: payment required");

        SpellTier tier = _classifyLayer(uint8(layerNumber));

        receiptHash = keccak256(
            abi.encodePacked(
                msg.sender,
                layerNumber,
                msg.value,
                block.timestamp,
                block.prevrandao
            )
        );

        uint256 expiresAt = block.timestamp + ACCESS_DURATION;

        receipts[receiptHash] = SpellReceipt({
            receiptHash:     receiptHash,
            payer:           msg.sender,
            layerNumber:     layerNumber,
            amountPaid:      msg.value,
            accessExpiresAt: expiresAt,
            tier:            tier,
            consumed:        false
        });

        emit SpellCast(receiptHash, msg.sender, layerNumber, msg.value, tier);
    }

    // ─── Receipt Verification ─────────────────────────────────────────────────

    /**
     * @notice Verify a receipt — used by WatcherGate before granting access.
     * @param receiptHash  Receipt hash to verify
     * @return valid    True if the receipt exists, is unexpired and unconsumed
     * @return receipt  Full SpellReceipt struct
     */
    function verifyReceipt(bytes32 receiptHash)
        external view
        returns (bool valid, SpellReceipt memory receipt)
    {
        receipt = receipts[receiptHash];
        valid = (
            receipt.receiptHash == receiptHash &&
            !receipt.consumed &&
            receipt.accessExpiresAt > block.timestamp
        );
    }

    /**
     * @notice Mark a receipt as consumed (one-time use).
     * @dev Callable by WatcherGate or owner.
     */
    function consumeReceipt(bytes32 receiptHash) external {
        require(
            msg.sender == owner || msg.sender == watcherGate,
            "SpellPayment: not authorised"
        );
        SpellReceipt storage r = receipts[receiptHash];
        require(!r.consumed, "SpellPayment: already consumed");
        require(r.accessExpiresAt > block.timestamp, "SpellPayment: receipt expired");

        r.consumed = true;
        emit ReceiptConsumed(receiptHash, r.payer);
    }

    // ─── Treasury ─────────────────────────────────────────────────────────────

    /**
     * @notice Withdraw collected ETH to owner.
     * @dev Uses call pattern (not transfer) per spec.
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "SpellPayment: nothing to withdraw");

        (bool sent,) = owner.call{value: balance}("");
        require(sent, "SpellPayment: withdrawal failed");
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    /**
     * @dev Classify a layer number into a SpellTier.
     *      CANTRIP: 1-3 | RITUAL: 4-7 | CEREMONY: 8-12 | INVOCATION: 13
     */
    function _classifyLayer(uint8 layerNumber) internal pure returns (SpellTier) {
        if (layerNumber <= 3)  return SpellTier.CANTRIP;
        if (layerNumber <= 7)  return SpellTier.RITUAL;
        if (layerNumber <= 12) return SpellTier.CEREMONY;
        return SpellTier.INVOCATION;
    }
}
