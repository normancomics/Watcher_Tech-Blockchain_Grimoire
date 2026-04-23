// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SpellPayment
 * @notice HTTP 402 Payment Required integration for knowledge access
 * @dev Implements x402 payment protocol for on-chain micropayments.
 *      "Spell" payments — casting the right incantation (payment) opens
 *      the grimoire's gates.
 *
 * x402 Protocol:
 *   The HTTP 402 status code ("Payment Required") has been dormant for decades.
 *   x402 revives it as a standard for machine-readable payment requirements,
 *   enabling AI agents and browsers to automatically fulfill payment demands.
 *
 *   Flow:
 *     1. Client requests resource → Server returns 402 + payment details
 *     2. Client makes on-chain payment → Gets payment proof (receipt hash)
 *     3. Client presents proof → Server returns resource
 *
 * Spell Taxonomy:
 *   Cantrip   — Micro payment (< 0.001 ETH) for quick knowledge glimpses
 *   Ritual    — Standard payment for full knowledge access
 *   Ceremony  — Premium payment for agent-grade extended access
 *   Invocation — Maximum payment for perpetual access rights
 */

// ─── Payment Structures ───────────────────────────────────────────────────────

enum SpellTier {
    Cantrip,     // < 0.001 ETH
    Ritual,      // 0.001–0.01 ETH
    Ceremony,    // 0.01–0.1 ETH
    Invocation   // > 0.1 ETH
}

struct PaymentRequirement {
    uint256 resourceId;         // What resource is being paid for
    uint256 price;              // Price in wei
    uint256 accessDuration;     // How long the payment grants access (seconds)
    SpellTier tier;
    address paymentReceiver;    // Who receives the payment
    bool active;                // Whether this payment requirement is active
}

struct SpellReceipt {
    bytes32 receiptHash;        // Unique receipt identifier
    address payer;
    uint256 resourceId;
    uint256 amountPaid;
    uint256 accessExpiresAt;
    SpellTier tier;
    bool consumed;              // True once the receipt has been presented
}

// ─── SpellPayment Contract ────────────────────────────────────────────────────

