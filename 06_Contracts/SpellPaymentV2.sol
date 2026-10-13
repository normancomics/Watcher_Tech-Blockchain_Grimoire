// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SpellPaymentV2
 * @author normancomics.eth — 2026 A.D.
 * @notice x402 receipt issuer for WatcherGateV2 — cast a spell, get a receipt hash.
 * @dev v2 of SpellPayment.sol. Deployed and referenced independently from the
 *      original SpellPayment.sol / WatcherGate.sol — this is an additive upgrade,
 *      not an in-place replacement, so existing v1 deployments and tests are
 *      unaffected.
 *
 * ─── What changed vs. SpellPayment.sol (v1) ───────────────────────────────────
 *   1. Price-enforced receipts  : owner may pin a minimum price per layer via
 *      `setLayerPrice`; `castSpell` then rejects underpayment instead of
 *      silently accepting any non-zero value (v1 accepted 1 wei for any layer).
 *   2. USDC (EIP-3009) payments : `castSpellWithUSDC` pulls USDC via a signed
 *      `receiveWithAuthorization` authorization — no separate `approve()` tx
 *      required from the payer.
 *   3. Pause                   : owner can halt new spell-casting in an
 *      emergency without disabling receipt verification/consumption.
 *   4. Two-step ownership      : `transferOwnership` + `acceptOwnership`
 *      (Ownable2Step pattern) instead of single-step ownership transfer, so a
 *      mistyped address can't accidentally brick ownership.
 *
 * Spell Taxonomy (unchanged from v1):
 *   CANTRIP   — Layers 1-3  (micro payment, < 0.001 ETH)
 *   RITUAL    — Layers 4-7  (standard payment, 0.001-0.01 ETH)
 *   CEREMONY  — Layers 8-12 (premium payment, 0.01-0.1 ETH)
 *   INVOCATION— Layer 13    (sovereign payment, ≥ 0.1 ETH)
 */

// ─── Minimal interfaces ───────────────────────────────────────────────────────

/**
 * @dev EIP-3009 "Transfer With Authorization" — implemented by Base USDC.
 *      https://eips.ethereum.org/EIPS/eip-3009
 */
interface IERC3009 {
    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8   v,
        bytes32 r,
        bytes32 s
    ) external;
}

// ─── Enums & Structs ─────────────────────────────────────────────────────────

enum SpellTier {
    CANTRIP,     // Layers 1-3
    RITUAL,      // Layers 4-7
    CEREMONY,    // Layers 8-12
    INVOCATION   // Layer 13
}

enum SpellCurrency {
    ETH,
    USDC
}

struct SpellReceipt {
    bytes32 receiptHash;
    address payer;
    uint256 layerNumber;   // WatcherGateV2 layer this receipt unlocks
    uint256 amountPaid;
    uint256 accessExpiresAt;
    SpellTier tier;
    SpellCurrency currency;
    bool consumed;
}

// ─── SpellPaymentV2 ────────────────────────────────────────────────────────────

