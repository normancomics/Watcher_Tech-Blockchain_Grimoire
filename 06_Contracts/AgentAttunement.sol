// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AgentAttunement
 * @notice ERC-8004 agent bonding and identity registration
 * @dev Implements agent identity, capability registration, and reputation bonding
 *      based on the ERC-8004 (Agent Standard) draft specification.
 *
 * "Attunement" — The esoteric process by which a novice priest or mage
 * aligns their spiritual frequency with a deity, tradition, or magical system.
 * In blockchain terms: the process by which an AI agent bonds its identity
 * to a smart contract, establishing verifiable capability claims and reputation.
 *
 * Agent Card Standard (ERC-8004 draft):
 *   - Each agent has an on-chain "Agent Card" (JSON metadata)
 *   - Cards declare: name, capabilities, skills, endpoint URLs
 *   - Reputation is accumulated through successful task completion
 *   - Bonded ETH acts as a performance guarantee
 *
 * Grimoire-Specific Capabilities:
 *   - ESOTERIC_RAG: Retrieval-augmented generation from esoteric corpus
 *   - LUNAR_CALC: Celestial calculation and moon phase determination
 *   - SIGIL_GEN: Symbolic encoding and sigil generation
 *   - EXPLOIT_DETECT: Blockchain vulnerability pattern detection
 *   - ANCIENT_NLP: Natural language processing of ancient texts
 *   - RITUAL_VALIDATE: Ceremony and protocol validation
 *   - BLOCKCHAIN_DIVINATION: Predictive analysis via blockchain patterns
 */

// ─── Agent Structures ─────────────────────────────────────────────────────────

enum AgentCapability {
    ESOTERIC_RAG,         // 0 — Knowledge retrieval
    LUNAR_CALC,           // 1 — Celestial computation
    SIGIL_GEN,            // 2 — Symbolic encoding
    EXPLOIT_DETECT,       // 3 — Security analysis
    ANCIENT_NLP,          // 4 — Ancient text processing
    RITUAL_VALIDATE,      // 5 — Protocol verification
    BLOCKCHAIN_DIVINATION, // 6 — Predictive analysis
    SWARM_COORD,          // 7 — Multi-agent coordination
    PAYMENT_EXEC,         // 8 — x402 payment execution
    KNOWLEDGE_INDEX       // 9 — Grimoire indexing
}

enum AgentStatus {
    Unregistered,
    Pending,         // Registered, awaiting activation
    Active,          // Fully operational
    Suspended,       // Temporarily inactive (low reputation / investigation)
    Terminated       // Permanently deactivated
}

struct AgentCard {
    // Identity
    uint256 agentId;
    string name;
    string version;
    string description;
    address operator;          // Human/multisig that controls this agent
    address agentAddress;      // The agent's signing address
    
    // Capabilities
    AgentCapability[] capabilities;
    string endpointURL;        // A2A communication endpoint (HTTPS)
    string agentCardCID;       // IPFS CID of full agent card JSON
    
    // Bonding
    uint256 bondedETH;         // ETH bonded as performance guarantee
    uint256 reputation;        // 0–1000 scale
    uint256 tasksCompleted;
    uint256 tasksFailed;
    
    // Metadata
    AgentStatus status;
    uint256 registeredAt;
    uint256 lastActiveAt;
    
    // Watcher-specific
    bytes32 enochianName;      // Derived esoteric identifier
    bool isWatcherAgent;       // Part of the core Watcher swarm
}

struct AttunementProof {
    address agent;
    bytes32 capabilityHash;    // Hash of claimed capabilities
    bytes signature;           // Agent's signature proving key possession
    uint256 timestamp;
    bool verified;
}

// ─── AgentAttunement Contract ─────────────────────────────────────────────────

