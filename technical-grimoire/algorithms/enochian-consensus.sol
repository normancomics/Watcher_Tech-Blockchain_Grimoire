// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title EnochianConsensus
 * @notice Angelic order-based validation — consensus inspired by the Enochian system
 * @dev Implements a hierarchical validator system modeled on the angelic hierarchy
 *      as described in John Dee's Enochian system, 1 Enoch, and Pseudo-Dionysius.
 *
 * Hierarchical Model:
 *   Tier 1: Seraphim (Highest) — Super-validators with finality power
 *   Tier 2: Cherubim — Attestation validators  
 *   Tier 3: Thrones — Block proposers
 *   Tier 4: Dominions — MEV/ordering role
 *   Tier 5: Powers — Attack detection and slash authority
 *   Tier 6: Virtues — Bridging / relay role
 *   Tier 7: Principalities — Regional/shard validators
 *   Tier 8: Archangels — Emergency responders
 *   Tier 9: Angels — Base validators (anyone can join)
 *
 * Enochian Reference:
 *   The 30 Aethyrs (heavenly zones) → Validation epochs
 *   The 91 Governors → Validator slots (91 per shard)
 *   The Holy Table → State root commitment device
 *
 * References:
 *   - 1 Enoch 20 (Names of the seven archangels)
 *   - John Dee, Five Books of Mystery (1582–1583)
 *   - Pseudo-Dionysius, The Celestial Hierarchy (c. 500 CE)
 */

// ─── Enochian Validator Tiers ────────────────────────────────────────────────

enum AngelicTier {
    Seraphim,       // Tier 1 — finality authority
    Cherubim,       // Tier 2 — attestation
    Thrones,        // Tier 3 — block proposal
    Dominions,      // Tier 4 — transaction ordering
    Powers,         // Tier 5 — slashing authority
    Virtues,        // Tier 6 — bridge/relay
    Principalities, // Tier 7 — shard validation
    Archangels,     // Tier 8 — emergency response
    Angels          // Tier 9 — base validators (open entry)
}

// ─── Validator Structures ────────────────────────────────────────────────────

struct EnochianValidator {
    address validatorAddress;
    AngelicTier tier;
    uint256 stake;              // ETH staked (in wei)
    uint256 reputationScore;    // 0–1000 scale
    uint256 attestationCount;   // Total attestations made
    uint256 slashCount;         // Times slashed
    bytes32 enochianName;       // Derived Enochian identifier
    bool active;
}

struct ConsensusRound {
    uint256 roundId;
    uint256 aethyr;             // Which of 30 Aethyrs (epoch mod 30)
    bytes32 proposedStateRoot;
    uint256 attestations;
    uint256 seraphimSeal;       // Finality when > 0
    uint256 startBlock;
    bool finalized;
}

// ─── Enochian Consensus Contract ─────────────────────────────────────────────

