// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title QliphoticForkResistance
 * @notice Anti-51% attack mechanisms inspired by Qliphotic (shadow) counterforces
 * @dev The Qliphoth (קְלִיפּוֹת, "shells" or "husks") are the shadow side of the
 *      Kabbalistic Tree of Life — 10 adverse forces that mirror and oppose the Sefirot.
 *      In blockchain security, a 51% attack is the archetypal "Qliphotic" threat:
 *      a shadow force seizing control of the canonical chain.
 *
 *      This contract implements multiple layers of 51% attack resistance
 *      by mapping each Qliphoth to a specific attack vector and its countermeasure.
 *
 * Qliphoth → Attack Vector Mapping:
 *   Thaumiel (Two-headed)  → Chain split / network partition
 *   Ghagiel (Hinderers)    → Transaction censorship
 *   Sathariel (Concealers) → Hidden selfish mining
 *   Gha'agsheblah          → Reorganization attacks
 *   Golachab (Burners)     → Smart contract exploitation
 *   Thagirion (Disputers)  → Governance attacks
 *   Gharab Tzerek          → Oracle manipulation
 *   Samael (Left-hand)     → MEV extraction
 *   Gamaliel (Obscene)     → Flash loan attacks
 *   Lilith (Night-demon)   → Private key theft
 *
 * References:
 *   - Qliphoth (Kabbalah) — shadow emanations
 *   - kabbalistic-merkle-trees.md
 *   - Selfish Mining paper (Eyal & Sirer, 2013)
 *   - Nakamoto Consensus paper (2008)
 */

// ─── Attack Vector Enumeration ────────────────────────────────────────────────

enum QliphothicAttack {
    Thaumiel,       // Chain split / long-range attack
    Ghagiel,        // Transaction censorship
    Sathariel,      // Selfish mining
    GhaAgsheblah,   // Reorganization attack
    Golachab,       // Smart contract exploit
    Thagirion,      // Governance capture
    GharabTzerek,   // Oracle manipulation
    Samael,         // MEV extraction
    Gamaliel,       // Flash loan attack
    Lilith          // Private key / social engineering
}

// ─── Defense Structures ───────────────────────────────────────────────────────

struct AttackSignal {
    QliphothicAttack attackType;
    uint256 detectedBlock;
    uint256 riskScore;          // 0–100
    address suspectedAttacker;
    bytes32 evidenceHash;
    bool mitigated;
}

struct ForkResistanceConfig {
    uint256 maxReorgDepth;          // Max reorganization allowed (blocks)
    uint256 finalizationDelay;      // Blocks before finalization
    uint256 censorshipThreshold;    // Blocks before censorship alert
    uint256 mevExtractionLimit;     // Max MEV % of block reward
    uint256 flashLoanTimelock;      // Blocks: flash loan governance block
    uint256 oracleDeviationLimit;   // Max % price deviation per block
}

// ─── Main Contract ────────────────────────────────────────────────────────────

