// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title WatcherGateV2Test
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry test suite for WatcherGateV2.sol + SpellPaymentV2.sol
 *
 * Run: forge test --match-path test/WatcherGateV2.t.sol -vvvv
 */

import {Test, console} from "forge-std/Test.sol";
import {WatcherGateV2, AuthMode, GateLayerConfig} from "../06_Contracts/WatcherGateV2.sol";
import {SpellPaymentV2, SpellReceipt}              from "../06_Contracts/SpellPaymentV2.sol";
import {SigilNFT}                                  from "../06_Contracts/SigilNFT.sol";
import {GrimoireERC8004Registry}                   from "../erc8004-registry/GrimoireERC8004Registry.sol";

/**
 * @dev Minimal EIP-3009 mock token for testing castSpellWithUSDC /
 *      withdrawUSDC. Does NOT verify the (v, r, s) signature — it is a
 *      test-only stand-in for Base USDC's real receiveWithAuthorization,
 *      which does perform full EIP-712 signature verification on-chain.
 */
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(bytes32 => bool)    public authorizationUsed;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8   /* v */,
        bytes32 /* r */,
        bytes32 /* s */
    ) external {
        require(block.timestamp > validAfter,  "MockUSDC: auth not yet valid");
        require(block.timestamp < validBefore, "MockUSDC: auth expired");
        require(!authorizationUsed[nonce],     "MockUSDC: auth already used");
        require(balanceOf[from] >= value,      "MockUSDC: insufficient balance");

        authorizationUsed[nonce] = true;
        balanceOf[from] -= value;
        balanceOf[to]   += value;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "MockUSDC: insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract WatcherGateV2Test is Test {

    WatcherGateV2            gate;
    SpellPaymentV2           spellPayment;
    SigilNFT                 sigilNFT;
    GrimoireERC8004Registry  registry;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    // ─── Setup ───────────────────────────────────────────────────────────────

    function setUp() public {
        sigilNFT     = new SigilNFT();
        spellPayment = new SpellPaymentV2(address(0));
        gate         = new WatcherGateV2(address(spellPayment));
        registry     = new GrimoireERC8004Registry();

        spellPayment.setWatcherGate(address(gate));
        gate.setERC8004Registry(address(registry));

        // Layer 1 — PAYMENT_ONLY
        gate.configureLayer(
            1, 0.0001 ether, 1 days, AuthMode.PAYMENT_ONLY, address(0), keccak256("LAYER_1_KEY"), 0
        );
        gate.activateLayer(1);

        // Layer 4 — SIGIL_ONLY, requires at least tier 2 (Initiate)
        gate.configureLayer(
            4, 0, 1 days, AuthMode.SIGIL_ONLY, address(sigilNFT), keccak256("LAYER_4_KEY"), 2
        );
        gate.activateLayer(4);

        // Layer 13 — DUAL_AUTH (sovereign), requires tier 4 (Sovereign) sigil
        gate.configureLayer(
            13, 0.1 ether, 1 days, AuthMode.DUAL_AUTH, address(sigilNFT), keccak256("LAYER_13_KEY"), 4
        );
        gate.activateLayer(13);

        vm.deal(alice, 10 ether);
        vm.deal(bob,   10 ether);
    }

    // ─── Baseline parity with v1 behavior ─────────────────────────────────────

    function testEnterGateWithPayment() public {
        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        assertTrue(gate.hasLayerAccess(alice, 1));
        assertEq(gate.highestLayerReached(alice), 1);
    }

    function testEnterGateInsufficientPayment() public {
        vm.prank(alice);
        vm.expectRevert("WatcherGateV2: insufficient payment");
        gate.enterGateWithPayment{value: 0.00001 ether}(1);
    }

    // ─── Sigil tier enforcement (new in v2) ───────────────────────────────────

    function testEnterGateWithSigilSufficientTierSucceeds() public {
        // Tier 2 (Initiate) sigil — exactly meets layer 4's required tier.
        sigilNFT.mint(alice, 2, "ipfs://sigil-alice-initiate");

        vm.prank(alice);
        gate.enterGateWithSigil(4, 1);

        assertTrue(gate.hasLayerAccess(alice, 4));
    }

    function testEnterGateWithSigilHigherTierSucceeds() public {
        // Tier 4 (Sovereign) sigil — exceeds layer 4's required tier of 2.
        sigilNFT.mint(alice, 4, "ipfs://sigil-alice-sovereign");

        vm.prank(alice);
        gate.enterGateWithSigil(4, 1);

        assertTrue(gate.hasLayerAccess(alice, 4));
    }

    function testEnterGateWithSigilTooLowTierReverts() public {
        // Tier 1 (Neophyte) sigil — below layer 4's required tier of 2.
        sigilNFT.mint(alice, 1, "ipfs://sigil-alice-neophyte");

        vm.prank(alice);
        vm.expectRevert("WatcherGateV2: sigil tier too low");
        gate.enterGateWithSigil(4, 1);
    }

    function testEnterGateWithDualAuthRequiresSovereignTier() public {
        // Tier 3 (Adept) is not enough for layer 13's required tier 4.
        sigilNFT.mint(alice, 3, "ipfs://sigil-alice-adept");

        vm.prank(alice);
        vm.expectRevert("WatcherGateV2: sigil tier too low");
        gate.enterGateWithDualAuth{value: 0.1 ether}(13, 1);
    }

    function testEnterGateWithDualAuthSovereignTierSucceeds() public {
        sigilNFT.mint(alice, 4, "ipfs://sigil-alice-sovereign");

        vm.prank(alice);
        gate.enterGateWithDualAuth{value: 0.1 ether}(13, 1);

        assertTrue(gate.hasLayerAccess(alice, 13));
    }

    // ─── Single-use receipt enforcement (new in v2) ───────────────────────────

    function testX402ReceiptIsConsumedAndCannotBeReplayed() public {
        vm.prank(alice);
        bytes32 receiptHash = spellPayment.castSpell{value: 0.0001 ether}(1);

        // First use succeeds.
        vm.prank(alice);
        gate.enterGateWithX402Receipt(1, receiptHash);
        assertTrue(gate.hasLayerAccess(alice, 1));

        // Replaying the same receipt must fail — it was consumed.
        vm.prank(alice);
        vm.expectRevert("WatcherGateV2: invalid or expired receipt");
        gate.enterGateWithX402Receipt(1, receiptHash);
    }

    function testX402AndSigilReceiptIsConsumed() public {
        sigilNFT.mint(alice, 4, "ipfs://sigil-alice-sovereign");

        vm.prank(alice);
        bytes32 receiptHash = spellPayment.castSpell{value: 0.1 ether}(13);

        vm.prank(alice);
        gate.enterGateWithX402AndSigil(13, receiptHash, 1);
        assertTrue(gate.hasLayerAccess(alice, 13));

        vm.prank(alice);
        vm.expectRevert("WatcherGateV2: invalid or expired receipt");
        gate.enterGateWithX402AndSigil(13, receiptHash, 1);
    }

    // ─── Price-enforced receipts (new in v2) ──────────────────────────────────

    function testCastSpellBelowPinnedPriceReverts() public {
        spellPayment.setLayerPrice(1, 0.0005 ether);

        vm.prank(alice);
        vm.expectRevert("SpellPaymentV2: payment below layer price");
        spellPayment.castSpell{value: 0.0001 ether}(1);
    }

    function testCastSpellAtOrAbovePinnedPriceSucceeds() public {
        spellPayment.setLayerPrice(1, 0.0005 ether);

        vm.prank(alice);
        bytes32 receiptHash = spellPayment.castSpell{value: 0.0005 ether}(1);

        vm.prank(alice);
        gate.enterGateWithX402Receipt(1, receiptHash);
        assertTrue(gate.hasLayerAccess(alice, 1));
    }

    function testCastSpellUnpinnedPriceAcceptsAnyNonZero() public {
        // No price pinned for layer 1 by default in this test (reset state) —
        // falls back to v1-style "any non-zero payment" behavior.
        vm.prank(bob);
        bytes32 receiptHash = spellPayment.castSpell{value: 1 wei}(1);
        assertTrue(receiptHash != bytes32(0));
    }

    // ─── Pause (new in v2) ─────────────────────────────────────────────────────

    function testPausedGateRejectsNewEntries() public {
        gate.pause();

        vm.prank(alice);
        vm.expectRevert("WatcherGateV2: paused");
        gate.enterGateWithPayment{value: 0.0001 ether}(1);
    }

    function testUnpauseRestoresEntries() public {
        gate.pause();
        gate.unpause();

        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);
        assertTrue(gate.hasLayerAccess(alice, 1));
    }

    function testPausedSpellPaymentRejectsNewCasts() public {
        spellPayment.pause();

        vm.prank(alice);
        vm.expectRevert("SpellPaymentV2: paused");
        spellPayment.castSpell{value: 0.0001 ether}(1);
    }

    function testWithdrawWorksEvenWhenPaused() public {
        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        gate.pause();

        uint256 balanceBefore = owner.balance;
        gate.withdraw();
        assertGt(owner.balance, balanceBefore);
    }

    // ─── Key commitments (new in v2) ───────────────────────────────────────────

    function testRevealKeyUpdateBeforeDelayReverts() public {
        bytes32 newKey = keccak256("NEW_LAYER_1_KEY");
        bytes32 salt   = keccak256("salt-1");
        bytes32 commitHash = keccak256(abi.encodePacked(newKey, salt));

        gate.commitKeyUpdate(1, commitHash);

        vm.expectRevert("WatcherGateV2: reveal too early");
        gate.revealKeyUpdate(1, newKey, salt);
    }

    function testRevealKeyUpdateWithWrongPreimageReverts() public {
        bytes32 newKey = keccak256("NEW_LAYER_1_KEY");
        bytes32 salt   = keccak256("salt-1");
        bytes32 commitHash = keccak256(abi.encodePacked(newKey, salt));

        gate.commitKeyUpdate(1, commitHash);
        skip(1 hours);

        bytes32 wrongKey = keccak256("WRONG_KEY");
        vm.expectRevert("WatcherGateV2: commitment mismatch");
        gate.revealKeyUpdate(1, wrongKey, salt);
    }

    function testRevealKeyUpdateAfterDelaySucceeds() public {
        bytes32 newKey = keccak256("NEW_LAYER_1_KEY");
        bytes32 salt   = keccak256("salt-1");
        bytes32 commitHash = keccak256(abi.encodePacked(newKey, salt));

        gate.commitKeyUpdate(1, commitHash);
        skip(1 hours);
        gate.revealKeyUpdate(1, newKey, salt);

        // Alice must have active access to read the key.
        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        vm.prank(alice);
        bytes32 key = gate.getLayerEncodedKey(1);
        assertEq(key, newKey);
    }

    // ─── Two-step ownership (new in v2) ────────────────────────────────────────

    function testTransferOwnershipRequiresAcceptance() public {
        gate.transferOwnership(alice);

        // Ownership has NOT changed yet — old owner can still act.
        assertEq(gate.owner(), owner);

        vm.prank(bob);
        vm.expectRevert("WatcherGateV2: not pending owner");
        gate.acceptOwnership();

        vm.prank(alice);
        gate.acceptOwnership();
        assertEq(gate.owner(), alice);
    }

    function testSpellPaymentTwoStepOwnership() public {
        spellPayment.transferOwnership(alice);
        assertEq(spellPayment.owner(), owner);

        vm.prank(alice);
        spellPayment.acceptOwnership();
        assertEq(spellPayment.owner(), alice);
    }

    // ─── USDC (EIP-3009) payments (new in v2) ──────────────────────────────────

    function testCastSpellWithUSDCSucceeds() public {
        MockUSDC usdc = new MockUSDC();
        usdc.mint(alice, 100e6); // 100 USDC

        spellPayment.setUsdcToken(address(usdc));

        vm.prank(alice);
        bytes32 receiptHash = spellPayment.castSpellWithUSDC(
            1,
            10e6, // 10 USDC
            0,
            block.timestamp + 1 hours,
            keccak256("nonce-1"),
            0, bytes32(0), bytes32(0)
        );

        vm.prank(alice);
        gate.enterGateWithX402Receipt(1, receiptHash);
        assertTrue(gate.hasLayerAccess(alice, 1));
        assertEq(usdc.balanceOf(address(spellPayment)), 10e6);
    }

    function testCastSpellWithUSDCBelowPinnedPriceReverts() public {
        MockUSDC usdc = new MockUSDC();
        usdc.mint(alice, 100e6);

        spellPayment.setUsdcToken(address(usdc));
        spellPayment.setLayerPriceUSDC(1, 20e6);

        vm.prank(alice);
        vm.expectRevert("SpellPaymentV2: USDC payment below layer price");
        spellPayment.castSpellWithUSDC(
            1, 10e6, 0, block.timestamp + 1 hours, keccak256("nonce-2"), 0, bytes32(0), bytes32(0)
        );
    }

    function testWithdrawUSDC() public {
        MockUSDC usdc = new MockUSDC();
        usdc.mint(alice, 100e6);
        spellPayment.setUsdcToken(address(usdc));

        vm.prank(alice);
        spellPayment.castSpellWithUSDC(
            1, 10e6, 0, block.timestamp + 1 hours, keccak256("nonce-3"), 0, bytes32(0), bytes32(0)
        );

        spellPayment.withdrawUSDC();
        assertEq(usdc.balanceOf(owner), 10e6);
    }

    // ─── Agent discount parity ─────────────────────────────────────────────────

    function testAgentDiscount() public {
        gate.registerAgent(alice);
        assertTrue(gate.verifiedAgents(alice));

        uint256 basePrice = 0.0001 ether;
        uint256 expected  = basePrice - (basePrice * 500 / 10000);

        vm.prank(alice);
        gate.enterGateWithPayment{value: expected}(1);

        assertTrue(gate.hasLayerAccess(alice, 1));
    }

    // ─── receive ETH ─────────────────────────────────────────────────────────

    receive() external payable {}
}