contract SpellPaymentV2 {

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant CANTRIP_MAX   = 0.001 ether;
    uint256 public constant RITUAL_MAX    = 0.01  ether;
    uint256 public constant CEREMONY_MAX  = 0.1   ether;

    uint256 public constant ACCESS_DURATION = 1 days;

    // ─── State ────────────────────────────────────────────────────────────────

    mapping(bytes32 => SpellReceipt) public receipts;

    /// @notice Minimum ETH price (in wei) required to cast a spell for a given
    ///         layer. 0 means "unset" — castSpell falls back to the v1 behavior
    ///         of accepting any non-zero payment for that layer.
    mapping(uint8 => uint256) public layerPrice;

    /// @notice Minimum USDC price (in USDC's smallest unit, 6 decimals) required
    ///         to cast a spell for a given layer via castSpellWithUSDC.
    mapping(uint8 => uint256) public layerPriceUSDC;

    address public owner;
    address public pendingOwner;
    address public watcherGate;
    address public usdcToken; // Base USDC (EIP-3009 compatible)
    bool    public paused;

    // ─── Events ───────────────────────────────────────────────────────────────

    event SpellCast(
        bytes32 indexed receiptHash,
        address indexed payer,
        uint256 indexed layerNumber,
        uint256         amountPaid,
        SpellTier       tier,
        SpellCurrency   currency
    );

    event ReceiptConsumed(bytes32 indexed receiptHash, address indexed consumer);
    event WatcherGateSet(address indexed watcherGate);
    event UsdcTokenSet(address indexed usdcToken);
    event LayerPriceSet(uint8 indexed layerNumber, uint256 priceWei);
    event LayerPriceUSDCSet(uint8 indexed layerNumber, uint256 priceUSDC);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _watcherGate) {
        owner       = msg.sender;
        watcherGate = _watcherGate;
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "SpellPaymentV2: not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "SpellPaymentV2: paused");
        _;
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    /**
     * @notice Set (or update) the WatcherGateV2 contract address post-deploy.
     */
    function setWatcherGate(address _watcherGate) external onlyOwner {
        require(_watcherGate != address(0), "SpellPaymentV2: zero address");
        watcherGate = _watcherGate;
        emit WatcherGateSet(_watcherGate);
    }

    /**
     * @notice Set the USDC token contract used for castSpellWithUSDC.
     * @dev Must be an EIP-3009-compatible token (e.g. Base USDC).
     */
    function setUsdcToken(address _usdcToken) external onlyOwner {
        require(_usdcToken != address(0), "SpellPaymentV2: zero address");
        usdcToken = _usdcToken;
        emit UsdcTokenSet(_usdcToken);
    }

    /**
     * @notice Pin a minimum ETH price (wei) for a given layer.
     * @dev Setting a price > 0 enforces it in castSpell; set back to 0 to
     *      restore v1-style "any non-zero payment accepted" behavior.
     */
    function setLayerPrice(uint8 layerNumber, uint256 priceWei) external onlyOwner {
        require(layerNumber >= 1 && layerNumber <= 13, "SpellPaymentV2: invalid layer");
        layerPrice[layerNumber] = priceWei;
        emit LayerPriceSet(layerNumber, priceWei);
    }

    /**
     * @notice Pin a minimum USDC price for a given layer (used by castSpellWithUSDC).
     */
    function setLayerPriceUSDC(uint8 layerNumber, uint256 priceUSDC) external onlyOwner {
        require(layerNumber >= 1 && layerNumber <= 13, "SpellPaymentV2: invalid layer");
        layerPriceUSDC[layerNumber] = priceUSDC;
        emit LayerPriceUSDCSet(layerNumber, priceUSDC);
    }

    /**
     * @notice Pause spell-casting (castSpell / castSpellWithUSDC) in an emergency.
     * @dev Receipt verification and consumption remain available while paused,
     *      so entrants who already hold a valid receipt are not locked out.
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

    /**
     * @notice Begin an ownership transfer. The new owner must call
     *         acceptOwnership() to complete it — protects against transferring
     *         ownership to an unreachable or mistyped address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SpellPaymentV2: zero address");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /**
     * @notice Complete a pending ownership transfer. Callable only by pendingOwner.
     */
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "SpellPaymentV2: not pending owner");
        address previousOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, owner);
    }

    // ─── Spell Casting (ETH) ────────────────────────────────────────────────────

    /**
     * @notice Cast a spell — pay ETH and receive a receipt hash proving payment.
     * @dev If a minimum price has been pinned for `layerNumber` via
     *      setLayerPrice, msg.value must meet or exceed it. Otherwise falls
     *      back to requiring any non-zero payment (v1 behavior).
     * @param layerNumber  WatcherGateV2 layer (1-13)
     * @return receiptHash  Unique proof of payment — present to WatcherGateV2
     */
    function castSpell(uint256 layerNumber)
        external payable
        whenNotPaused
        returns (bytes32 receiptHash)
    {
        require(layerNumber >= 1 && layerNumber <= 13, "SpellPaymentV2: invalid layer");

        uint256 minPrice = layerPrice[uint8(layerNumber)];
        if (minPrice > 0) {
            require(msg.value >= minPrice, "SpellPaymentV2: payment below layer price");
        } else {
            require(msg.value > 0, "SpellPaymentV2: payment required");
        }

        SpellTier tier = _classifyLayer(uint8(layerNumber));

        receiptHash = keccak256(
            abi.encodePacked(
                msg.sender,
                layerNumber,
                msg.value,
                block.timestamp,
                block.prevrandao,
                uint8(SpellCurrency.ETH)
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
            currency:        SpellCurrency.ETH,
            consumed:        false
        });

        emit SpellCast(receiptHash, msg.sender, layerNumber, msg.value, tier, SpellCurrency.ETH);
    }

    // ─── Spell Casting (USDC via EIP-3009) ─────────────────────────────────────

    /**
     * @notice Cast a spell using a signed USDC "receive with authorization" —
     *         no prior approve() transaction needed from the payer.
     * @dev Requires usdcToken to be configured via setUsdcToken. The
     *      authorization's `to` must be this contract; `from` must be
     *      msg.sender so the receipt's payer matches the authorizing signer.
     * @param layerNumber   WatcherGateV2 layer (1-13)
     * @param amount        USDC amount (smallest unit, 6 decimals)
     * @param validAfter    EIP-3009 authorization valid-after timestamp
     * @param validBefore   EIP-3009 authorization valid-before timestamp
     * @param nonce         EIP-3009 unique authorization nonce
     * @param v,r,s         EIP-3009 signature components
     * @return receiptHash  Unique proof of payment — present to WatcherGateV2
     */
    function castSpellWithUSDC(
        uint256 layerNumber,
        uint256 amount,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8   v,
        bytes32 r,
        bytes32 s
    )
        external
        whenNotPaused
        returns (bytes32 receiptHash)
    {
        require(layerNumber >= 1 && layerNumber <= 13, "SpellPaymentV2: invalid layer");
        require(usdcToken != address(0), "SpellPaymentV2: USDC not configured");

        uint256 minPrice = layerPriceUSDC[uint8(layerNumber)];
        if (minPrice > 0) {
            require(amount >= minPrice, "SpellPaymentV2: USDC payment below layer price");
        } else {
            require(amount > 0, "SpellPaymentV2: payment required");
        }

        SpellTier tier = _classifyLayer(uint8(layerNumber));

        // Pull USDC directly from the payer via their signed authorization.
        IERC3009(usdcToken).receiveWithAuthorization(
            msg.sender,
            address(this),
            amount,
            validAfter,
            validBefore,
            nonce,
            v, r, s
        );

        receiptHash = keccak256(
            abi.encodePacked(
                msg.sender,
                layerNumber,
                amount,
                block.timestamp,
                nonce,
                uint8(SpellCurrency.USDC)
            )
        );

        uint256 expiresAt = block.timestamp + ACCESS_DURATION;

        receipts[receiptHash] = SpellReceipt({
            receiptHash:     receiptHash,
            payer:           msg.sender,
            layerNumber:     layerNumber,
            amountPaid:      amount,
            accessExpiresAt: expiresAt,
            tier:            tier,
            currency:        SpellCurrency.USDC,
            consumed:        false
        });

        emit SpellCast(receiptHash, msg.sender, layerNumber, amount, tier, SpellCurrency.USDC);
    }

    // ─── Receipt Verification ─────────────────────────────────────────────────

    /**
     * @notice Verify a receipt — used by WatcherGateV2 before granting access.
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
     * @dev Callable by WatcherGateV2 or owner. WatcherGateV2 calls this itself
     *      after verifying a receipt and before granting access, so a receipt
     *      can never be presented twice (v1's gap — WatcherGate never called
     *      consumeReceipt, so the same receipt could be replayed until expiry).
     */
    function consumeReceipt(bytes32 receiptHash) external {
        require(
            msg.sender == owner || msg.sender == watcherGate,
            "SpellPaymentV2: not authorised"
        );
        SpellReceipt storage r = receipts[receiptHash];
        require(!r.consumed, "SpellPaymentV2: already consumed");
        require(r.accessExpiresAt > block.timestamp, "SpellPaymentV2: receipt expired");

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
        require(balance > 0, "SpellPaymentV2: nothing to withdraw");

        (bool sent,) = owner.call{value: balance}("");
        require(sent, "SpellPaymentV2: withdrawal failed");
    }

    /**
     * @notice Withdraw collected USDC to owner.
     */
    function withdrawUSDC() external onlyOwner {
        require(usdcToken != address(0), "SpellPaymentV2: USDC not configured");
        (bool ok, bytes memory data) = usdcToken.call(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        require(ok && data.length >= 32, "SpellPaymentV2: balance query failed");
        uint256 balance = abi.decode(data, (uint256));
        require(balance > 0, "SpellPaymentV2: nothing to withdraw");

        (bool sent, bytes memory sentData) = usdcToken.call(
            abi.encodeWithSignature("transfer(address,uint256)", owner, balance)
        );
        require(sent && (sentData.length == 0 || abi.decode(sentData, (bool))), "SpellPaymentV2: USDC transfer failed");
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