contract QliphoticForkResistance {
    
    // ─── Constants ────────────────────────────────────────────────────────────
    
    // The Seal of the Abyss — separator between Qliphoth and Sefirot
    // Represents the line between manageable risk and catastrophic attack
    uint256 public constant ABYSS_THRESHOLD = 51;  // % of stake needed for attack
    
    // Daath — the hidden knowledge sphere (max depth before chain dies)
    uint256 public constant DAATH_REORG_LIMIT = 100;  // blocks
    
    // ─── State ────────────────────────────────────────────────────────────────
    
    ForkResistanceConfig public config;
    
    mapping(uint256 => AttackSignal) public detectedAttacks;
    mapping(address => uint256) public attackerReputation;  // 0=trustworthy, 100=known attacker
    mapping(uint256 => bytes32) public blockHashHistory;    // For reorg detection
    mapping(address => uint256) public lastTransactionBlock; // For censorship detection
    
    uint256 public attackCount;
    uint256 public totalMitigations;
    
    address public guardian;    // The Watcher — monitoring authority
    
    // ─── Events ───────────────────────────────────────────────────────────────
    
    event QliphothicAttackDetected(
        uint256 indexed attackId,
        QliphothicAttack attackType,
        address indexed suspect,
        uint256 riskScore,
        uint256 blockNumber
    );
    
    event AttackMitigated(
        uint256 indexed attackId,
        QliphothicAttack attackType,
        string mitigationMethod
    );
    
    event ReorgDetected(
        uint256 indexed depth,
        bytes32 expectedHash,
        bytes32 actualHash,
        uint256 blockNumber
    );
    
    event CensorshipAlert(
        address indexed censoredAddress,
        uint256 blocksWithoutInclusion
    );
    
    event OracleDeviationAlert(
        address indexed oracle,
        uint256 reportedPrice,
        uint256 expectedPrice,
        uint256 deviationPercent
    );
    
    // ─── Constructor ──────────────────────────────────────────────────────────
    
    constructor(address _guardian) {
        guardian = _guardian;
        
        // Initialize default fork resistance configuration
        config = ForkResistanceConfig({
            maxReorgDepth: 6,           // 6 blocks = standard Bitcoin finality
            finalizationDelay: 32,      // 32 blocks = one epoch
            censorshipThreshold: 10,    // 10 blocks without inclusion = censorship
            mevExtractionLimit: 20,     // Max 20% of block reward as MEV
            flashLoanTimelock: 1,       // Flash loans cannot affect governance in same block
            oracleDeviationLimit: 5     // Max 5% price change per block
        });
    }
    
    modifier onlyGuardian() {
        require(msg.sender == guardian, "Only the Watcher-Guardian");
        _;
    }
    
    // ─── Thaumiel Defense: Chain Split Resistance ─────────────────────────────
    
    /**
     * @notice Detect and respond to potential chain splits
     * @dev Compares current block hash against historical record
     *      Flags deviations as potential long-range attacks
     */
    function detectChainSplit(
        uint256 blockNumber,
        bytes32 reportedHash
    ) external onlyGuardian returns (bool splitDetected) {
        bytes32 expectedHash = blockHashHistory[blockNumber];
        
        if (expectedHash == bytes32(0)) {
            // No record — store it
            blockHashHistory[blockNumber] = reportedHash;
            return false;
        }
        
        if (expectedHash != reportedHash) {
            _recordAttack(
                QliphothicAttack.Thaumiel,
                address(0),
                90,
                keccak256(abi.encodePacked(blockNumber, reportedHash, expectedHash))
            );
            
            emit ReorgDetected(
                block.number - blockNumber,
                expectedHash,
                reportedHash,
                blockNumber
            );
            
            return true;
        }
        
        return false;
    }
    
    // ─── Ghagiel Defense: Anti-Censorship ────────────────────────────────────
    
    /**
     * @notice Report transaction censorship
     * @dev If a transaction has been pending for > threshold blocks, flag censorship
     */
    function reportCensorship(
        address victim,
        uint256 txSubmittedBlock
    ) external returns (bool censorshipConfirmed) {
        uint256 blocksWaiting = block.number - txSubmittedBlock;
        
        if (blocksWaiting > config.censorshipThreshold) {
            _recordAttack(
                QliphothicAttack.Ghagiel,
                address(0),  // Censoring validator unknown
                (blocksWaiting * 100) / config.censorshipThreshold,
                keccak256(abi.encodePacked(victim, txSubmittedBlock))
            );
            
            emit CensorshipAlert(victim, blocksWaiting);
            return true;
        }
        
        return false;
    }
    
    // ─── GhaAgsheblah Defense: Reorg Resistance ──────────────────────────────
    
    /**
     * @notice Verify that a reorganization is within safe depth limits
     * @param reorgDepth Number of blocks being reorganized
     * @return safe Whether this reorg depth is within safe limits
     */
    function verifyReorgSafety(
        uint256 reorgDepth
    ) external returns (bool safe) {
        if (reorgDepth > config.maxReorgDepth) {
            _recordAttack(
                QliphothicAttack.GhaAgsheblah,
                address(0),
                _reorgRiskScore(reorgDepth),
                keccak256(abi.encodePacked(reorgDepth, block.number))
            );
            return false;
        }
        return true;
    }
    
    // ─── Gamaliel Defense: Flash Loan Attack Resistance ──────────────────────
    
    /**
     * @notice Check if a governance action is protected from flash loan influence
     * @dev Flash loans are borrowed and repaid in one transaction
     *      Governance actions must be block-timelock protected
     * @param proposalBlock Block in which the proposal was made
     * @param currentBlock Current block number
     */
    function isFlashLoanSafe(
        uint256 proposalBlock,
        uint256 currentBlock
    ) external returns (bool protected) {
        if (currentBlock <= proposalBlock + config.flashLoanTimelock) {
            _recordAttack(
                QliphothicAttack.Gamaliel,
                msg.sender,
                85,
                keccak256(abi.encodePacked(proposalBlock, currentBlock))
            );
            return false;
        }
        return true;
    }
    
    // ─── GharabTzerek Defense: Oracle Manipulation Resistance ────────────────
    
    /**
     * @notice Validate an oracle price report against manipulation thresholds
     * @param oracle Address of the oracle reporting
     * @param reportedPrice Price being reported
     * @param previousPrice Last confirmed price
     */
    function validateOracleReport(
        address oracle,
        uint256 reportedPrice,
        uint256 previousPrice
    ) external returns (bool valid) {
        if (previousPrice == 0) return true;  // No baseline yet
        
        uint256 deviation = reportedPrice > previousPrice
            ? ((reportedPrice - previousPrice) * 100) / previousPrice
            : ((previousPrice - reportedPrice) * 100) / previousPrice;
        
        if (deviation > config.oracleDeviationLimit) {
            _recordAttack(
                QliphothicAttack.GharabTzerek,
                oracle,
                (deviation * 100) / config.oracleDeviationLimit,
                keccak256(abi.encodePacked(oracle, reportedPrice, previousPrice))
            );
            
            emit OracleDeviationAlert(oracle, reportedPrice, previousPrice, deviation);
            return false;
        }
        
        return true;
    }
    
    // ─── Mitigation ───────────────────────────────────────────────────────────
    
    /**
     * @notice Mark an attack as mitigated
     * @param attackId The ID of the attack signal
     * @param mitigationMethod Description of how it was mitigated
     */
    function mitigateAttack(
        uint256 attackId,
        string calldata mitigationMethod
    ) external onlyGuardian {
        AttackSignal storage attack = detectedAttacks[attackId];
        require(!attack.mitigated, "Already mitigated");
        
        attack.mitigated = true;
        totalMitigations++;
        
        emit AttackMitigated(attackId, attack.attackType, mitigationMethod);
    }
    
    // ─── Configuration ────────────────────────────────────────────────────────
    
    /**
     * @notice Update fork resistance parameters
     * @dev Only the Guardian (Watcher-Archon) can update configuration
     */
    function updateConfig(
        ForkResistanceConfig calldata newConfig
    ) external onlyGuardian {
        require(newConfig.maxReorgDepth <= DAATH_REORG_LIMIT, "Exceeds Daath limit");
        config = newConfig;
    }
    
    // ─── View Functions ───────────────────────────────────────────────────────
    
    function getAttack(uint256 attackId) external view returns (AttackSignal memory) {
        return detectedAttacks[attackId];
    }
    
    function getDefenseStatus() external view returns (
        uint256 totalAttacks,
        uint256 mitigated,
        uint256 unmitigated
    ) {
        return (
            attackCount,
            totalMitigations,
            attackCount - totalMitigations
        );
    }
    
    // ─── Internal Helpers ─────────────────────────────────────────────────────
    
    function _recordAttack(
        QliphothicAttack attackType,
        address suspect,
        uint256 riskScore,
        bytes32 evidence
    ) internal returns (uint256 attackId) {
        attackId = ++attackCount;
        
        detectedAttacks[attackId] = AttackSignal({
            attackType: attackType,
            detectedBlock: block.number,
            riskScore: riskScore > 100 ? 100 : riskScore,
            suspectedAttacker: suspect,
            evidenceHash: evidence,
            mitigated: false
        });
        
        if (suspect != address(0)) {
            attackerReputation[suspect] = attackerReputation[suspect] < 90
                ? attackerReputation[suspect] + 10
                : 100;
        }
        
        emit QliphothicAttackDetected(
            attackId,
            attackType,
            suspect,
            riskScore,
            block.number
        );
    }
    
    function _reorgRiskScore(uint256 reorgDepth) internal view returns (uint256) {
        if (reorgDepth >= DAATH_REORG_LIMIT) return 100;
        return (reorgDepth * 100) / DAATH_REORG_LIMIT;
    }
}
