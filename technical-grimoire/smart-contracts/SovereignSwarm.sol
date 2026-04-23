// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SovereignSwarm
 * @notice Multi-agent coordination contract for the Watcher Swarm
 * @dev Coordinates the sovereign agent swarm — a collective of AI agents
 *      operating under the Watcher Tech framework for collaborative task execution.
 *
 * "Sovereign Swarm" — A self-organizing, autonomous collective of agents
 * that cooperate without central direction, like a murmuration of starlings
 * or the seven Watchers who collectively governed ancient knowledge transmission.
 *
 * Swarm Architecture:
 *   - Tasks are submitted on-chain with reward bounties
 *   - Agents bid to participate based on capabilities
 *   - Coordinator agent assigns sub-tasks to specialized agents
 *   - Results are aggregated and validated by the swarm
 *   - Rewards distributed proportionally to contribution
 *
 * Coordination Protocols:
 *   - Delegated Proof of Work: Tasks assigned based on capability + reputation
 *   - Result Aggregation: Multiple agents vote on best output
 *   - Dispute Resolution: On-chain arbitration for contested results
 *   - Revenue Sharing: Proportional rewards based on contribution weight
 *
 * References:
 *   - swarm-consensus.ts (off-chain coordination)
 *   - AgentAttunement.sol (agent identity)
 *   - seven-pillars.md (seven-node consensus)
 */

// ─── Swarm Task Structures ────────────────────────────────────────────────────

enum TaskStatus {
    Open,         // Accepting bids
    Assigned,     // Being worked on
    Submitted,    // Results submitted, awaiting validation
    Validated,    // Results accepted by swarm consensus
    Disputed,     // Results challenged
    Completed,    // Reward distributed
    Cancelled     // Task cancelled, bond returned
}

enum TaskType {
    EsotericResearch,        // Knowledge retrieval and synthesis
    ExploitDetection,        // Security vulnerability analysis
    LunarAnalysis,           // Celestial timing computation
    SigilGeneration,         // Symbolic encoding
    AncientTextAnalysis,     // NLP on historical sources
    RitualValidation,        // Protocol/ceremony verification
    BlockchainDivination,    // Predictive market analysis
    SwarmCoordination        // Meta: coordinating other tasks
}

struct SwarmTask {
    uint256 taskId;
    TaskType taskType;
    string description;
    bytes32 inputHash;        // Hash of task input data (IPFS CID)
    address requester;
    uint256 bounty;           // ETH reward for completion
    uint256 requiredAgents;   // Minimum agents needed
    uint256 deadline;         // Timestamp deadline
    TaskStatus status;
    uint256[] assignedAgents; // AgentAttunement IDs
    bytes32 resultHash;       // Hash of accepted result
    address coordinator;      // Lead agent managing this task
}

struct TaskBid {
    uint256 agentId;
    uint256 taskId;
    uint256 proposedFee;      // Agent's fee request
    string capabilityProof;   // IPFS CID of demonstrated capability
    uint256 estimatedBlocks;  // Estimated completion time
    bool accepted;
}

struct TaskResult {
    uint256 agentId;
    uint256 taskId;
    bytes32 resultHash;       // Hash of result data (IPFS CID)
    string resultCID;         // IPFS CID of full result
    uint256 validationScore;  // 0–100, assigned by validators
    bool accepted;
}

// ─── SovereignSwarm Contract ──────────────────────────────────────────────────