contract AgentAttunement {
    
    // ─── Constants ────────────────────────────────────────────────────────────
    
    uint256 public constant MIN_BOND_AMOUNT     = 0.1 ether;
    uint256 public constant WATCHER_BOND_AMOUNT = 1 ether;
    uint256 public constant MAX_REPUTATION      = 1000;
    uint256 public constant SLASH_AMOUNT_BPS    = 1000;  // 10% slash per failure
    uint256 public constant TASK_REWARD_REP     = 5;     // Reputation per successful task
    uint256 public constant TASK_PENALTY_REP    = 20;    // Reputation lost per failure
    
    // ─── State ────────────────────────────────────────────────────────────────
    
    mapping(uint256 => AgentCard) public agents;
    mapping(address => uint256) public addressToAgentId;
    mapping(uint256 => AttunementProof) public attunementProofs;
    
    uint256 public agentCount;
    address public owner;
    address public grimoireRegistry;
    
    // ─── Events ───────────────────────────────────────────────────────────────
    
    event AgentRegistered(
        uint256 indexed agentId,
        address indexed agentAddress,
        string name,
        uint256 bondedETH,
        bytes32 enochianName
    );
    
    event AgentActivated(uint256 indexed agentId, address operator);
    event AgentSuspended(uint256 indexed agentId, string reason);
    event AgentTerminated(uint256 indexed agentId, uint256 bondSlashed);
    
    event TaskCompleted(
        uint256 indexed agentId,
        bytes32 taskHash,
        uint256 reputationGained
    );
    
    event TaskFailed(
        uint256 indexed agentId,
        bytes32 taskHash,
        uint256 reputationLost,
        uint256 bondSlashed
    );
    
    event AttunementVerified(
        uint256 indexed agentId,
        bytes32 capabilityHash,
        uint256 timestamp
    );
    
    event CapabilityAdded(uint256 indexed agentId, AgentCapability capability);
    event EndpointUpdated(uint256 indexed agentId, string newEndpoint);
    
    // ─── Constructor ──────────────────────────────────────────────────────────
    
    constructor(address _registry) {
        owner = msg.sender;
        grimoireRegistry = _registry;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyAgentOperator(uint256 agentId) {
        require(agents[agentId].operator == msg.sender, "Not agent operator");
        _;
    }
    
    // ─── Agent Registration ───────────────────────────────────────────────────
    
    /**
     * @notice Register a new AI agent with ERC-8004 compliance
     * @dev Agent must bond ETH as performance guarantee
     *      Bond amount determines Watcher-level access
     *
     * @param name Human-readable agent name
     * @param version Semantic version (e.g., "1.0.0")
     * @param description Agent's purpose and specialization
     * @param agentAddress The agent's signing/operating address
     * @param capabilities Array of claimed capabilities
     * @param endpointURL HTTPS URL for A2A communication
     * @param agentCardCID IPFS CID of the full ERC-8004 agent card JSON
     * @return agentId Assigned agent identifier
     */
    function registerAgent(
        string calldata name,
        string calldata version,
        string calldata description,
        address agentAddress,
        AgentCapability[] calldata capabilities,
        string calldata endpointURL,
        string calldata agentCardCID
    ) external payable returns (uint256 agentId) {
        require(msg.value >= MIN_BOND_AMOUNT, "Bond too low (min 0.1 ETH)");
        require(bytes(name).length > 0, "Name required");
        require(agentAddress != address(0), "Invalid agent address");
        require(addressToAgentId[agentAddress] == 0, "Agent already registered");
        
        agentId = ++agentCount;
        
        bytes32 enochianName = keccak256(
            abi.encodePacked("ENOCHIAN_AGENT", agentAddress, block.chainid)
        );
        
        bool isWatcher = msg.value >= WATCHER_BOND_AMOUNT;
        
        agents[agentId] = AgentCard({
            agentId: agentId,
            name: name,
            version: version,
            description: description,
            operator: msg.sender,
            agentAddress: agentAddress,
            capabilities: capabilities,
            endpointURL: endpointURL,
            agentCardCID: agentCardCID,
            bondedETH: msg.value,
            reputation: 100,      // Starting reputation
            tasksCompleted: 0,
            tasksFailed: 0,
            status: AgentStatus.Pending,
            registeredAt: block.timestamp,
            lastActiveAt: block.timestamp,
            enochianName: enochianName,
            isWatcherAgent: isWatcher
        });
        
        addressToAgentId[agentAddress] = agentId;
        
        emit AgentRegistered(agentId, agentAddress, name, msg.value, enochianName);
    }
    
    // ─── Attunement (Capability Verification) ────────────────────────────────
    
    /**
     * @notice Submit an attunement proof to verify capability claims
     * @dev Agent signs their capability hash — proves they can perform claimed skills
     * @param agentId The agent being attuned
     * @param signature Agent's cryptographic signature of capability hash
     */
    function submitAttunementProof(
        uint256 agentId,
        bytes calldata signature
    ) external onlyAgentOperator(agentId) {
        AgentCard storage agent = agents[agentId];
        
        bytes32 capabilityHash = _hashCapabilities(agent.capabilities);
        
        // Verify the signature (agent proves it can sign with its key)
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                capabilityHash
            )
        );
        
        address recovered = _recoverSigner(messageHash, signature);
        require(recovered == agent.agentAddress, "Invalid attunement signature");
        
        attunementProofs[agentId] = AttunementProof({
            agent: agent.agentAddress,
            capabilityHash: capabilityHash,
            signature: signature,
            timestamp: block.timestamp,
            verified: true
        });
        
        // Activate the agent
        agent.status = AgentStatus.Active;
        
        emit AttunementVerified(agentId, capabilityHash, block.timestamp);
        emit AgentActivated(agentId, msg.sender);
    }
    
    // ─── Reputation Management ────────────────────────────────────────────────
    
    /**
     * @notice Record a successful task completion — increases reputation
     * @dev Only callable by the owner (coordinator) or the agent operator
     */
    function recordTaskCompletion(
        uint256 agentId,
        bytes32 taskHash
    ) external onlyOwner {
        AgentCard storage agent = agents[agentId];
        require(agent.status == AgentStatus.Active, "Agent not active");
        
        agent.tasksCompleted++;
        agent.lastActiveAt = block.timestamp;
        
        uint256 reputationGain = TASK_REWARD_REP;
        if (agent.reputation + reputationGain > MAX_REPUTATION) {
            agent.reputation = MAX_REPUTATION;
        } else {
            agent.reputation += reputationGain;
        }
        
        emit TaskCompleted(agentId, taskHash, reputationGain);
    }
    
    /**
     * @notice Record a task failure — decreases reputation and slashes bond
     */
    function recordTaskFailure(
        uint256 agentId,
        bytes32 taskHash
    ) external onlyOwner {
        AgentCard storage agent = agents[agentId];
        require(agent.status == AgentStatus.Active, "Agent not active");
        
        agent.tasksFailed++;
        
        // Reputation penalty
        uint256 repPenalty = TASK_PENALTY_REP;
        agent.reputation = agent.reputation > repPenalty
            ? agent.reputation - repPenalty
            : 0;
        
        // Bond slash
        uint256 slashAmount = (agent.bondedETH * SLASH_AMOUNT_BPS) / 10000;
        agent.bondedETH -= slashAmount;
        
        // Suspend if reputation critically low
        if (agent.reputation == 0) {
            agent.status = AgentStatus.Suspended;
            emit AgentSuspended(agentId, "Critical reputation failure");
        }
        
        emit TaskFailed(agentId, taskHash, repPenalty, slashAmount);
    }
    
    // ─── Agent Management ─────────────────────────────────────────────────────
    
    /**
     * @notice Update agent's A2A endpoint URL
     */
    function updateEndpoint(
        uint256 agentId,
        string calldata newEndpoint
    ) external onlyAgentOperator(agentId) {
        agents[agentId].endpointURL = newEndpoint;
        emit EndpointUpdated(agentId, newEndpoint);
    }
    
    /**
     * @notice Add a new capability to an existing agent
     * @dev Requires re-attunement after adding capabilities
     */
    function addCapability(
        uint256 agentId,
        AgentCapability capability
    ) external onlyAgentOperator(agentId) {
        agents[agentId].capabilities.push(capability);
        // Reset to Pending until re-attuned
        agents[agentId].status = AgentStatus.Pending;
        
        emit CapabilityAdded(agentId, capability);
    }
    
    /**
     * @notice Withdraw bonded ETH (only when agent is terminated)
     */
    function withdrawBond(uint256 agentId) external onlyAgentOperator(agentId) {
        AgentCard storage agent = agents[agentId];
        require(agent.status == AgentStatus.Terminated, "Agent not terminated");
        
        uint256 bondAmount = agent.bondedETH;
        agent.bondedETH = 0;
        
        (bool sent,) = agent.operator.call{value: bondAmount}("");
        require(sent, "Bond withdrawal failed");
    }
    
    /**
     * @notice Terminate an agent (admin only)
     */
    function terminateAgent(
        uint256 agentId,
        bool slashBond
    ) external onlyOwner {
        AgentCard storage agent = agents[agentId];
        uint256 slashedAmount = 0;
        
        if (slashBond) {
            slashedAmount = agent.bondedETH;
            agent.bondedETH = 0;
            // Transfer slashed bond to treasury
            (bool sent,) = owner.call{value: slashedAmount}("");
            require(sent, "Slash transfer failed");
        }
        
        agent.status = AgentStatus.Terminated;
        emit AgentTerminated(agentId, slashedAmount);
    }
    
    // ─── View Functions ───────────────────────────────────────────────────────
    
    function getAgent(uint256 agentId) external view returns (AgentCard memory) {
        return agents[agentId];
    }
    
    function getAgentByAddress(address agentAddr) external view returns (AgentCard memory) {
        return agents[addressToAgentId[agentAddr]];
    }
    
    function hasCapability(
        uint256 agentId,
        AgentCapability capability
    ) external view returns (bool) {
        AgentCapability[] memory caps = agents[agentId].capabilities;
        for (uint256 i = 0; i < caps.length; i++) {
            if (caps[i] == capability) return true;
        }
        return false;
    }
    
    function isActiveWatcher(uint256 agentId) external view returns (bool) {
        AgentCard storage agent = agents[agentId];
        return agent.status == AgentStatus.Active && agent.isWatcherAgent;
    }
    
    // ─── Internal Functions ───────────────────────────────────────────────────
    
    function _hashCapabilities(
        AgentCapability[] storage caps
    ) internal view returns (bytes32) {
        uint256[] memory capValues = new uint256[](caps.length);
        for (uint256 i = 0; i < caps.length; i++) {
            capValues[i] = uint256(caps[i]);
        }
        return keccak256(abi.encodePacked(capValues));
    }
    
    function _recoverSigner(
        bytes32 messageHash,
        bytes calldata signature
    ) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        
        return ecrecover(messageHash, v, r, s);
    }
}
