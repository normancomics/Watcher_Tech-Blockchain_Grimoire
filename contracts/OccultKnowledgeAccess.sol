// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title OccultKnowledgeAccess
 * @author normancomics.eth 2026 A.D.
 * @notice Hierarchical knowledge layer registry with timed activation and alignment checks.
 *         Authored in the year of our Lord 2026 by normancomics.eth.
 *         Caution: This contract uses thematic naming drawn from extra-Biblical Enochian lore.
 *         Scripture warns against sorcery, divination, and forbidden arts (Deut 18:10-12).
 *         Use only for artistic, educational, or historical reference.
 */
contract OccultKnowledgeAccess {
    struct KnowledgeLayer {
        string domain;          // e.g., "Astrology", "Geomancy"
        string encodedRitual;   // Proto-Canaanite / Enochian sequences
        uint256 activationTime; // Cosmic / astrological timing
        address guardian;       // Ethical alignment overseer
        mapping(address => bool) aligned;
    }

    mapping(uint256 => KnowledgeLayer) public registry;
    mapping(address => bool) public globalAlignment;

    event KnowledgeRegistered(
        uint256 indexed id,
        string domain,
        uint256 activationTime,
        address guardian
    );
    event AccessGranted(uint256 indexed id, address user);
    event AccessDenied(uint256 indexed id, address user);
    event UserAlignmentSet(uint256 indexed id, address user, bool aligned);
    event GlobalAlignmentSet(address user, bool aligned);

    modifier onlyGuardian(uint256 id) {
        require(msg.sender == registry[id].guardian, "Not authorized by guardian");
        _;
    }

    modifier isAligned(uint256 id, address user) {
        require(
            registry[id].aligned[user] || globalAlignment[user],
            "User not ethically aligned"
        );
        _;
    }

    /**
     * @dev Register a new knowledge layer
     */
    function registerLayer(
        uint256 id,
        string memory domain,
        string memory encodedRitual,
        uint256 activationTime,
        address guardian
    ) external {
        KnowledgeLayer storage layer = registry[id];
        layer.domain = domain;
        layer.encodedRitual = encodedRitual;
        layer.activationTime = activationTime;
        layer.guardian = guardian;

        emit KnowledgeRegistered(id, domain, activationTime, guardian);
    }

    /**
     * @dev Request access to a knowledge layer
     */
    function requestAccess(uint256 id, address user) external isAligned(id, user) {
        KnowledgeLayer storage layer = registry[id];

        if (block.timestamp >= layer.activationTime) {
            emit AccessGranted(id, user);
        } else {
            emit AccessDenied(id, user);
        }
    }

    /**
     * @dev Set per-layer user alignment (guardian only)
     */
    function setUserAlignment(
        uint256 id,
        address user,
        bool aligned
    ) external onlyGuardian(id) {
        registry[id].aligned[user] = aligned;
        emit UserAlignmentSet(id, user, aligned);
    }

    /**
     * @dev Set global alignment (could be restricted to owner in production)
     */
    function setGlobalAlignment(address user, bool aligned) external {
        globalAlignment[user] = aligned;
        emit GlobalAlignmentSet(user, aligned);
    }
}