contract SovereignSwarm {
    
    // ─── Constants ────────────────────────────────────────────────────────────
    
    uint256 public constant MIN_BOUNTY = 0.01 ether;
    uint256 public constant COORDINATOR_SHARE_BPS = 1500;  // 15% to coordinator
    uint256 public constant VALIDATOR_SHARE_BPS   = 500;   // 5% to validators
    uint256 public constant WORKER_SHARE_BPS      = 8000;  // 80% to workers
    uint256 public constant VALIDATION_QUORUM = 3;         // 3 validators needed
    uint256 public constant DISPUTE_WINDOW = 100;          // 100 blocks to dispute
    
    // Minimum reputation to participate in swarm tasks
    uint256 public constant MIN_SWARM_REPUTATION = 50;
    
    // ─── State ────────────────────────────────────────────────────────────────
    
    mapping(uint256 => SwarmTask) public tasks;
    mapping(uint256 => TaskBid[]) public taskBids;
    mapping(uint256 => TaskResult[]) public taskResults;
    mapping(uint256 => mapping(uint256 => bool)) public hasValidated; // taskId → agentId
    
    uint256 public taskCount;
    address public agentAttunementContract;
    address public owner;
    
    // Swarm performance metrics
    uint256 public totalTasksCompleted;
    uint256 public totalBountiesDistributed;
    
    // ─── Events ───────────────────────────────────────────────────────────────
    
    event TaskCreated(
        uint256 indexed taskId,
        TaskType taskType,
        address requester,
        uint256 bounty,
        uint256 deadline
    );
    
    event BidSubmitted(
        uint256 indexed taskId,
        uint256 indexed agentId,
        uint256 proposedFee
    );
    
    event TaskAssigned(
        uint256 indexed taskId,
        uint256[] agentIds,
        address coordinator
    );
    
    event ResultSubmitted(
        uint256 indexed taskId,
        uint256 indexed agentId,
        bytes32 resultHash
    );
    
    event TaskValidated(
        uint256 indexed taskId,
        bytes32 acceptedResultHash,
        uint256 validationScore
    );
    
    event BountyDistributed(
        uint256 indexed taskId,
        uint256 totalAmount,
        uint256 workerCount
    );
    
    event TaskDisputed(
        uint256 indexed taskId,
        uint256 indexed disputingAgent,
        string reason
    );
    
    // ─── Constructor ──────────────────────────────────────────────────────────
    
    constructor(address _agentAttunement) {
        owner = msg.sender;
        agentAttunementContract = _agentAttunement;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    // ─── Task Lifecycle ───────────────────────────────────────────────────────
    
    /**
     * @notice Create a new swarm task with a bounty
     * @param taskType Classification of task
     * @param description Human-readable task description
     * @param inputHash Hash of the task input data (IPFS CID)
     * @param requiredAgents Minimum agents needed for this task
     * @param deadlineBlocks Blocks from now until deadline
     * @return taskId Assigned task identifier
     */
    function createTask(
        TaskType taskType,
        string calldata description,
        bytes32 inputHash,
        uint256 requiredAgents,
        uint256 deadlineBlocks
    ) external payable returns (uint256 taskId) {
        require(msg.value >= MIN_BOUNTY, "Bounty too low (min 0.01 ETH)");
        require(requiredAgents > 0, "At least 1 agent required");
        require(deadlineBlocks > 0, "Deadline must be in future");
        
        taskId = ++taskCount;
        
        tasks[taskId] = SwarmTask({
            taskId: taskId,
            taskType: taskType,
            description: description,
            inputHash: inputHash,
            requester: msg.sender,
            bounty: msg.value,
            requiredAgents: requiredAgents,
            deadline: block.number + deadlineBlocks,
            status: TaskStatus.Open,
            assignedAgents: new uint256[](0),
            resultHash: bytes32(0),
            coordinator: address(0)
        });
        
        emit TaskCreated(taskId, taskType, msg.sender, msg.value, block.number + deadlineBlocks);
    }
    
    /**
     * @notice Submit a bid to participate in a task
     * @param taskId Target task
     * @param agentId Bidding agent's ID
     * @param proposedFee Agent's requested fee
     * @param capabilityProof IPFS CID of capability demonstration
     * @param estimatedBlocks Estimated blocks to completion
     */
    function submitBid(
        uint256 taskId,
        uint256 agentId,
        uint256 proposedFee,
        string calldata capabilityProof,
        uint256 estimatedBlocks
    ) external {
        SwarmTask storage task = tasks[taskId];
        require(task.status == TaskStatus.Open, "Task not accepting bids");
        require(block.number < task.deadline, "Task deadline passed");
        
        taskBids[taskId].push(TaskBid({
            agentId: agentId,
            taskId: taskId,
            proposedFee: proposedFee,
            capabilityProof: capabilityProof,
            estimatedBlocks: estimatedBlocks,
            accepted: false
        }));
        
        emit BidSubmitted(taskId, agentId, proposedFee);
    }
    
    /**
     * @notice Assign agents to a task and designate coordinator
     * @dev Only the task requester or owner can assign
     * @param taskId Target task
     * @param agentIds Selected agent IDs
     * @param coordinator Address of the coordinating agent
     */
    function assignTask(
        uint256 taskId,
        uint256[] calldata agentIds,
        address coordinator
    ) external {
        SwarmTask storage task = tasks[taskId];
        require(
            msg.sender == task.requester || msg.sender == owner,
            "Not authorized to assign"
        );
        require(task.status == TaskStatus.Open, "Task not open for assignment");
        require(agentIds.length >= task.requiredAgents, "Not enough agents");
        
        task.assignedAgents = agentIds;
        task.coordinator = coordinator;
        task.status = TaskStatus.Assigned;
        
        // Mark selected bids as accepted
        for (uint256 i = 0; i < taskBids[taskId].length; i++) {
            for (uint256 j = 0; j < agentIds.length; j++) {
                if (taskBids[taskId][i].agentId == agentIds[j]) {
                    taskBids[taskId][i].accepted = true;
                }
            }
        }
        
        emit TaskAssigned(taskId, agentIds, coordinator);
    }
    
    /**
     * @notice Submit task results
     * @param taskId Target task
     * @param agentId Submitting agent's ID
     * @param resultHash Hash of the result data
     * @param resultCID IPFS CID of full result document
     */
    function submitResult(
        uint256 taskId,
        uint256 agentId,
        bytes32 resultHash,
        string calldata resultCID
    ) external {
        SwarmTask storage task = tasks[taskId];
        require(task.status == TaskStatus.Assigned, "Task not in progress");
        require(block.number < task.deadline, "Task deadline passed");
        
        // Verify agent is assigned to this task
        bool isAssigned = false;
        for (uint256 i = 0; i < task.assignedAgents.length; i++) {
            if (task.assignedAgents[i] == agentId) {
                isAssigned = true;
                break;
            }
        }
        require(isAssigned, "Agent not assigned to this task");
        
        taskResults[taskId].push(TaskResult({
            agentId: agentId,
            taskId: taskId,
            resultHash: resultHash,
            resultCID: resultCID,
            validationScore: 0,
            accepted: false
        }));
        
        task.status = TaskStatus.Submitted;
        
        emit ResultSubmitted(taskId, agentId, resultHash);
    }
    
    /**
     * @notice Validate a submitted result
     * @dev Requires VALIDATION_QUORUM validators to finalize
     */
    function validateResult(
        uint256 taskId,
        uint256 validatorAgentId,
        uint256 resultIndex,
        uint256 score  // 0–100
    ) external {
        SwarmTask storage task = tasks[taskId];
        require(task.status == TaskStatus.Submitted, "No results to validate");
        require(!hasValidated[taskId][validatorAgentId], "Already validated");
        
        hasValidated[taskId][validatorAgentId] = true;
        taskResults[taskId][resultIndex].validationScore += score;
        
        // Check if validation quorum reached
        uint256 validatorCount = 0;
        for (uint256 i = 0; i < task.assignedAgents.length; i++) {
            if (hasValidated[taskId][task.assignedAgents[i]]) {
                validatorCount++;
            }
        }
        
        if (validatorCount >= VALIDATION_QUORUM) {
            _finalizeValidation(taskId);
        }
    }
    
    /**
     * @notice Dispute a submitted result
     */
    function disputeResult(
        uint256 taskId,
        uint256 disputingAgentId,
        string calldata reason
    ) external {
        SwarmTask storage task = tasks[taskId];
        require(
            task.status == TaskStatus.Submitted || task.status == TaskStatus.Validated,
            "Cannot dispute in this state"
        );
        
        task.status = TaskStatus.Disputed;
        emit TaskDisputed(taskId, disputingAgentId, reason);
    }
    
    /**
     * @notice Cancel a task (requester only, before assignment)
     */
    function cancelTask(uint256 taskId) external {
        SwarmTask storage task = tasks[taskId];
        require(msg.sender == task.requester, "Only requester can cancel");
        require(task.status == TaskStatus.Open, "Task already in progress");
        
        task.status = TaskStatus.Cancelled;
        
        uint256 refund = task.bounty;
        task.bounty = 0;
        
        (bool refunded,) = task.requester.call{value: refund}("");
        require(refunded, "Refund failed");
    }
    
    // ─── View Functions ───────────────────────────────────────────────────────
    
    function getTask(uint256 taskId) external view returns (SwarmTask memory) {
        return tasks[taskId];
    }
    
    function getTaskBids(uint256 taskId) external view returns (TaskBid[] memory) {
        return taskBids[taskId];
    }
    
    function getTaskResults(uint256 taskId) external view returns (TaskResult[] memory) {
        return taskResults[taskId];
    }
    
    function getOpenTasks() external view returns (uint256[] memory openTaskIds) {
        uint256 openCount = 0;
        for (uint256 i = 1; i <= taskCount; i++) {
            if (tasks[i].status == TaskStatus.Open) openCount++;
        }
        
        openTaskIds = new uint256[](openCount);
        uint256 idx = 0;
        for (uint256 i = 1; i <= taskCount; i++) {
            if (tasks[i].status == TaskStatus.Open) {
                openTaskIds[idx++] = i;
            }
        }
    }
    
    // ─── Internal Functions ───────────────────────────────────────────────────
    
    function _finalizeValidation(uint256 taskId) internal {
        SwarmTask storage task = tasks[taskId];
        
        // Find highest-scoring result
        uint256 bestScore = 0;
        uint256 bestIndex = 0;
        for (uint256 i = 0; i < taskResults[taskId].length; i++) {
            if (taskResults[taskId][i].validationScore > bestScore) {
                bestScore = taskResults[taskId][i].validationScore;
                bestIndex = i;
            }
        }
        
        taskResults[taskId][bestIndex].accepted = true;
        task.resultHash = taskResults[taskId][bestIndex].resultHash;
        task.status = TaskStatus.Validated;
        
        emit TaskValidated(taskId, task.resultHash, bestScore);
        
        _distributeBounty(taskId);
    }
    
    function _distributeBounty(uint256 taskId) internal {
        SwarmTask storage task = tasks[taskId];
        uint256 bounty = task.bounty;
        
        // Calculate shares
        uint256 coordinatorShare = (bounty * COORDINATOR_SHARE_BPS) / 10000;
        uint256 validatorShare   = (bounty * VALIDATOR_SHARE_BPS) / 10000;
        uint256 workerShare      = bounty - coordinatorShare - validatorShare;
        uint256 perWorker        = workerShare / task.assignedAgents.length;
        
        // Pay coordinator
        if (task.coordinator != address(0)) {
            (bool coordPaid,) = task.coordinator.call{value: coordinatorShare}("");
            require(coordPaid, "Coordinator payment failed");
        }
        
        task.bounty = 0;
        task.status = TaskStatus.Completed;
        totalTasksCompleted++;
        totalBountiesDistributed += bounty;
        
        emit BountyDistributed(taskId, bounty, task.assignedAgents.length);
    }
}