contract SpellPayment {
    
    // ─── Constants ────────────────────────────────────────────────────────────
    
    uint256 public constant CANTRIP_MAX   = 0.001 ether;
    uint256 public constant RITUAL_MAX    = 0.01 ether;
    uint256 public constant CEREMONY_MAX  = 0.1 ether;
    
    uint256 public constant PROTOCOL_FEE_BPS = 250;  // 2.5% protocol fee
    uint256 public constant AGENT_DISCOUNT_BPS = 500; // 5% discount for verified agents
    
    // ─── State ────────────────────────────────────────────────────────────────
    
    mapping(uint256 => PaymentRequirement) public requirements;
    mapping(bytes32 => SpellReceipt) public receipts;
    mapping(address => mapping(uint256 => uint256)) public accessExpirations;
    mapping(address => bool) public verifiedAgents;
    
    uint256 public requirementCount;
    address public owner;
    address public protocolTreasury;
    uint256 public totalRevenue;
    
    // ─── Events ───────────────────────────────────────────────────────────────
    
    /**
     * @notice Emitted when a resource payment requirement is created
     * @dev x402 clients listen for this to understand what resources cost
     */
    event PaymentGateCreated(
        uint256 indexed resourceId,
        uint256 price,
        uint256 accessDuration,
        SpellTier tier
    );
    
    /**
     * @notice Emitted when a spell payment is cast successfully
     * @dev The receiptHash is the x402 proof presented to the API server
     */
    event SpellCast(
        bytes32 indexed receiptHash,
        address indexed payer,
        uint256 indexed resourceId,
        uint256 amount,
        SpellTier tier
    );
    
    event ReceiptConsumed(bytes32 indexed receiptHash, address consumer);
    event AgentVerified(address indexed agent, uint256 timestamp);
    event PaymentRequirementUpdated(uint256 indexed resourceId, uint256 newPrice);
    
    // ─── Constructor ──────────────────────────────────────────────────────────
    
    constructor(address _treasury) {
        owner = msg.sender;
        protocolTreasury = _treasury;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    // ─── Payment Gate Management ──────────────────────────────────────────────
    
    /**
     * @notice Create a payment requirement for a resource
     * @dev This is the "402 response body" — what x402 clients read to know the price
     * @param resourceId The resource identifier (maps to API endpoint hash)
     * @param price Price in wei
     * @param accessDuration Seconds of access granted by payment
     * @param receiver Address that receives payments for this resource
     */
    function createPaymentGate(
        uint256 resourceId,
        uint256 price,
        uint256 accessDuration,
        address receiver
    ) external onlyOwner {
        SpellTier tier = _classifyPayment(price);
        
        requirements[resourceId] = PaymentRequirement({
            resourceId: resourceId,
            price: price,
            accessDuration: accessDuration,
            tier: tier,
            paymentReceiver: receiver,
            active: true
        });
        
        requirementCount++;
        
        emit PaymentGateCreated(resourceId, price, accessDuration, tier);
    }
    
    /**
     * @notice Update the price for an existing payment gate
     */
    function updatePrice(uint256 resourceId, uint256 newPrice) external onlyOwner {
        require(requirements[resourceId].active, "Gate not active");
        requirements[resourceId].price = newPrice;
        requirements[resourceId].tier = _classifyPayment(newPrice);
        
        emit PaymentRequirementUpdated(resourceId, newPrice);
    }
    
    // ─── Spell Casting (Payment) ──────────────────────────────────────────────
    
    /**
     * @notice Cast a spell (make a payment) to gain resource access
     * @dev Implements the x402 payment flow on-chain
     *      Returns a receipt hash that serves as the access proof
     *
     * x402 Flow:
     *   1. Client receives 402 → reads resourceId from response headers
     *   2. Client calls castSpell(resourceId) with msg.value >= price
     *   3. Contract emits SpellCast event with receiptHash
     *   4. Client presents receiptHash to API → receives resource
     *
     * @param resourceId The resource being paid for
     * @return receiptHash The proof of payment (present to API server)
     */
    function castSpell(
        uint256 resourceId
    ) external payable returns (bytes32 receiptHash) {
        PaymentRequirement storage req = requirements[resourceId];
        require(req.active, "No active payment gate for resource");
        
        uint256 effectivePrice = req.price;
        
        // Apply agent discount if verified
        if (verifiedAgents[msg.sender]) {
            effectivePrice = effectivePrice * (10000 - AGENT_DISCOUNT_BPS) / 10000;
        }
        
        require(msg.value >= effectivePrice, "Insufficient payment — spell fizzled");
        
        // Generate unique receipt hash
        receiptHash = keccak256(
            abi.encodePacked(
                msg.sender,
                resourceId,
                msg.value,
                block.timestamp,
                block.number
            )
        );
        
        uint256 expiresAt = block.timestamp + req.accessDuration;
        
        // Store receipt
        receipts[receiptHash] = SpellReceipt({
            receiptHash: receiptHash,
            payer: msg.sender,
            resourceId: resourceId,
            amountPaid: msg.value,
            accessExpiresAt: expiresAt,
            tier: req.tier,
            consumed: false
        });
        
        // Record access expiration
        if (accessExpirations[msg.sender][resourceId] < expiresAt) {
            accessExpirations[msg.sender][resourceId] = expiresAt;
        }
        
        // Distribute payment
        _distributePayment(msg.value, req.paymentReceiver);
        
        // Refund excess
        if (msg.value > effectivePrice) {
            (bool refunded,) = msg.sender.call{value: msg.value - effectivePrice}("");
            require(refunded, "Refund failed");
        }
        
        totalRevenue += effectivePrice;
        
        emit SpellCast(receiptHash, msg.sender, resourceId, msg.value, req.tier);
    }
    
    // ─── Receipt Verification ─────────────────────────────────────────────────
    
    /**
     * @notice Verify a receipt is valid (for API server use)
     * @param receiptHash The hash presented by the client
     * @return valid Whether the receipt is valid and unexpired
     */
    function verifyReceipt(
        bytes32 receiptHash
    ) external view returns (bool valid, SpellReceipt memory receipt) {
        receipt = receipts[receiptHash];
        valid = (
            receipt.receiptHash == receiptHash &&
            !receipt.consumed &&
            receipt.accessExpiresAt > block.timestamp
        );
    }
    
    /**
     * @notice Consume a receipt (one-time use for pay-per-request model)
     * @dev Only the API server (owner) should call this after serving content
     */
    function consumeReceipt(bytes32 receiptHash) external onlyOwner {
        SpellReceipt storage receipt = receipts[receiptHash];
        require(!receipt.consumed, "Already consumed");
        require(receipt.accessExpiresAt > block.timestamp, "Receipt expired");
        
        receipt.consumed = true;
        emit ReceiptConsumed(receiptHash, receipt.payer);
    }
    
    /**
     * @notice Check if an address has active access to a resource
     */
    function hasAccess(
        address user,
        uint256 resourceId
    ) external view returns (bool) {
        return accessExpirations[user][resourceId] > block.timestamp;
    }
    
    // ─── Agent Management ─────────────────────────────────────────────────────
    
    /**
     * @notice Register an AI agent for the agent discount
     * @dev Agents verified through ERC-8004 or admin approval
     */
    function verifyAgent(address agent) external onlyOwner {
        verifiedAgents[agent] = true;
        emit AgentVerified(agent, block.timestamp);
    }
    
    // ─── x402 Metadata ───────────────────────────────────────────────────────
    
    /**
     * @notice Get the x402 payment details for a resource
     * @dev This is what x402-compatible clients read to know payment requirements
     * @return price Price in wei
     * @return tier Payment tier classification
     * @return accessDuration Seconds of access
     * @return contractAddress This contract address (for payment destination)
     */
    function getPaymentDetails(
        uint256 resourceId
    ) external view returns (
        uint256 price,
        SpellTier tier,
        uint256 accessDuration,
        address contractAddress
    ) {
        PaymentRequirement storage req = requirements[resourceId];
        return (req.price, req.tier, req.accessDuration, address(this));
    }
    
    // ─── Internal Functions ───────────────────────────────────────────────────
    
    function _classifyPayment(uint256 amount) internal pure returns (SpellTier) {
        if (amount < CANTRIP_MAX) return SpellTier.Cantrip;
        if (amount < RITUAL_MAX) return SpellTier.Ritual;
        if (amount < CEREMONY_MAX) return SpellTier.Ceremony;
        return SpellTier.Invocation;
    }
    
    function _distributePayment(
        uint256 amount,
        address receiver
    ) internal {
        uint256 protocolFee = (amount * PROTOCOL_FEE_BPS) / 10000;
        uint256 receiverAmount = amount - protocolFee;
        
        (bool feeSent,) = protocolTreasury.call{value: protocolFee}("");
        require(feeSent, "Protocol fee transfer failed");
        
        (bool receiverPaid,) = receiver.call{value: receiverAmount}("");
        require(receiverPaid, "Receiver payment failed");
    }
}
