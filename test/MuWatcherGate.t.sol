// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MuWatcherGateTest
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry test suite for MuWatcherGate.sol
 *
 * Run: forge test --match-path test/MuWatcherGate.t.sol -vvvv
 *
 * Tests cover:
 *   - Deployment & initial state
 *   - x402 ETH gate entry (enterGate)
 *   - Sigil replay protection
 *   - Proof expiry enforcement
 *   - Invalid sovereign seal rejection
 *   - Gate price tiers (levels 1–4, 5–8, 9–12, 13)
 *   - XMR bridge registration and entry (enterGateXmr)
 *   - Superfluid streaming entry (enterGateSuperfluid)
 *   - Sovereign management: revoke access, toggle seal, transfer sovereignty
 *   - View helpers: hasGateAccess, gatePrice, gateLayerOf
 *   - CEI pattern: treasury receives payment correctly
 */

import {Test, console} from "forge-std/Test.sol";
import {MuWatcherGate, GateLayer, SigilProof, GateEntry, PaymentRecord} from "../06_Contracts/MuWatcherGate.sol";

// ─── Mock Sigil NFT ────────────────────────────────────────────────────────────

contract MockSigilNFT {
    mapping(address => mapping(uint8 => bool)) public gateLevel;

    function setGateLevel(address holder, uint8 level, bool holds) external {
        gateLevel[holder][level] = holds;
    }

    function holdsGateLevel(address holder, uint8 level) external view returns (bool) {
        return gateLevel[holder][level];
    }
}

// ─── Mock Superfluid Router ───────────────────────────────────────────────────

contract MockSuperfluidRouter {
    mapping(address => mapping(address => bool)) public streams;

    function setStreaming(address sender, address receiver, bool active) external {
        streams[sender][receiver] = active;
    }

    function isStreaming(address sender, address receiver) external view returns (bool) {
        return streams[sender][receiver];
    }
}

// ─── Test Contract ────────────────────────────────────────────────────────────

