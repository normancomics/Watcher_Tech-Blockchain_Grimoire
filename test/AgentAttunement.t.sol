// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AgentAttunementTest
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry test suite for AgentAttunement.sol
 *
 * Run: forge test --match-path test/AgentAttunement.t.sol -vvvv
 */

import {Test, console} from "forge-std/Test.sol";
import {
    AgentAttunement,
    AgentCapability,
    AgentStatus,
    AgentCard
} from "../06_Contracts/AgentAttunement.sol";

contract AgentAttunementTest is Test {

    AgentAttunement attunement;

    address owner    = address(this);
    address operator = address(0x0A);
    address agentAddr = address(0x0B);
    address operator2 = address(0x0C);
    address agentAddr2 = address(0x0D);

    uint256 constant MIN_BOND     = 0.1 ether;
    uint256 constant WATCHER_BOND = 1 ether;

    // ─── Setup ───────────────────────────────────────────────────────────────

    function setUp() public {
        attunement = new AgentAttunement(address(0)); // No registry for tests

        vm.deal(operator,  10 ether);
        vm.deal(operator2, 10 ether);
    }

    // ─── testRegisterAgent ────────────────────────────────────────────────────

    function testRegisterAgent() public {
        AgentCapability[] memory caps = _defaultCaps();

        vm.prank(operator);
        uint256 agentId = attunement.registerAgent{value: MIN_BOND}(
            "TestAgent",
            "1.0.0",
            "A test agent",
            agentAddr,
            caps,
            "https://agent.example.com",
            "bafybeiabc123"
        );

        assertEq(agentId, 1);
        assertEq(attunement.agentCount(), 1);

        AgentCard memory agent = attunement.getAgent(agentId);

        assertEq(agent.agentId, 1);
        assertEq(agent.name, "TestAgent");
        assertEq(agent.operator, operator);
        assertEq(agent.agentAddress, agentAddr);
        assertEq(agent.bondedETH, MIN_BOND);
        assertEq(agent.reputation, 100);
        assertEq(uint256(agent.status), uint256(AgentStatus.Pending));
        assertFalse(agent.isWatcherAgent); // Bond < WATCHER_BOND_AMOUNT
    }

    function testRegisterAgentWatcherTier() public {
        AgentCapability[] memory caps = _defaultCaps();

        vm.prank(operator);
        uint256 agentId = attunement.registerAgent{value: WATCHER_BOND}(
            "WatcherAgent",
            "1.0.0",
            "A watcher agent",
            agentAddr,
            caps,
            "https://watcher.example.com",
            "bafybeiwatcher"
        );

        AgentCard memory agent = attunement.getAgent(agentId);
        assertTrue(agent.isWatcherAgent);
    }

    function testRegisterAgentBondTooLow() public {
        AgentCapability[] memory caps = _defaultCaps();

        vm.prank(operator);
        vm.expectRevert("Bond too low (min 0.1 ETH)");
        attunement.registerAgent{value: 0.05 ether}(
            "LowBondAgent",
            "1.0.0",
            "Low bond agent",
            agentAddr,
            caps,
            "https://agent.example.com",
            "bafybeilowbond"
        );
    }

    function testRegisterAgentDuplicateAddressReverts() public {
        AgentCapability[] memory caps = _defaultCaps();

        vm.prank(operator);
        attunement.registerAgent{value: MIN_BOND}(
            "AgentFirst",
            "1.0.0",
            "First agent",
            agentAddr,
            caps,
            "https://agent.example.com",
            "bafybeifirst"
        );

        vm.prank(operator2);
        vm.expectRevert("Agent already registered");
        attunement.registerAgent{value: MIN_BOND}(
            "AgentDuplicate",
            "1.0.0",
            "Duplicate agent",
            agentAddr,  // Same agent address!
            caps,
            "https://agent2.example.com",
            "bafybeisecond"
        );
    }

    function testRegisterAgentZeroAddressReverts() public {
        AgentCapability[] memory caps = _defaultCaps();

        vm.prank(operator);
        vm.expectRevert("Invalid agent address");
        attunement.registerAgent{value: MIN_BOND}(
            "ZeroAgent",
            "1.0.0",
            "Zero address agent",
            address(0),
            caps,
            "https://agent.example.com",
            "bafybeizero"
        );
    }

    // ─── testUpdateEndpoint ───────────────────────────────────────────────────

    function testUpdateEndpoint() public {
        uint256 agentId = _registerAgent(operator, agentAddr, MIN_BOND);

        vm.prank(operator);
        attunement.updateEndpoint(agentId, "https://new-endpoint.example.com");

        AgentCard memory agent = attunement.getAgent(agentId);
        assertEq(agent.endpointURL, "https://new-endpoint.example.com");
    }

    function testUpdateEndpointNonOperatorReverts() public {
        uint256 agentId = _registerAgent(operator, agentAddr, MIN_BOND);

        vm.prank(operator2); // Not the operator
        vm.expectRevert("Not agent operator");
        attunement.updateEndpoint(agentId, "https://attacker.example.com");
    }

    // ─── testAddCapability ────────────────────────────────────────────────────

    function testAddCapability() public {
        uint256 agentId = _registerAgent(operator, agentAddr, MIN_BOND);

        vm.prank(operator);
        attunement.addCapability(agentId, AgentCapability.LUNAR_CALC);

        // Status should revert to Pending after adding capability
        AgentCard memory agent = attunement.getAgent(agentId);
        assertEq(uint256(agent.status), uint256(AgentStatus.Pending));

        // hasCapability should return true
        assertTrue(attunement.hasCapability(agentId, AgentCapability.EXPLOIT_DETECT));
        assertTrue(attunement.hasCapability(agentId, AgentCapability.LUNAR_CALC));
    }

    // ─── testRecordTaskCompletion ─────────────────────────────────────────────

    function testRecordTaskCompletionIncreasesReputation() public {
        uint256 agentId = _registerAgentAndActivate(operator, agentAddr, MIN_BOND);

        uint256 repBefore = attunement.getAgent(agentId).reputation;

        attunement.recordTaskCompletion(agentId, keccak256("task1"));

        uint256 repAfter = attunement.getAgent(agentId).reputation;
        assertEq(repAfter, repBefore + attunement.TASK_REWARD_REP());
    }

    function testRecordTaskCompletionCapsAtMax() public {
        uint256 agentId = _registerAgentAndActivate(operator, agentAddr, MIN_BOND);

        // Set reputation to just below max using vm.store
        _setReputation(agentId, attunement.MAX_REPUTATION() - 1);

        attunement.recordTaskCompletion(agentId, keccak256("task1"));

        assertEq(attunement.getAgent(agentId).reputation, attunement.MAX_REPUTATION());
    }

    // ─── testRecordTaskFailure ────────────────────────────────────────────────

    function testRecordTaskFailureReducesReputation() public {
        uint256 agentId = _registerAgentAndActivate(operator, agentAddr, MIN_BOND);

        uint256 repBefore = attunement.getAgent(agentId).reputation;

        attunement.recordTaskFailure(agentId, keccak256("task_fail"));

        AgentCard memory agent = attunement.getAgent(agentId);
        assertEq(agent.reputation, repBefore - attunement.TASK_PENALTY_REP());
        assertEq(agent.tasksFailed, 1);
    }

    function testRecordTaskFailureSlashesBond() public {
        uint256 agentId = _registerAgentAndActivate(operator, agentAddr, MIN_BOND);

        uint256 bondBefore = attunement.getAgent(agentId).bondedETH;

        attunement.recordTaskFailure(agentId, keccak256("task_fail"));

        uint256 bondAfter = attunement.getAgent(agentId).bondedETH;

        uint256 expectedSlash = (bondBefore * attunement.SLASH_AMOUNT_BPS()) / 10000;
        assertEq(bondAfter, bondBefore - expectedSlash);
    }

    function testRecordTaskFailureSuspendsAtZeroRep() public {
        uint256 agentId = _registerAgentAndActivate(operator, agentAddr, MIN_BOND);

        // Set reputation to the minimum that will hit zero after one failure
        _setReputation(agentId, attunement.TASK_PENALTY_REP());

        attunement.recordTaskFailure(agentId, keccak256("fatal_task"));

        AgentCard memory agent = attunement.getAgent(agentId);
        assertEq(uint256(agent.status), uint256(AgentStatus.Suspended));
    }

    // ─── testTerminateAgent ───────────────────────────────────────────────────

    function testTerminateAgent() public {
        uint256 agentId = _registerAgentAndActivate(operator, agentAddr, MIN_BOND);

        attunement.terminateAgent(agentId, false);

        assertEq(uint256(attunement.getAgent(agentId).status), uint256(AgentStatus.Terminated));
    }

    function testTerminateAgentWithSlash() public {
        uint256 agentId = _registerAgentAndActivate(operator, agentAddr, MIN_BOND);

        uint256 ownerBefore = owner.balance;

        attunement.terminateAgent(agentId, true);

        uint256 ownerAfter = owner.balance;
        assertGt(ownerAfter, ownerBefore);
    }

    function testTerminateAgentOnlyOwner() public {
        uint256 agentId = _registerAgentAndActivate(operator, agentAddr, MIN_BOND);

        vm.prank(operator);
        vm.expectRevert("Not owner");
        attunement.terminateAgent(agentId, false);
    }

    // ─── testGetAgentByAddress ────────────────────────────────────────────────

    function testGetAgentByAddress() public {
        uint256 agentId = _registerAgent(operator, agentAddr, MIN_BOND);

        assertEq(attunement.addressToAgentId(agentAddr), agentId);
    }

    // ─── testIsActiveWatcher ──────────────────────────────────────────────────

    function testIsActiveWatcherFalseWhenPending() public {
        _registerAgent(operator, agentAddr, WATCHER_BOND);
        assertFalse(attunement.isActiveWatcher(1)); // Status is Pending
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    function _defaultCaps() internal pure returns (AgentCapability[] memory) {
        AgentCapability[] memory caps = new AgentCapability[](2);
        caps[0] = AgentCapability.EXPLOIT_DETECT;
        caps[1] = AgentCapability.SWARM_COORD;
        return caps;
    }

    function _registerAgent(
        address op,
        address agAddr,
        uint256 bond
    ) internal returns (uint256 agentId) {
        AgentCapability[] memory caps = _defaultCaps();

        vm.prank(op);
        agentId = attunement.registerAgent{value: bond}(
            "TestAgent",
            "1.0.0",
            "A test agent",
            agAddr,
            caps,
            "https://agent.example.com",
            "bafybeiabc123"
        );
    }

    function _registerAgentAndActivate(
        address op,
        address agAddr,
        uint256 bond
    ) internal returns (uint256 agentId) {
        agentId = _registerAgent(op, agAddr, bond);

        // Directly set status to Active using vm.store (bypassing signature verification)
        // AgentAttunement.agents mapping is at slot 0.
        // AgentCard struct slot layout (each string/array occupies one slot for the length):
        //   0: agentId (uint256)
        //   1: name (string — 1 slot for length in storage)
        //   2: version (string)
        //   3: description (string)
        //   4: operator (address — packed with next bool if it fits, but address is 20 bytes)
        //   5: agentAddress (address)
        //   6: capabilities (uint256[] — 1 slot for length)
        //   7: endpointURL (string)
        //   8: agentCardCID (string)
        //   9: bondedETH (uint256)
        //  10: reputation (uint256)
        //  11: tasksCompleted (uint256)
        //  12: tasksFailed (uint256)
        //  13: status (AgentStatus enum — uint8, packed)
        //  14: registeredAt (uint256)
        //  15: lastActiveAt (uint256)
        //  16: enochianName (bytes32)
        //  17: isWatcherAgent (bool, packed with status in same slot as 13)
        bytes32 baseSlot = keccak256(abi.encode(agentId, uint256(0)));
        bytes32 statusSlot = bytes32(uint256(baseSlot) + 13);
        vm.store(address(attunement), statusSlot, bytes32(uint256(AgentStatus.Active)));
    }

    function _setReputation(uint256 agentId, uint256 rep) internal {
        bytes32 baseSlot = keccak256(abi.encode(agentId, uint256(0)));
        bytes32 repSlot  = bytes32(uint256(baseSlot) + 10);
        vm.store(address(attunement), repSlot, bytes32(rep));
    }

    receive() external payable {}
}
