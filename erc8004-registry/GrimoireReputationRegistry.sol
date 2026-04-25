// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GrimoireReputationRegistry
 * @author normancomics.eth — 2026 A.D.
 * @notice ERC-8004 reputation registry — on-chain feedback accumulator for agents.
 * @dev Feedback values are clamped to [-10, +10] per ERC-8004 spec.
 *      Cumulative reputationScore is the running sum of all feedback values.
 *      feedbackURI points to an IPFS document with the full review.
 *      feedbackHash is a content hash of the review document for integrity.
 */

contract GrimoireReputationRegistry {

    // ─── Structs ──────────────────────────────────────────────────────────────

    struct Feedback {
        address reviewer;
        uint256 agentId;
        int8    value;          // -10 to +10
        bytes32 tag1;           // searchable tag (e.g. "security", "reliability")
        bytes32 tag2;           // optional second tag
        string  feedbackURI;    // IPFS URI with full review text
        bytes32 feedbackHash;   // keccak256 content hash of the review document
        uint256 timestamp;
    }

    // ─── State ────────────────────────────────────────────────────────────────

    /// @notice Cumulative reputation score per agentId
    mapping(uint256 => int256) public reputationScore;

    /// @notice Feedback count per agentId
    mapping(uint256 => uint256) private _feedbackCount;

    /// @notice All feedback for an agentId: agentId → index → Feedback
    mapping(uint256 => mapping(uint256 => Feedback)) private _feedbacks;

    address public owner;

    // ─── Events ───────────────────────────────────────────────────────────────

    event FeedbackSubmitted(
        uint256 indexed agentId,
        address indexed reviewer,
        int8    value,
        bytes32 tag1,
        bytes32 tag2,
        string  feedbackURI,
        bytes32 feedbackHash,
        uint256 timestamp
    );

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "GrimoireReputationRegistry: not owner");
        _;
    }

    // ─── Feedback Submission ──────────────────────────────────────────────────

    /**
     * @notice Submit feedback for a registered agent.
     * @param agentId       The ERC-8004 agentId (tokenId from GrimoireERC8004Registry)
     * @param value         Feedback value (-10 to +10)
     * @param tag1          Primary searchable tag (e.g. bytes32("security"))
     * @param tag2          Optional secondary tag (bytes32(0) if unused)
     * @param feedbackURI   IPFS URI containing the full review document
     * @param feedbackHash  keccak256 content hash of the review document
     */
    function submitFeedback(
        uint256 agentId,
        int8    value,
        bytes32 tag1,
        bytes32 tag2,
        string  calldata feedbackURI,
        bytes32 feedbackHash
    ) external {
        require(agentId > 0,                    "GrimoireReputationRegistry: invalid agentId");
        require(value >= -10 && value <= 10,    "GrimoireReputationRegistry: value out of range");

        uint256 idx = _feedbackCount[agentId];
        _feedbacks[agentId][idx] = Feedback({
            reviewer:     msg.sender,
            agentId:      agentId,
            value:        value,
            tag1:         tag1,
            tag2:         tag2,
            feedbackURI:  feedbackURI,
            feedbackHash: feedbackHash,
            timestamp:    block.timestamp
        });

        _feedbackCount[agentId]  = idx + 1;
        reputationScore[agentId] += int256(value);

        emit FeedbackSubmitted(
            agentId,
            msg.sender,
            value,
            tag1,
            tag2,
            feedbackURI,
            feedbackHash,
            block.timestamp
        );
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    /**
     * @notice Returns the cumulative reputation score for `agentId`.
     */
    function getScore(uint256 agentId) external view returns (int256) {
        return reputationScore[agentId];
    }

    /**
     * @notice Returns the total number of feedback entries for `agentId`.
     */
    function getFeedbackCount(uint256 agentId) external view returns (uint256) {
        return _feedbackCount[agentId];
    }

    /**
     * @notice Returns a specific feedback entry for `agentId` at `index`.
     */
    function getFeedback(uint256 agentId, uint256 index)
        external view
        returns (Feedback memory)
    {
        require(index < _feedbackCount[agentId], "GrimoireReputationRegistry: index out of bounds");
        return _feedbacks[agentId][index];
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "GrimoireReputationRegistry: zero address");
        owner = newOwner;
    }
}