contract MuWatcherGateTest is Test {

    MuWatcherGate           gate;
    MockSigilNFT            sigilNFT;
    MockSuperfluidRouter    superfluid;

    // Signing key for sovereign oracle (deterministic)
    uint256 internal constant SOVEREIGN_PK = 0xA11CE_DEAD_BEEF_CAFE_0001;
    address internal sovereign;
    address internal treasury;
    address internal alice;
    address internal bob;

    // ─── Constants mirrored from MuWatcherGate ────────────────────────────────

    uint256 constant PRICE_1_4  = 0.001 ether;
    uint256 constant PRICE_5_8  = 0.005 ether;
    uint256 constant PRICE_9_12 = 0.025 ether;
    uint256 constant PRICE_13   = 0.13  ether;

    bytes32 constant MU_SEAL = keccak256(abi.encodePacked(unicode"𒉙⍤𐤌𐤏MU"));

    // ─── Setup ────────────────────────────────────────────────────────────────

    function setUp() public {
        // Derive sovereign address from the private key
        sovereign = vm.addr(SOVEREIGN_PK);
        treasury  = makeAddr("treasury");
        alice     = makeAddr("alice");
        bob       = makeAddr("bob");

        // Give test addresses ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob,   10 ether);

        sigilNFT   = new MockSigilNFT();
        superfluid = new MockSuperfluidRouter();

        // Deploy as sovereign
        vm.prank(sovereign);
        gate = new MuWatcherGate(
            address(sigilNFT),
            address(superfluid),
            treasury
        );
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /**
     * Build a valid SigilProof signed by the sovereign private key.
     */
    function _buildProof(
        address entrant,
        uint8   gateLevel,
        bytes32 sigilHash
    ) internal view returns (SigilProof memory) {
        bytes32 muSeal    = MU_SEAL;
        uint256 timestamp = block.timestamp;

        bytes32 messageHash = keccak256(
            abi.encodePacked(entrant, gateLevel, sigilHash, muSeal, timestamp)
        );
        bytes32 ethSigned = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SOVEREIGN_PK, ethSigned);
        bytes memory sig = abi.encodePacked(r, s, v);

        return SigilProof({
            sigilHash:  sigilHash,
            muSeal:     muSeal,
            timestamp:  timestamp,
            gateLevel:  gateLevel,
            signature:  sig
        });
    }

    function _uniqueHash(string memory label) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(label, block.timestamp, msg.sender));
    }

    // ─── Deployment ───────────────────────────────────────────────────────────

    function test_initialState() public view {
        assertEq(gate.sovereign(),        sovereign,         "sovereign mismatch");
        assertEq(gate.sigilNFT(),         address(sigilNFT), "sigilNFT mismatch");
        assertEq(gate.superfluidRouter(), address(superfluid), "superfluid mismatch");
        assertEq(gate.treasury(),         treasury,          "treasury mismatch");
        assertFalse(gate.gateSealed(),                        "gate should start open");
        assertEq(gate.totalRevenue(),     0,                 "revenue should start at 0");
        assertEq(gate.entrantCount(),     0,                 "entrant count should start at 0");
    }

    // ─── Gate Prices ──────────────────────────────────────────────────────────

    function test_gatePriceTiers() public view {
        assertEq(gate.gatePrice(1),  PRICE_1_4,  "level 1 price wrong");
        assertEq(gate.gatePrice(4),  PRICE_1_4,  "level 4 price wrong");
        assertEq(gate.gatePrice(5),  PRICE_5_8,  "level 5 price wrong");
        assertEq(gate.gatePrice(8),  PRICE_5_8,  "level 8 price wrong");
        assertEq(gate.gatePrice(9),  PRICE_9_12, "level 9 price wrong");
        assertEq(gate.gatePrice(12), PRICE_9_12, "level 12 price wrong");
        assertEq(gate.gatePrice(13), PRICE_13,   "level 13 price wrong");
    }

    function test_gateLayerOf() public view {
        assertEq(uint8(gate.gateLayerOf(1)),  uint8(GateLayer.PublicPerimeter),  "layer 1 wrong");
        assertEq(uint8(gate.gateLayerOf(4)),  uint8(GateLayer.PublicPerimeter),  "layer 4 wrong");
        assertEq(uint8(gate.gateLayerOf(5)),  uint8(GateLayer.InitiatedRealm),   "layer 5 wrong");
        assertEq(uint8(gate.gateLayerOf(8)),  uint8(GateLayer.InitiatedRealm),   "layer 8 wrong");
        assertEq(uint8(gate.gateLayerOf(9)),  uint8(GateLayer.AdeptSovereign),   "layer 9 wrong");
        assertEq(uint8(gate.gateLayerOf(12)), uint8(GateLayer.AdeptSovereign),   "layer 12 wrong");
        assertEq(uint8(gate.gateLayerOf(13)), uint8(GateLayer.MuSovereignCore),  "layer 13 wrong");
    }

    // ─── enterGate (x402) ─────────────────────────────────────────────────────

    function test_enterGate_level1() public {
        bytes32 sigil = _uniqueHash("alice-level-1");
        SigilProof memory proof = _buildProof(alice, 1, sigil);

        uint256 treasuryBefore = treasury.balance;

        vm.prank(alice);
        gate.enterGate{value: PRICE_1_4}(proof, alice);

        // Check entry recorded
        GateEntry memory entry = gate.gateEntries(alice);
        assertTrue(entry.active,                "entry not active");
        assertEq(entry.entrant,   alice,         "entrant mismatch");
        assertEq(entry.gateLevel, 1,             "gate level mismatch");
        assertEq(entry.sigilHash, sigil,         "sigil hash mismatch");

        // Check payment forwarded
        assertEq(treasury.balance - treasuryBefore, PRICE_1_4, "treasury payment mismatch");

        // Check state counters
        assertEq(gate.totalRevenue(), PRICE_1_4, "totalRevenue mismatch");
        assertEq(gate.entrantCount(), 1,          "entrantCount mismatch");
        assertEq(gate.totalPaid(alice), PRICE_1_4, "totalPaid mismatch");

        // hasGateAccess
        assertTrue(gate.hasGateAccess(alice, 1), "alice should have gate 1 access");
        assertFalse(gate.hasGateAccess(alice, 2), "alice should not have gate 2+ access");
    }

    function test_enterGate_level5() public {
        bytes32 sigil = _uniqueHash("bob-level-5");
        SigilProof memory proof = _buildProof(bob, 5, sigil);

        vm.prank(bob);
        gate.enterGate{value: PRICE_5_8}(proof, bob);

        GateEntry memory entry = gate.gateEntries(bob);
        assertEq(entry.gateLevel, 5, "gate level should be 5");
        assertTrue(entry.active,     "entry should be active");
        assertEq(gate.totalRevenue(), PRICE_5_8, "revenue should be PRICE_5_8");
    }

    function test_enterGate_overpayment_accepted() public {
        bytes32 sigil = _uniqueHash("alice-overpay");
        SigilProof memory proof = _buildProof(alice, 1, sigil);

        // Overpay — gate should still accept it (full value forwarded to treasury)
        vm.prank(alice);
        gate.enterGate{value: 1 ether}(proof, alice);

        assertTrue(gate.gateEntries(alice).active, "entry should be active");
        assertEq(gate.totalRevenue(), 1 ether,     "revenue should reflect full overpayment");
    }

    function test_enterGate_revert_insufficientPayment() public {
        bytes32 sigil = _uniqueHash("alice-underpay");
        SigilProof memory proof = _buildProof(alice, 1, sigil);

        vm.prank(alice);
        vm.expectRevert(bytes("MU: insufficient x402 payment"));
        gate.enterGate{value: PRICE_1_4 - 1}(proof, alice);
    }

    function test_enterGate_revert_expiredProof() public {
        bytes32 sigil = _uniqueHash("alice-expired");
        SigilProof memory proof = _buildProof(alice, 1, sigil);

        // Advance time beyond PROOF_WINDOW (5 minutes)
        vm.warp(block.timestamp + 6 minutes);

        vm.prank(alice);
        vm.expectRevert(bytes("MU: sigil proof expired"));
        gate.enterGate{value: PRICE_1_4}(proof, alice);
    }

    function test_enterGate_revert_invalidSeal() public {
        bytes32 sigil = _uniqueHash("alice-badseal");
        SigilProof memory proof = _buildProof(alice, 1, sigil);

        // Corrupt the MU seal
        proof.muSeal = keccak256("NOT_THE_MU_SEAL");

        vm.prank(alice);
        vm.expectRevert(bytes("MU: invalid sovereign seal \xF0\x92\x89\x99\xE2\x8D\xA4\xF0\x90\xA4\x8C\xF0\x90\xA4\x8FMU"));
        gate.enterGate{value: PRICE_1_4}(proof, alice);
    }

    function test_enterGate_revert_replayProtection() public {
        bytes32 sigil = _uniqueHash("alice-replay");
        SigilProof memory proof = _buildProof(alice, 1, sigil);

        vm.startPrank(alice);
        gate.enterGate{value: PRICE_1_4}(proof, alice);

        // Same proof — replay
        vm.expectRevert(bytes("MU: sigil already consumed (replay)"));
        gate.enterGate{value: PRICE_1_4}(proof, alice);
        vm.stopPrank();
    }

    function test_enterGate_revert_invalidSignature() public {
        bytes32 sigil = _uniqueHash("alice-badsig");
        SigilProof memory proof = _buildProof(alice, 1, sigil);

        // Corrupt signature (flip last byte)
        bytes memory sig = proof.signature;
        sig[64] = sig[64] ^ 0x01;
        proof.signature = sig;

        vm.prank(alice);
        vm.expectRevert(bytes("MU: sigil signature invalid — not sovereign oracle"));
        gate.enterGate{value: PRICE_1_4}(proof, alice);
    }

    function test_enterGate_revert_zeroEntrant() public {
        bytes32 sigil = _uniqueHash("zero-entrant");
        SigilProof memory proof = _buildProof(address(0), 1, sigil);

        vm.prank(alice);
        vm.expectRevert(bytes("MU: zero entrant"));
        gate.enterGate{value: PRICE_1_4}(proof, address(0));
    }

    function test_enterGate_revert_invalidLevel() public {
        bytes32 sigil = _uniqueHash("level-zero");
        SigilProof memory proof = _buildProof(alice, 0, sigil);

        vm.prank(alice);
        vm.expectRevert(bytes("MU: invalid gate level"));
        gate.enterGate{value: 0}(proof, alice);
    }

    // ─── Level 9+ Sigil NFT requirement ──────────────────────────────────────

    function test_enterGate_level9_requiresSigilNFT() public {
        bytes32 sigil = _uniqueHash("alice-level-9");
        SigilProof memory proof = _buildProof(alice, 9, sigil);

        // Alice does NOT hold level 9 sigil NFT
        vm.prank(alice);
        vm.expectRevert(bytes("MU: insufficient sigil NFT tier for sovereign layer"));
        gate.enterGate{value: PRICE_9_12}(proof, alice);
    }

    function test_enterGate_level9_withSigilNFT() public {
        // Grant alice level 9 sigil
        sigilNFT.setGateLevel(alice, 9, true);

        bytes32 sigil = _uniqueHash("alice-level-9-ok");
        SigilProof memory proof = _buildProof(alice, 9, sigil);

        vm.prank(alice);
        gate.enterGate{value: PRICE_9_12}(proof, alice);

        assertTrue(gate.gateEntries(alice).active, "entry should be active");
        assertEq(gate.gateEntries(alice).gateLevel, 9, "gate level should be 9");
        assertTrue(gate.hasGateAccess(alice, 9), "alice should have level 9 access");
    }

    function test_enterGate_level13_sovereign() public {
        // Grant alice level 13 sigil
        sigilNFT.setGateLevel(alice, 13, true);

        bytes32 sigil = _uniqueHash("alice-level-13");
        SigilProof memory proof = _buildProof(alice, 13, sigil);

        vm.prank(alice);
        gate.enterGate{value: PRICE_13}(proof, alice);

        GateEntry memory entry = gate.gateEntries(alice);
        assertEq(entry.gateLevel, 13, "gate level should be 13");
        assertTrue(entry.active,      "entry should be active");
        assertEq(gate.totalRevenue(), PRICE_13, "revenue mismatch");
    }

    // ─── XMR Bridge Entry ─────────────────────────────────────────────────────

    function test_enterGateXmr() public {
        bytes32 xmrHash = keccak256("monero_tx_hash_12345");
        bytes32 sigil   = _uniqueHash("alice-xmr");

        // Sovereign registers XMR commitment
        vm.prank(sovereign);
        gate.registerXmrHash(xmrHash);

        // Alice enters via XMR bridge
        SigilProof memory proof = _buildProof(alice, 3, sigil);
        gate.enterGateXmr(xmrHash, proof, alice);

        GateEntry memory entry = gate.gateEntries(alice);
        assertTrue(entry.active,           "entry should be active");
        assertEq(entry.gateLevel, 3,       "gate level should be 3");
        assertEq(gate.entrantCount(), 1,   "entrantCount mismatch");

        // XMR hash should be consumed
        assertFalse(gate.xmrHashRegistry(xmrHash), "xmrHash should be consumed");

        PaymentRecord memory rec = gate.payments(alice);
        assertTrue(rec.xmrBridgePaid, "xmrBridgePaid should be true");
        assertEq(rec.xmrBridgeHash, xmrHash, "xmrBridgeHash mismatch");
    }

    function test_enterGateXmr_revert_unregisteredHash() public {
        bytes32 xmrHash = keccak256("unregistered_xmr_hash");
        bytes32 sigil   = _uniqueHash("alice-xmr-bad");

        SigilProof memory proof = _buildProof(alice, 1, sigil);
        vm.expectRevert(bytes("MU: XMR hash not registered"));
        gate.enterGateXmr(xmrHash, proof, alice);
    }

    function test_registerXmrHash_onlySovereign() public {
        bytes32 xmrHash = keccak256("xmr_hash_onlySovereign");

        vm.prank(alice);
        vm.expectRevert(bytes("MU: not sovereign"));
        gate.registerXmrHash(xmrHash);
    }

    function test_registerXmrHash_revert_duplicate() public {
        bytes32 xmrHash = keccak256("xmr_hash_dup");
        vm.prank(sovereign);
        gate.registerXmrHash(xmrHash);

        vm.prank(sovereign);
        vm.expectRevert(bytes("MU: XMR hash already registered"));
        gate.registerXmrHash(xmrHash);
    }

    // ─── Superfluid Entry ─────────────────────────────────────────────────────

    function test_enterGateSuperfluid() public {
        // Activate stream: alice → treasury
        superfluid.setStreaming(alice, treasury, true);

        bytes32 sigil = _uniqueHash("alice-superfluid");
        SigilProof memory proof = _buildProof(alice, 6, sigil);

        gate.enterGateSuperfluid(proof, alice);

        GateEntry memory entry = gate.gateEntries(alice);
        assertTrue(entry.active,     "entry should be active");
        assertEq(entry.gateLevel, 6, "gate level should be 6");

        PaymentRecord memory rec = gate.payments(alice);
        assertTrue(rec.superfluidActive, "superfluidActive should be true");
    }

    function test_enterGateSuperfluid_revert_noStream() public {
        bytes32 sigil = _uniqueHash("alice-no-stream");
        SigilProof memory proof = _buildProof(alice, 4, sigil);

        vm.expectRevert(bytes("MU: no active Superfluid stream to treasury"));
        gate.enterGateSuperfluid(proof, alice);
    }

    // ─── Sovereign Management ─────────────────────────────────────────────────

    function test_revokeAccess() public {
        // Enter first
        bytes32 sigil = _uniqueHash("alice-revoke");
        SigilProof memory proof = _buildProof(alice, 2, sigil);
        vm.prank(alice);
        gate.enterGate{value: PRICE_1_4}(proof, alice);

        assertTrue(gate.gateEntries(alice).active, "entry should be active before revoke");

        // Sovereign revokes
        vm.prank(sovereign);
        gate.revokeAccess(alice);

        assertFalse(gate.gateEntries(alice).active, "entry should be inactive after revoke");
        assertFalse(gate.hasGateAccess(alice, 2),   "alice should not have gate access after revoke");
    }

    function test_revokeAccess_onlySovereign() public {
        vm.prank(alice);
        vm.expectRevert(bytes("MU: not sovereign"));
        gate.revokeAccess(bob);
    }

    function test_revokeAccess_revert_noActiveEntry() public {
        vm.prank(sovereign);
        vm.expectRevert(bytes("MU: no active entry"));
        gate.revokeAccess(alice);
    }

    function test_toggleGateSeal() public {
        assertFalse(gate.gateSealed(), "gate should start open");

        vm.prank(sovereign);
        gate.toggleGateSeal();
        assertTrue(gate.gateSealed(), "gate should be sealed");

        vm.prank(sovereign);
        gate.toggleGateSeal();
        assertFalse(gate.gateSealed(), "gate should be re-opened");
    }

    function test_toggleGateSeal_onlySovereign() public {
        vm.prank(alice);
        vm.expectRevert(bytes("MU: not sovereign"));
        gate.toggleGateSeal();
    }

    function test_enterGate_revert_whenSealed() public {
        vm.prank(sovereign);
        gate.toggleGateSeal();

        bytes32 sigil = _uniqueHash("sealed");
        SigilProof memory proof = _buildProof(alice, 1, sigil);

        vm.prank(alice);
        vm.expectRevert(bytes("MU: gate sealed by sovereign decree"));
        gate.enterGate{value: PRICE_1_4}(proof, alice);
    }

    function test_transferSovereignty() public {
        address newSovereign = makeAddr("newSovereign");

        vm.prank(sovereign);
        gate.transferSovereignty(newSovereign);

        assertEq(gate.sovereign(), newSovereign, "sovereignty not transferred");

        // Old sovereign can no longer call sovereign functions
        vm.prank(sovereign);
        vm.expectRevert(bytes("MU: not sovereign"));
        gate.toggleGateSeal();

        // New sovereign can
        vm.prank(newSovereign);
        gate.toggleGateSeal();
        assertTrue(gate.gateSealed(), "new sovereign should be able to seal");
    }

    function test_transferSovereignty_revert_zeroAddress() public {
        vm.prank(sovereign);
        vm.expectRevert(bytes("MU: zero sovereign"));
        gate.transferSovereignty(address(0));
    }

    function test_updateAddresses() public {
        address newSigilNFT   = makeAddr("newSigilNFT");
        address newSuperfluid = makeAddr("newSuperfluid");
        address newTreasury   = makeAddr("newTreasury");

        vm.prank(sovereign);
        gate.updateAddresses(newSigilNFT, newSuperfluid, newTreasury);

        assertEq(gate.sigilNFT(),         newSigilNFT,   "sigilNFT not updated");
        assertEq(gate.superfluidRouter(), newSuperfluid, "superfluid not updated");
        assertEq(gate.treasury(),         newTreasury,   "treasury not updated");
    }

    function test_updateAddresses_zeroIgnored() public {
        address originalSigil    = gate.sigilNFT();
        address originalFluid    = gate.superfluidRouter();
        address originalTreasury = gate.treasury();

        // Pass zero — should not overwrite
        vm.prank(sovereign);
        gate.updateAddresses(address(0), address(0), address(0));

        assertEq(gate.sigilNFT(),         originalSigil,    "sigilNFT should be unchanged");
        assertEq(gate.superfluidRouter(), originalFluid,    "superfluid should be unchanged");
        assertEq(gate.treasury(),         originalTreasury, "treasury should be unchanged");
    }

    // ─── Fuzz Test ────────────────────────────────────────────────────────────

    /**
     * @notice Fuzz gate level — any valid level (1–13) should be stored correctly.
     */
    function testFuzz_enterGate_allLevels(uint8 rawLevel) public {
        // Bound to valid range 1–8 (avoid 9–13 which require sigil NFT)
        uint8 level = uint8(bound(rawLevel, 1, 8));

        bytes32 sigil = keccak256(abi.encodePacked("fuzz", level, block.timestamp));
        SigilProof memory proof = _buildProof(alice, level, sigil);
        uint256 price = gate.gatePrice(level);

        vm.deal(alice, price);
        vm.prank(alice);
        gate.enterGate{value: price}(proof, alice);

        assertEq(gate.gateEntries(alice).gateLevel, level, "gate level mismatch");
        assertTrue(gate.gateEntries(alice).active,         "entry should be active");
    }
}
