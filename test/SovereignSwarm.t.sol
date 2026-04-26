// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SovereignSwarmTest
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry test suite for SovereignSwarm.sol
 *
 * Run: forge test --match-path test/SovereignSwarm.t.sol -vvvv
 */

import {Test, console} from "forge-std/Test.sol";
import {
    SovereignSwarm,
    TaskType,
    TaskStatus,
    SwarmTask
} from "../06_Contracts/SovereignSwarm.sol";

contract SovereignSwarmTest is Test {

    SovereignSwarm swarm;

    address owner     = address(this);
    address requester = address(0x111);
    address agent1    = address(0x222);
    address agent2    = address(0x333);
    address agent3    = address(0x444);

    uint256 constant MIN_BOUNTY = 0.01 ether;

    // ─── Setup ───────────────────────────────────────────────────────────────

    function setUp() public {
        swarm = new SovereignSwarm(address(0)); // No AgentAttunement for tests

        vm.deal(requester, 10 ether);
        vm.deal(agent1,    1 ether);
        vm.deal(agent2,    1 ether);
        vm.deal(agent3,    1 ether);
    }

    // ─── testCreateTask ───────────────────────────────────────────────────────

    function testCreateTask() public {
        vm.prank(requester);
        uint256 taskId = swarm.createTask{value: MIN_BOUNTY}(
            TaskType.EsotericResearch,
            "Research Enochian cipher systems",
            keccak256("task-input-data"),
            2,    // requiredAgents
            1000  // deadline in blocks
        );

        assertEq(taskId, 1);
        assertEq(swarm.taskCount(), 1);

        SwarmTask memory task = swarm.getTask(taskId);

        assertEq(task.taskId, 1);
        assertEq(uint256(task.taskType), uint256(TaskType.EsotericResearch));
        assertEq(task.description, "Research Enochian cipher systems");
        assertEq(task.inputHash, keccak256("task-input-data"));
        assertEq(task.requester, requester);
        assertEq(task.bounty, MIN_BOUNTY);
        assertEq(task.requiredAgents, 2);
        assertEq(uint256(task.status), uint256(TaskStatus.Open));
        assertEq(task.coordinator, address(0));
    }

    function testCreateTaskBountyTooLow() public {
        vm.prank(requester);
        vm.expectRevert("Bounty too low (min 0.01 ETH)");
        swarm.createTask{value: 0.001 ether}(
            TaskType.ExploitDetection,
            "Find vulnerabilities",
            keccak256("data"),
            1,
            100
        );
    }

    function testCreateTaskZeroAgentsReverts() public {
        vm.prank(requester);
        vm.expectRevert("At least 1 agent required");
        swarm.createTask{value: MIN_BOUNTY}(
            TaskType.ExploitDetection,
            "Find vulnerabilities",
            keccak256("data"),
            0,
            100
        );
    }

    // ─── testSubmitBid ────────────────────────────────────────────────────────

    function testSubmitBid() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 1, 1000);

        vm.prank(agent1);
        swarm.submitBid(taskId, 1, 0.005 ether, "bafybeiagentcap", 50);

        SovereignSwarm.TaskBid[] memory bids = swarm.getTaskBids(taskId);
        assertEq(bids.length, 1);
        assertEq(bids[0].agentId, 1);
        assertEq(bids[0].taskId, taskId);
        assertEq(bids[0].proposedFee, 0.005 ether);
    }

    function testSubmitBidAfterDeadlineReverts() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 1, 10); // 10 block deadline

        vm.roll(block.number + 11);

        vm.prank(agent1);
        vm.expectRevert("Task deadline passed");
        swarm.submitBid(taskId, 1, 0.005 ether, "bafybeiagentcap", 5);
    }

    function testSubmitBidOnAssignedTaskReverts() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 1, 1000);

        uint256[] memory agentIds = new uint256[](1);
        agentIds[0] = 1;
        vm.prank(requester);
        swarm.assignTask(taskId, agentIds, agent1);

        vm.prank(agent2);
        vm.expectRevert("Task not accepting bids");
        swarm.submitBid(taskId, 2, 0.005 ether, "bafybeicap", 50);
    }

    // ─── testAssignTask ───────────────────────────────────────────────────────

    function testAssignTask() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 2, 1000);

        uint256[] memory agentIds = new uint256[](2);
        agentIds[0] = 1;
        agentIds[1] = 2;

        vm.prank(requester);
        swarm.assignTask(taskId, agentIds, agent1);

        SwarmTask memory task = swarm.getTask(taskId);
        assertEq(uint256(task.status), uint256(TaskStatus.Assigned));
        assertEq(task.coordinator, agent1);
    }

    function testAssignTaskNotEnoughAgentsReverts() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 3, 1000);

        uint256[] memory agentIds = new uint256[](2);
        agentIds[0] = 1;
        agentIds[1] = 2;

        vm.prank(requester);
        vm.expectRevert("Not enough agents");
        swarm.assignTask(taskId, agentIds, agent1);
    }

    function testAssignTaskUnauthorizedReverts() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 1, 1000);

        uint256[] memory agentIds = new uint256[](1);
        agentIds[0] = 1;

        vm.prank(agent1); // Not the requester or owner
        vm.expectRevert("Not authorized to assign");
        swarm.assignTask(taskId, agentIds, agent1);
    }

    // ─── testSubmitResult ─────────────────────────────────────────────────────

    function testSubmitResult() public {
        uint256 taskId = _createAndAssignTask(requester, agent1, 1);

        vm.prank(agent1);
        swarm.submitResult(
            taskId,
            1,
            keccak256("result-data"),
            "bafybeiresult123"
        );

        SwarmTask memory task = swarm.getTask(taskId);
        assertEq(uint256(task.status), uint256(TaskStatus.Submitted));

        SovereignSwarm.TaskResult[] memory results = swarm.getTaskResults(taskId);
        assertEq(results.length, 1);
        assertEq(results[0].resultHash, keccak256("result-data"));
        assertEq(results[0].resultCID, "bafybeiresult123");
    }

    function testSubmitResultNonAssignedAgentReverts() public {
        uint256 taskId = _createAndAssignTask(requester, agent1, 1);

        vm.prank(agent2);
        vm.expectRevert("Agent not assigned to this task");
        swarm.submitResult(taskId, 2, keccak256("result"), "bafybeibad");
    }

    // ─── testCancelTask ───────────────────────────────────────────────────────

    function testCancelTask() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 1, 1000);

        uint256 balanceBefore = requester.balance;

        vm.prank(requester);
        swarm.cancelTask(taskId);

        uint256 balanceAfter = requester.balance;
        assertEq(balanceAfter, balanceBefore + MIN_BOUNTY);

        assertEq(uint256(swarm.getTask(taskId).status), uint256(TaskStatus.Cancelled));
    }

    function testCancelTaskNonRequesterReverts() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 1, 1000);

        vm.prank(agent1);
        vm.expectRevert("Only requester can cancel");
        swarm.cancelTask(taskId);
    }

    function testCancelAssignedTaskReverts() public {
        uint256 taskId = _createAndAssignTask(requester, agent1, 1);

        vm.prank(requester);
        vm.expectRevert("Task already in progress");
        swarm.cancelTask(taskId);
    }

    // ─── testDisputeResult ────────────────────────────────────────────────────

    function testDisputeResult() public {
        uint256 taskId = _createAndAssignTask(requester, agent1, 1);

        vm.prank(agent1);
        swarm.submitResult(taskId, 1, keccak256("result"), "bafybeiresult");

        swarm.disputeResult(taskId, 2, "Result is incorrect");

        assertEq(uint256(swarm.getTask(taskId).status), uint256(TaskStatus.Disputed));
    }

    // ─── testGetOpenTasks ─────────────────────────────────────────────────────

    function testGetOpenTasks() public {
        _createTask(requester, MIN_BOUNTY, 1, 1000);
        _createTask(requester, MIN_BOUNTY, 1, 1000);
        uint256 task3 = _createTask(requester, MIN_BOUNTY, 1, 1000);

        vm.prank(requester);
        swarm.cancelTask(task3);

        uint256[] memory openTasks = swarm.getOpenTasks();
        assertEq(openTasks.length, 2);
        assertEq(openTasks[0], 1);
        assertEq(openTasks[1], 2);
    }

    // ─── testOwnerCanAssignTask ───────────────────────────────────────────────

    function testOwnerCanAssignTask() public {
        uint256 taskId = _createTask(requester, MIN_BOUNTY, 1, 1000);

        uint256[] memory agentIds = new uint256[](1);
        agentIds[0] = 1;

        swarm.assignTask(taskId, agentIds, agent1);

        assertEq(uint256(swarm.getTask(taskId).status), uint256(TaskStatus.Assigned));
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    function _createTask(
        address req,
        uint256 bounty,
        uint256 requiredAgents,
        uint256 deadlineBlocks
    ) internal returns (uint256 taskId) {
        vm.prank(req);
        taskId = swarm.createTask{value: bounty}(
            TaskType.EsotericResearch,
            "Test task description",
            keccak256("input-data"),
            requiredAgents,
            deadlineBlocks
        );
    }

    function _createAndAssignTask(
        address req,
        address coordinator,
        uint256 numAgents
    ) internal returns (uint256 taskId) {
        taskId = _createTask(req, MIN_BOUNTY, numAgents, 1000);

        uint256[] memory agentIds = new uint256[](numAgents);
        for (uint256 i = 0; i < numAgents; i++) {
            agentIds[i] = i + 1;
        }

        vm.prank(req);
        swarm.assignTask(taskId, agentIds, coordinator);
    }

    receive() external payable {}
}