contract EnochianConsensus {
    
    // ─── Constants ────────────────────────────────────────────────────────────
    
    uint256 public constant SERAPHIM_MIN_STAKE       = 1000 ether;
    uint256 public constant CHERUBIM_MIN_STAKE       = 500 ether;
    uint256 public constant ARCHANGEL_MIN_STAKE      = 100 ether;
    uint256 public constant ANGEL_MIN_STAKE          = 32 ether;
    
    uint256 public constant GOVERNORS_PER_AETHYR     = 91;   // John Dee's number
    uint256 public constant TOTAL_AETHYRS             = 30;   // 30 Heavenly Zones
    uint256 public constant FINALITY_THRESHOLD        = 2;    // Seraphim seals needed
    uint256 public constant ATTESTATION_QUORUM        = 67;   // 2/3 of validators
    
    // Enochian call "MADRIAX" — the invocation of the Aethyrs
    bytes32 public constant MADRIAX = keccak256("MADRIAX_ENOCHIAN_INVOCATION");
    
    // ─── State ─────────────────────────────────────────────────────────────────
    
    mapping(address => EnochianValidator) public validators;
    mapping(uint256 => ConsensusRound) public rounds;
    mapping(uint256 => mapping(address => bool)) public hasAttested;
    
    address[] public validatorSet;
    uint256 public currentRound;
    uint256 public totalStaked;
    
    // The Holy Table — state commitment device
    bytes32 public holyTable;   // Current canonical state root
    
    // ─── Events ───────────────────────────────────────────────────────────────
    
    event ValidatorRegistered(
        address indexed validator,
        AngelicTier tier,
        bytes32 enochianName,
        uint256 stake
    );
    
    event RoundOpened(
        uint256 indexed roundId,
        uint256 aethyr,
        address indexed proposer,
        bytes32 proposedStateRoot
    );
    
    event Attestation(
        uint256 indexed roundId,
        address indexed attester,
        AngelicTier tier,
        uint256 attestationWeight
    );
    
    event SeraphimSeal(
        uint256 indexed roundId,
        address indexed seraph,
        bytes32 finalStateRoot
    );
    
    event Finalized(
        uint256 indexed roundId,
        bytes32 finalStateRoot,
        uint256 aethyr
    );
    
    event Slashed(
        address indexed validator,
        uint256 slashedAmount,
        string reason
    );
    
    // ─── Constructor ──────────────────────────────────────────────────────────
    
    constructor() {
        holyTable = bytes32(0);
        currentRound = 1;
    }
    
    // ─── Registration ─────────────────────────────────────────────────────────
    
    /**
     * @notice Register as an Enochian validator
     * @dev Tier is automatically assigned based on stake amount
     */
    function registerValidator() external payable {
        require(msg.value >= ANGEL_MIN_STAKE, "Below minimum angel stake (32 ETH)");
        require(!validators[msg.sender].active, "Already registered");
        
        AngelicTier tier = _assignTier(msg.value);
        bytes32 enochianName = _deriveEnochianName(msg.sender);
        
        validators[msg.sender] = EnochianValidator({
            validatorAddress: msg.sender,
            tier: tier,
            stake: msg.value,
            reputationScore: 500,  // Start at midpoint
            attestationCount: 0,
            slashCount: 0,
            enochianName: enochianName,
            active: true
        });
        
        validatorSet.push(msg.sender);
        totalStaked += msg.value;
        
        emit ValidatorRegistered(msg.sender, tier, enochianName, msg.value);
    }
    
    // ─── Block Proposal (Thrones) ─────────────────────────────────────────────
    
    /**
     * @notice Propose a new state root — only Thrones and above can propose
     * @param proposedRoot The new state root being proposed
     */
    function proposeBlock(bytes32 proposedRoot) external {
        EnochianValidator storage proposer = validators[msg.sender];
        require(proposer.active, "Not an active validator");
        require(
            proposer.tier <= AngelicTier.Thrones,
            "Insufficient tier: Thrones or above required"
        );
        
        uint256 aethyr = currentRound % TOTAL_AETHYRS;
        
        rounds[currentRound] = ConsensusRound({
            roundId: currentRound,
            aethyr: aethyr,
            proposedStateRoot: proposedRoot,
            attestations: 0,
            seraphimSeal: 0,
            startBlock: block.number,
            finalized: false
        });
        
        emit RoundOpened(currentRound, aethyr, msg.sender, proposedRoot);
    }
    
    // ─── Attestation (Cherubim + Angels) ─────────────────────────────────────
    
    /**
     * @notice Attest to the current round's proposed state root
     * @dev Attestation weight is proportional to tier
     */
    function attest() external {
        EnochianValidator storage attester = validators[msg.sender];
        require(attester.active, "Not an active validator");
        require(!hasAttested[currentRound][msg.sender], "Already attested");
        
        ConsensusRound storage round = rounds[currentRound];
        require(!round.finalized, "Round already finalized");
        
        hasAttested[currentRound][msg.sender] = true;
        
        uint256 weight = _attestationWeight(attester.tier);
        round.attestations += weight;
        attester.attestationCount++;
        
        // Increase reputation for participation
        if (attester.reputationScore < 1000) {
            attester.reputationScore += 1;
        }
        
        emit Attestation(currentRound, msg.sender, attester.tier, weight);
        
        // Check if we've reached quorum
        _checkFinality();
    }
    
    // ─── Finality (Seraphim) ──────────────────────────────────────────────────
    
    /**
     * @notice Apply Seraphim seal — Seraphim grant finality power
     * @dev Requires 2 Seraphim seals for absolute finality
     */
    function applySeal() external {
        EnochianValidator storage seraph = validators[msg.sender];
        require(seraph.active, "Not an active validator");
        require(seraph.tier == AngelicTier.Seraphim, "Only Seraphim can seal");
        
        ConsensusRound storage round = rounds[currentRound];
        require(!round.finalized, "Already finalized");
        require(round.attestations > 0, "No attestations to seal");
        
        round.seraphimSeal++;
        
        emit SeraphimSeal(
            currentRound, 
            msg.sender, 
            round.proposedStateRoot
        );
        
        // Two Seraphim seals = absolute finality
        if (round.seraphimSeal >= FINALITY_THRESHOLD) {
            _finalizeRound(round);
        }
    }
    
    // ─── Slashing (Powers) ────────────────────────────────────────────────────
    
    /**
     * @notice Slash a validator for misbehavior — Powers tier authority
     * @param maliciousValidator Address of the validator to slash
     * @param reason Description of the violation
     */
    function slash(
        address maliciousValidator,
        string calldata reason
    ) external {
        require(
            validators[msg.sender].tier <= AngelicTier.Powers,
            "Only Powers or above can slash"
        );
        
        EnochianValidator storage target = validators[maliciousValidator];
        require(target.active, "Validator not active");
        
        // Slash 1/8 of stake for first offense, increasing with repeat offenses
        uint256 slashAmount = target.stake / (8 - target.slashCount);
        
        target.stake -= slashAmount;
        target.reputationScore = target.reputationScore > 100
            ? target.reputationScore - 100
            : 0;
        target.slashCount++;
        
        // Deactivate if stake falls below minimum
        if (target.stake < ANGEL_MIN_STAKE) {
            target.active = false;
        }
        
        totalStaked -= slashAmount;
        
        emit Slashed(maliciousValidator, slashAmount, reason);
    }
    
    // ─── Aethyr Queries ───────────────────────────────────────────────────────
    
    /**
     * @notice Get the current Aethyr (epoch identifier)
     * @dev Aethyrs cycle 1→30 as in John Dee's system
     */
    function currentAethyr() external view returns (uint256) {
        return (currentRound % TOTAL_AETHYRS) + 1;
    }
    
    /**
     * @notice Get Aethyr name (simplified — uses 3-letter Enochian names)
     */
    function aethyrName(uint256 aethyr) external pure returns (string memory) {
        string[30] memory aethyrs = [
            "LIL", "ARN", "ZOM", "PAZ", "LIT", "MAZ", "DEO", "ZID", "ZIP",
            "ZAX", "ICH", "LOE", "ZIM", "UTA", "OXO", "LEA", "TAN", "ZEN",
            "POP", "KHR", "ASP", "LIN", "TOR", "NIA", "UTI", "DES", "ZAA",
            "BAG", "RII", "TEX"
        ];
        require(aethyr >= 1 && aethyr <= 30, "Invalid Aethyr");
        return aethyrs[aethyr - 1];
    }
    
    // ─── Internal Functions ───────────────────────────────────────────────────
    
    function _assignTier(uint256 stake) internal pure returns (AngelicTier) {
        if (stake >= SERAPHIM_MIN_STAKE)  return AngelicTier.Seraphim;
        if (stake >= CHERUBIM_MIN_STAKE)  return AngelicTier.Cherubim;
        if (stake >= ARCHANGEL_MIN_STAKE) return AngelicTier.Archangels;
        return AngelicTier.Angels;
    }
    
    function _deriveEnochianName(address addr) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(MADRIAX, addr, block.chainid));
    }
    
    function _attestationWeight(AngelicTier tier) internal pure returns (uint256) {
        // Higher tiers have more voting weight
        if (tier == AngelicTier.Seraphim)    return 9;
        if (tier == AngelicTier.Cherubim)    return 8;
        if (tier == AngelicTier.Thrones)     return 7;
        if (tier == AngelicTier.Dominions)   return 6;
        if (tier == AngelicTier.Powers)      return 5;
        if (tier == AngelicTier.Virtues)     return 4;
        if (tier == AngelicTier.Principalities) return 3;
        if (tier == AngelicTier.Archangels)  return 2;
        return 1; // Angels
    }
    
    function _checkFinality() internal {
        ConsensusRound storage round = rounds[currentRound];
        uint256 totalWeight = validatorSet.length * 9; // Max possible weight
        
        if (round.attestations * 100 >= totalWeight * ATTESTATION_QUORUM) {
            // Quorum reached — await Seraphim seal
        }
    }
    
    function _finalizeRound(ConsensusRound storage round) internal {
        round.finalized = true;
        holyTable = round.proposedStateRoot;
        
        emit Finalized(currentRound, round.proposedStateRoot, round.aethyr);
        
        currentRound++;
    }
    
    // ─── View Functions ───────────────────────────────────────────────────────
    
    function getValidator(address addr) external view returns (EnochianValidator memory) {
        return validators[addr];
    }
    
    function getRound(uint256 roundId) external view returns (ConsensusRound memory) {
        return rounds[roundId];
    }
    
    function validatorCount() external view returns (uint256) {
        return validatorSet.length;
    }
}
