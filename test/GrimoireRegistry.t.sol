// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GrimoireRegistryTest
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry test suite for GrimoireRegistry.sol
 *
 * Run: forge test --match-path test/GrimoireRegistry.t.sol -vvvv
 */

import {Test, console} from "forge-std/Test.sol";
import {
    GrimoireRegistry,
    EsotericDomain,
    AccessLevel,
    KnowledgeEntry
} from "../06_Contracts/GrimoireRegistry.sol";

contract GrimoireRegistryTest is Test {

    GrimoireRegistry registry;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address carol = address(0xCA401);

    // ─── Setup ───────────────────────────────────────────────────────────────

    function setUp() public {
        registry = new GrimoireRegistry();

        // Give test accounts some ETH (not strictly needed, but good practice)
        vm.deal(alice, 1 ether);
        vm.deal(bob,   1 ether);
        vm.deal(carol, 1 ether);
    }

    // ─── testInitiatorIsOwnerAndMaster ────────────────────────────────────────

    function testDeployerIsOwnerAndMaster() public view {
        assertEq(registry.owner(), owner);
        (, , , , bool isMaster, ) = _getContributor(owner);
        assertTrue(isMaster);
    }

    // ─── testInitiate ─────────────────────────────────────────────────────────

    function testInitiate() public {
        vm.prank(alice);
        registry.initiate("ancient secret phrase");

        (address addr, uint256 rep, , , , ) = _getContributor(alice);
        assertEq(addr, alice);
        assertEq(rep, 10); // Starting reputation
    }

    function testInitiateTwiceReverts() public {
        vm.prank(alice);
        registry.initiate("first phrase");

        vm.prank(alice);
        vm.expectRevert("Already initiated");
        registry.initiate("second phrase");
    }

    // ─── testSubmitEntry ──────────────────────────────────────────────────────

    function testSubmitEntry() public {
        // Alice must be initiated first
        vm.prank(alice);
        registry.initiate("alice secret");

        vm.prank(alice);
        uint256 entryId = registry.submitEntry(
            "Hermetic Axioms",
            "bafybeiabc123",
            EsotericDomain.MysterySchools,
            AccessLevel.Public
        );

        assertEq(entryId, 1);
        assertEq(registry.entryCount(), 1);

        GrimoireRegistry.KnowledgeEntry memory entry = registry.getEntry(entryId);

        assertEq(entry.id, 1);
        assertEq(entry.title, "Hermetic Axioms");
        assertEq(entry.contributor, alice);
        assertFalse(entry.verified);
    }

    function testSubmitEntryWithoutInitiationReverts() public {
        vm.prank(alice);
        vm.expectRevert("Must be initiated");
        registry.submitEntry(
            "Secret Knowledge",
            "bafybeioxyz456",
            EsotericDomain.TechnicalGrimoire,
            AccessLevel.Public
        );
    }

    function testSubmitEntryEmptyTitleReverts() public {
        vm.prank(alice);
        registry.initiate("alice secret");

        vm.prank(alice);
        vm.expectRevert("Title required");
        registry.submitEntry(
            "",
            "bafybeiabc123",
            EsotericDomain.PrimordialTraditions,
            AccessLevel.Public
        );
    }

    // ─── testVerifyEntry ──────────────────────────────────────────────────────

    function testVerifyEntryRequiresReputation() public {
        // Alice submits
        vm.prank(alice);
        registry.initiate("alice secret");

        vm.prank(alice);
        registry.submitEntry(
            "Some Title",
            "bafybeiabc123",
            EsotericDomain.MysterySchools,
            AccessLevel.Public
        );

        // Bob tries to verify (insufficient reputation — only 10 starting rep)
        vm.prank(bob);
        registry.initiate("bob secret");

        vm.prank(bob);
        vm.expectRevert("Insufficient reputation");
        registry.verifyEntry(1);
    }

    function testVerifyEntryReachesQuorum() public {
        // Alice submits
        vm.prank(alice);
        registry.initiate("alice secret");

        vm.prank(alice);
        registry.submitEntry(
            "Sacred Geometry",
            "bafybeigeo123",
            EsotericDomain.NephilimRephaim,
            AccessLevel.Public
        );

        // Three adept-level reviewers (use owner address which starts as master)
        address rev1 = address(0x111);
        address rev2 = address(0x222);
        address rev3 = address(0x333);

        _makeAdept(rev1);
        _makeAdept(rev2);
        _makeAdept(rev3);

        vm.prank(rev1);
        registry.verifyEntry(1);

        // Not yet verified after 1 review
        assertFalse(registry.getEntry(1).verified);

        vm.prank(rev2);
        registry.verifyEntry(1);

        // Not yet verified after 2 reviews
        assertFalse(registry.getEntry(1).verified);

        vm.prank(rev3);
        registry.verifyEntry(1);

        // Verified after 3 reviews (VERIFICATION_QUORUM)
        assertTrue(registry.getEntry(1).verified);
    }

    // ─── testVoteOnEntry ──────────────────────────────────────────────────────

    function testUpvoteIncreasesReputation() public {
        // Alice submits
        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry(
            "Kabbalistic Tree",
            "bafybei111",
            EsotericDomain.MysterySchools,
            AccessLevel.Public
        );

        // Bob is initiated and upvotes
        vm.prank(bob);
        registry.initiate("bob secret");

        (, uint256 repBefore, , , , ) = _getContributor(alice);

        vm.prank(bob);
        registry.voteOnEntry(1, true);

        (, uint256 repAfter, , , , ) = _getContributor(alice);
        assertEq(repAfter, repBefore + 1);
    }

    function testDownvoteDecreasesReputation() public {
        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry(
            "Questionable Entry",
            "bafybei222",
            EsotericDomain.ThirteenBloodlines,
            AccessLevel.Public
        );

        vm.prank(bob);
        registry.initiate("bob secret");

        (, uint256 repBefore, , , , ) = _getContributor(alice);

        vm.prank(bob);
        registry.voteOnEntry(1, false);

        (, uint256 repAfter, , , , ) = _getContributor(alice);
        assertEq(repAfter, repBefore - 1);
    }

    function testVoteTwiceReverts() public {
        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry("Title", "cid", EsotericDomain.SovereignAgents, AccessLevel.Public);

        vm.prank(bob);
        registry.initiate("bob secret");

        vm.prank(bob);
        registry.voteOnEntry(1, true);

        vm.prank(bob);
        vm.expectRevert("Already voted");
        registry.voteOnEntry(1, true);
    }

    function testCannotVoteOnOwnEntry() public {
        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry("My Entry", "mycid", EsotericDomain.SovereignAgents, AccessLevel.Public);

        vm.prank(alice);
        vm.expectRevert("Cannot vote on own entry");
        registry.voteOnEntry(1, true);
    }

    // ─── testCrossReferences ─────────────────────────────────────────────────

    function testAddCrossReference() public {
        vm.prank(alice);
        registry.initiate("alice secret");

        vm.prank(alice);
        registry.submitEntry("Entry A", "cidA", EsotericDomain.TechnicalGrimoire, AccessLevel.Public);

        vm.prank(alice);
        registry.submitEntry("Entry B", "cidB", EsotericDomain.SovereignAgents, AccessLevel.Public);

        vm.prank(alice);
        registry.addCrossReference(1, 2);

        uint256[] memory refs = registry.getCrossReferences(1);
        assertEq(refs.length, 1);
        assertEq(refs[0], 2);
    }

    function testCrossReferenceOnlyByContributor() public {
        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry("Alice Entry", "cidA", EsotericDomain.MysterySchools, AccessLevel.Public);

        vm.prank(bob);
        registry.initiate("bob secret");
        vm.prank(bob);
        registry.submitEntry("Bob Entry", "cidB", EsotericDomain.MysterySchools, AccessLevel.Public);

        // Bob tries to add cross-reference to Alice's entry
        vm.prank(bob);
        vm.expectRevert("Only contributor can cross-reference");
        registry.addCrossReference(1, 2);
    }

    // ─── testPromoteMaster ────────────────────────────────────────────────────

    function testPromoteMaster() public {
        // Carol gets enough reputation to be promoted
        vm.prank(carol);
        registry.initiate("carol secret");

        _boostReputation(carol, 500); // Give master-level reputation

        // Owner (who is a master) promotes Carol
        registry.promoteMaster(carol);

        (, , , , bool isMaster, ) = _getContributor(carol);
        assertTrue(isMaster);
    }

    function testNonMasterCannotPromote() public {
        vm.prank(alice);
        registry.initiate("alice secret");

        vm.prank(carol);
        registry.initiate("carol secret");

        _boostReputation(carol, 500);

        vm.prank(alice);
        vm.expectRevert("Only masters can promote");
        registry.promoteMaster(carol);
    }

    // ─── testGetDomainEntries ─────────────────────────────────────────────────

    function testGetDomainEntries() public {
        vm.prank(alice);
        registry.initiate("alice secret");

        vm.startPrank(alice);
        registry.submitEntry("Entry 1", "cid1", EsotericDomain.TechnicalGrimoire, AccessLevel.Public);
        registry.submitEntry("Entry 2", "cid2", EsotericDomain.TechnicalGrimoire, AccessLevel.Public);
        registry.submitEntry("Entry 3", "cid3", EsotericDomain.SovereignAgents, AccessLevel.Public);
        vm.stopPrank();

        uint256[] memory techEntries = registry.getDomainEntries(EsotericDomain.TechnicalGrimoire);
        uint256[] memory agentEntries = registry.getDomainEntries(EsotericDomain.SovereignAgents);

        assertEq(techEntries.length, 2);
        assertEq(agentEntries.length, 1);
    }

    // ─── testHasAccess ────────────────────────────────────────────────────────

    function testHasAccessPublic() public {
        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry("Public Entry", "cid", EsotericDomain.MysterySchools, AccessLevel.Public);

        // Anyone has access to Public entries
        assertTrue(registry.hasAccess(bob, 1, false));
    }

    function testHasAccessInitiatedNeedsToken() public {
        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry(
            "Initiated Entry", "cid", EsotericDomain.MysterySchools, AccessLevel.Initiated
        );

        assertFalse(registry.hasAccess(bob, 1, false)); // No token
        assertTrue(registry.hasAccess(bob, 1, true));   // Has token
    }

    function testHasAccessAdeptNeedsReputation() public {
        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry(
            "Adept Entry", "cid", EsotericDomain.TechnicalGrimoire, AccessLevel.Adept
        );

        // Bob has 10 reputation — too low
        vm.prank(bob);
        registry.initiate("bob secret");
        assertFalse(registry.hasAccess(bob, 1, false));

        // Give bob enough reputation
        _boostReputation(bob, 100);
        assertTrue(registry.hasAccess(bob, 1, false));
    }

    // ─── testGetStats ─────────────────────────────────────────────────────────

    function testGetStats() public {
        (uint256 total, uint256 verified, , uint256 masters) = registry.getStats();
        assertEq(total, 0);
        assertEq(verified, 0);
        assertEq(masters, 1); // deployer

        vm.prank(alice);
        registry.initiate("alice secret");
        vm.prank(alice);
        registry.submitEntry("Entry", "cid", EsotericDomain.SovereignAgents, AccessLevel.Public);

        (uint256 total2, , , ) = registry.getStats();
        assertEq(total2, 1);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /// @dev Unpack the Contributor struct mapping (workaround for Solidity tuple returns)
    function _getContributor(address addr) internal view returns (
        address contAddr,
        uint256 reputation,
        uint256 entriesSubmitted,
        uint256 entriesVerified,
        bool    isMaster,
        bytes32 initiationHash
    ) {
        return registry.contributors(addr);
    }

    /// @dev Directly manipulate contributor reputation via vm.store (cheat)
    function _boostReputation(address addr, uint256 amount) internal {
        // Use Foundry's vm.store to directly set the reputation slot.
        // GrimoireRegistry.contributors mapping is at slot 0 of the contract.
        // Mapping slot for key 'addr': keccak256(abi.encode(addr, 0))
        // Contributor struct layout:
        //   slot 0: addr (address, 20 bytes)
        //   slot 1: reputation (uint256)
        //   slot 2: entriesSubmitted (uint256)
        //   slot 3: entriesVerified (uint256)
        //   slot 4: isMaster (bool)
        //   slot 5: initiationHash (bytes32)
        bytes32 baseSlot = keccak256(abi.encode(addr, uint256(0)));
        bytes32 repSlot  = bytes32(uint256(baseSlot) + 1);
        vm.store(address(registry), repSlot, bytes32(amount));
    }

    /// @dev Create a fresh address with adept-level reputation (>= 100)
    function _makeAdept(address addr) internal {
        vm.prank(addr);
        registry.initiate("adept phrase");

        _boostReputation(addr, 100);
    }
}
