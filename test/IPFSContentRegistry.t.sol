// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPFSContentRegistryTest
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry test suite for IPFSContentRegistry.sol
 *
 * Run: forge test --match-path test/IPFSContentRegistry.t.sol -vvvv
 */

import {Test, console} from "forge-std/Test.sol";
import {
    IPFSContentRegistry,
    ContentDomain,
    StorageLayer,
    ContentRecord
} from "../06_Contracts/IPFSContentRegistry.sol";

contract IPFSContentRegistryTest is Test {

    IPFSContentRegistry registry;

    address owner  = address(this);
    address alice  = address(0xA11CE);
    address bob    = address(0xB0B);
    address carol  = address(0xCA401);

    string constant TEST_CID  = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
    bytes32 constant TEST_HASH = keccak256("test content data");

    // ─── Setup ───────────────────────────────────────────────────────────────

    function setUp() public {
        registry = new IPFSContentRegistry();
        vm.deal(alice, 1 ether);
        vm.deal(bob,   1 ether);
        vm.deal(carol, 1 ether);
    }

    // ─── testRegisterContent ─────────────────────────────────────────────────

    function testRegisterContent() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID,
            TEST_HASH,
            ContentDomain.TechnicalGrimoire,
            StorageLayer.IPFS
        );

        assertEq(contentId, 1);
        assertEq(registry.contentCount(), 1);

        IPFSContentRegistry.ContentRecord memory record = registry.getContent(contentId);
        assertEq(record.id, contentId);
        assertEq(record.cid, TEST_CID);
        assertEq(record.contentHash, TEST_HASH);
        assertEq(record.author, alice);
        assertEq(uint256(record.domain), uint256(ContentDomain.TechnicalGrimoire));
        assertEq(uint256(record.storageLayer), uint256(StorageLayer.IPFS));
        assertEq(record.blockNumber, block.number);
        assertFalse(record.sealed);
        assertEq(record.attestationCount, 0);
    }

    function testRegisterContentEmptyCIDReverts() public {
        vm.prank(alice);
        vm.expectRevert("IPFSContentRegistry: CID required");
        registry.registerContent("", TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS);
    }

    function testRegisterContentZeroHashReverts() public {
        vm.prank(alice);
        vm.expectRevert("IPFSContentRegistry: content hash required");
        registry.registerContent(TEST_CID, bytes32(0), ContentDomain.TechnicalGrimoire, StorageLayer.IPFS);
    }

    function testRegisterDuplicateCIDReverts() public {
        vm.prank(alice);
        registry.registerContent(TEST_CID, TEST_HASH, ContentDomain.SovereignAgents, StorageLayer.IPFS);

        vm.prank(bob);
        vm.expectRevert("IPFSContentRegistry: CID already registered");
        registry.registerContent(TEST_CID, TEST_HASH, ContentDomain.SovereignAgents, StorageLayer.IPFS);
    }

    // ─── testCIDLookup ────────────────────────────────────────────────────────

    function testCIDLookup() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.MysterySchools, StorageLayer.IPFS
        );

        (bool found, uint256 id, bool sealed) = registry.verifyCID(TEST_CID);
        assertTrue(found);
        assertEq(id, contentId);
        assertFalse(sealed);
    }

    function testCIDLookupNotFound() public view {
        (bool found, uint256 id, ) = registry.verifyCID("bafybeiunknown");
        assertFalse(found);
        assertEq(id, 0);
    }

    // ─── testSealContent ─────────────────────────────────────────────────────

    function testSealContent() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        vm.prank(alice);
        registry.sealContent(contentId);

        IPFSContentRegistry.ContentRecord memory record = registry.getContent(contentId);
        assertTrue(record.sealed);
    }

    function testSealContentOnlyAuthorOrOwner() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        vm.prank(bob); // Not the author or owner
        vm.expectRevert("IPFSContentRegistry: not author or owner");
        registry.sealContent(contentId);
    }

    function testOwnerCanSealAnyContent() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        // Owner seals it (not alice)
        registry.sealContent(contentId);

        IPFSContentRegistry.ContentRecord memory record = registry.getContent(contentId);
        assertTrue(record.sealed);
    }

    function testSealTwiceReverts() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        vm.prank(alice);
        registry.sealContent(contentId);

        vm.prank(alice);
        vm.expectRevert("IPFSContentRegistry: content is sealed");
        registry.sealContent(contentId);
    }

    // ─── testAttestation ─────────────────────────────────────────────────────

    function testAttestation() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.PrimordialTraditions, StorageLayer.IPFS
        );

        vm.prank(bob);
        registry.attestContent(contentId);

        IPFSContentRegistry.ContentRecord memory record = registry.getContent(contentId);
        assertEq(record.attestationCount, 1);
    }

    function testDoubleAttestationReverts() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.PrimordialTraditions, StorageLayer.IPFS
        );

        vm.prank(bob);
        registry.attestContent(contentId);

        vm.prank(bob);
        vm.expectRevert("IPFSContentRegistry: already attested");
        registry.attestContent(contentId);
    }

    function testSelfAttestationReverts() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.PrimordialTraditions, StorageLayer.IPFS
        );

        vm.prank(alice); // Author tries to attest own content
        vm.expectRevert("IPFSContentRegistry: cannot self-attest");
        registry.attestContent(contentId);
    }

    function testAutoSealOnThresholdAttestations() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        uint256 threshold = registry.SEAL_ATTESTATION_THRESHOLD(); // 5

        // Attest from 5 different addresses
        for (uint256 i = 0; i < threshold; i++) {
            address attester = address(uint160(0x1000 + i));
            vm.prank(attester);
            registry.attestContent(contentId);
        }

        // Should be auto-sealed
        IPFSContentRegistry.ContentRecord memory record = registry.getContent(contentId);
        assertTrue(record.sealed);
    }

    // ─── testLinkArweave ─────────────────────────────────────────────────────

    function testLinkArweave() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.NephilimRephaim, StorageLayer.IPFS
        );

        string memory arweaveTx = "rMzFaJWG4K9xJuRmEK4dE8pBvPn4AhkJSiVlPGxfKjk";

        vm.prank(alice);
        registry.linkArweave(contentId, arweaveTx);

        IPFSContentRegistry.ContentRecord memory record = registry.getContent(contentId);
        assertEq(record.arweaveTxId, arweaveTx);
        assertEq(uint256(record.storageLayer), uint256(StorageLayer.Both));
    }

    function testLinkArweaveOnlyAuthor() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.NephilimRephaim, StorageLayer.IPFS
        );

        vm.prank(bob); // Not the author
        vm.expectRevert("IPFSContentRegistry: not the author");
        registry.linkArweave(contentId, "someTxId");
    }

    function testLinkArweaveSealedReverts() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        vm.prank(alice);
        registry.sealContent(contentId);

        vm.prank(alice);
        vm.expectRevert("IPFSContentRegistry: content is sealed");
        registry.linkArweave(contentId, "someTxId");
    }

    // ─── testGetAuthorContents ────────────────────────────────────────────────

    function testGetAuthorContents() public {
        string memory cid1 = "bafybeicid1aabbccdd";
        string memory cid2 = "bafybeicid2aabbccdd";

        vm.prank(alice);
        registry.registerContent(cid1, keccak256("data1"), ContentDomain.MysterySchools, StorageLayer.IPFS);

        vm.prank(alice);
        registry.registerContent(cid2, keccak256("data2"), ContentDomain.SovereignAgents, StorageLayer.IPFS);

        vm.prank(bob);
        registry.registerContent("bafybeibobcid", keccak256("bobdata"), ContentDomain.ThirteenBloodlines, StorageLayer.IPFS);

        uint256[] memory aliceContents = registry.getAuthorContents(alice);
        assertEq(aliceContents.length, 2);

        uint256[] memory bobContents = registry.getAuthorContents(bob);
        assertEq(bobContents.length, 1);
    }

    // ─── testGetDomainContents ────────────────────────────────────────────────

    function testGetDomainContents() public {
        vm.prank(alice);
        registry.registerContent("bafybeicid1", keccak256("d1"), ContentDomain.TechnicalGrimoire, StorageLayer.IPFS);

        vm.prank(alice);
        registry.registerContent("bafybeicid2", keccak256("d2"), ContentDomain.TechnicalGrimoire, StorageLayer.IPFS);

        vm.prank(bob);
        registry.registerContent("bafybeicid3", keccak256("d3"), ContentDomain.SovereignAgents, StorageLayer.IPFS);

        uint256[] memory techContents = registry.getDomainContents(ContentDomain.TechnicalGrimoire);
        assertEq(techContents.length, 2);

        uint256[] memory agentContents = registry.getDomainContents(ContentDomain.SovereignAgents);
        assertEq(agentContents.length, 1);
    }

    // ─── testLinkGrimoireEntry ────────────────────────────────────────────────

    function testLinkGrimoireEntry() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        vm.prank(alice);
        registry.linkGrimoireEntry(contentId, 42);

        IPFSContentRegistry.ContentRecord memory record = registry.getContent(contentId);
        assertEq(record.grimoireEntryId, 42);
    }

    function testLinkGrimoireEntryOnlyAuthor() public {
        vm.prank(alice);
        uint256 contentId = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        vm.prank(bob);
        vm.expectRevert("IPFSContentRegistry: not the author");
        registry.linkGrimoireEntry(contentId, 1);
    }

    // ─── testGetStats ─────────────────────────────────────────────────────────

    function testGetStats() public {
        (uint256 total, uint256 sealed, uint256 withProofs) = registry.getStats();
        assertEq(total, 0);
        assertEq(sealed, 0);
        assertEq(withProofs, 0);

        vm.prank(alice);
        uint256 id = registry.registerContent(
            TEST_CID, TEST_HASH, ContentDomain.TechnicalGrimoire, StorageLayer.IPFS
        );

        vm.prank(alice);
        registry.sealContent(id);

        (uint256 total2, uint256 sealed2, ) = registry.getStats();
        assertEq(total2, 1);
        assertEq(sealed2, 1);
    }

    // ─── testContentNotFoundReverts ───────────────────────────────────────────

    function testSealNonExistentReverts() public {
        vm.expectRevert("IPFSContentRegistry: content not found");
        registry.sealContent(999);
    }

    function testAttestNonExistentReverts() public {
        vm.expectRevert("IPFSContentRegistry: content not found");
        registry.attestContent(999);
    }
}
