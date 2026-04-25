// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title WatcherGateTest
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry test suite for WatcherGate.sol
 *
 * Run: forge test --match-path test/WatcherGate.t.sol -vvvv
 */

import {Test, console} from "forge-std/Test.sol";
import {WatcherGate, AuthMode, GateLayerConfig} from "../06_Contracts/WatcherGate.sol";
import {SpellPayment, SpellReceipt}              from "../06_Contracts/SpellPayment.sol";
import {SigilNFT}                                from "../06_Contracts/SigilNFT.sol";
import {GrimoireERC8004Registry}                 from "../erc8004-registry/GrimoireERC8004Registry.sol";

contract WatcherGateTest is Test {

    WatcherGate             gate;
    SpellPayment            spellPayment;
    SigilNFT                sigilNFT;
    GrimoireERC8004Registry registry;

    address owner   = address(this);
    address alice   = address(0xA11CE);
    address bob     = address(0xB0B);

    // ─── Setup ───────────────────────────────────────────────────────────────

    function setUp() public {
        sigilNFT     = new SigilNFT();
        spellPayment = new SpellPayment(address(0));
        gate         = new WatcherGate(address(spellPayment));
        registry     = new GrimoireERC8004Registry();

        // Wire together
        spellPayment.setWatcherGate(address(gate));
        gate.setERC8004Registry(address(registry));

        // Configure and activate layer 1 (PAYMENT_ONLY)
        gate.configureLayer(
            1,
            0.0001 ether,
            1 days,
            AuthMode.PAYMENT_ONLY,
            address(0),
            keccak256("LAYER_1_KEY")
        );
        gate.activateLayer(1);

        // Configure layer 4 (SIGIL_ONLY)
        gate.configureLayer(
            4,
            0,
            1 days,
            AuthMode.SIGIL_ONLY,
            address(sigilNFT),
            keccak256("LAYER_4_KEY")
        );
        gate.activateLayer(4);

        // Configure layer 13 (DUAL_AUTH)
        gate.configureLayer(
            13,
            0.1 ether,
            1 days,
            AuthMode.DUAL_AUTH,
            address(sigilNFT),
            keccak256("LAYER_13_KEY")
        );
        gate.activateLayer(13);

        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob,   10 ether);
    }

    // ─── testEnterGateWithPayment ─────────────────────────────────────────────

    function testEnterGateWithPayment() public {
        uint256 price = 0.0001 ether;

        vm.prank(alice);
        gate.enterGateWithPayment{value: price}(1);

        assertTrue(gate.hasLayerAccess(alice, 1));
        assertEq(gate.highestLayerReached(alice), 1);
    }

    // ─── testEnterGateInsufficientPayment ─────────────────────────────────────

    function testEnterGateInsufficientPayment() public {
        vm.prank(alice);
        vm.expectRevert("WatcherGate: insufficient payment");
        gate.enterGateWithPayment{value: 0.00001 ether}(1);
    }

    // ─── testEnterGateWithSigil ───────────────────────────────────────────────

    function testEnterGateWithSigil() public {
        // Mint an Initiate sigil (tier 2) to alice
        sigilNFT.mint(alice, 2, "ipfs://sigil-alice");

        // Alice enters layer 4 using her sigil (tokenId 1)
        vm.prank(alice);
        gate.enterGateWithSigil(4, 1);

        assertTrue(gate.hasLayerAccess(alice, 4));
        assertEq(gate.highestLayerReached(alice), 4);
    }

    // ─── testEnterGateWithDualAuth ────────────────────────────────────────────

    function testEnterGateWithDualAuth() public {
        // Mint a Sovereign sigil (tier 4) to alice
        sigilNFT.mint(alice, 4, "ipfs://sigil-sovereign-alice");

        // Alice enters layer 13 with payment + sigil
        vm.prank(alice);
        gate.enterGateWithDualAuth{value: 0.1 ether}(13, 1);

        assertTrue(gate.hasLayerAccess(alice, 13));
        assertEq(gate.highestLayerReached(alice), 13);
    }

    // ─── testAgentDiscount ────────────────────────────────────────────────────

    function testAgentDiscount() public {
        // Register alice as an agent
        gate.registerAgent(alice);
        assertTrue(gate.verifiedAgents(alice));

        uint256 basePrice = 0.0001 ether;
        uint256 discount  = basePrice * 500 / 10000;  // 5%
        uint256 expected  = basePrice - discount;

        // Alice should pay discounted price (exact amount — no excess)
        vm.prank(alice);
        gate.enterGateWithPayment{value: expected}(1);

        assertTrue(gate.hasLayerAccess(alice, 1));
    }

    // ─── testGetAccessStatus ──────────────────────────────────────────────────

    function testGetAccessStatus() public {
        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        (bool[14] memory active, uint256[14] memory expiries) = gate.getAccessStatus(alice);

        assertTrue(active[1]);
        assertGt(expiries[1], block.timestamp);

        // Layers 2-13 should be inactive
        for (uint8 i = 2; i <= 13; i++) {
            assertFalse(active[i]);
            assertEq(expiries[i], 0);
        }
    }

    // ─── testGetLayerEncodedKey ───────────────────────────────────────────────

    function testGetLayerEncodedKey() public {
        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        vm.prank(alice);
        bytes32 key = gate.getLayerEncodedKey(1);

        assertEq(key, keccak256("LAYER_1_KEY"));
    }

    function testGetLayerEncodedKeyNoAccess() public {
        vm.prank(alice);
        vm.expectRevert("WatcherGate: no active access to this layer");
        gate.getLayerEncodedKey(1);
    }

    // ─── testWithdraw ─────────────────────────────────────────────────────────

    function testWithdraw() public {
        // Alice pays to enter layer 1
        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        uint256 balanceBefore = owner.balance;
        gate.withdraw();
        uint256 balanceAfter = owner.balance;

        assertGt(balanceAfter, balanceBefore);
    }

    // ─── testNonOwnerWithdrawReverts ──────────────────────────────────────────

    function testNonOwnerWithdrawReverts() public {
        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        vm.prank(bob);
        vm.expectRevert("WatcherGate: not owner");
        gate.withdraw();
    }

    // ─── testSelfRegisterAsAgent ──────────────────────────────────────────────

    function testSelfRegisterAsAgent() public {
        assertFalse(gate.verifiedAgents(alice));

        vm.prank(alice);
        gate.selfRegisterAsAgent();

        assertTrue(gate.verifiedAgents(alice));
        assertTrue(registry.isRegistered(alice));
    }

    function testSelfRegisterAsAgentTwiceReverts() public {
        vm.prank(alice);
        gate.selfRegisterAsAgent();

        vm.prank(alice);
        vm.expectRevert("WatcherGate: already a verified agent");
        gate.selfRegisterAsAgent();
    }

    // ─── testExtendAccess ─────────────────────────────────────────────────────

    function testExtendAccess() public {
        // Alice enters layer 1
        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        uint256 originalExpiry = gate.accessExpiresAt(alice, 1);

        // Extend before expiry
        vm.prank(alice);
        gate.extendAccess{value: 0.0001 ether}(1);

        uint256 newExpiry = gate.accessExpiresAt(alice, 1);
        assertEq(newExpiry, originalExpiry + 1 days);
    }

    function testExtendAccessWithoutActiveAccessReverts() public {
        vm.prank(alice);
        vm.expectRevert("WatcherGate: no active access to extend");
        gate.extendAccess{value: 0.0001 ether}(1);
    }

    // ─── testLayerActivation ──────────────────────────────────────────────────

    function testLayerActivation() public {
        // Deactivate layer 1
        gate.deactivateLayer(1);

        vm.prank(alice);
        vm.expectRevert("WatcherGate: layer not active");
        gate.enterGateWithPayment{value: 0.0001 ether}(1);

        // Reactivate
        gate.activateLayer(1);

        vm.prank(alice);
        gate.enterGateWithPayment{value: 0.0001 ether}(1);
        assertTrue(gate.hasLayerAccess(alice, 1));
    }

    // ─── testEnterGateWithX402AndSigil ────────────────────────────────────────

    function testEnterGateWithX402AndSigil() public {
        // Mint sovereign sigil to alice
        sigilNFT.mint(alice, 4, "ipfs://sigil-sovereign-alice");

        // Alice casts a spell for layer 13
        vm.prank(alice);
        bytes32 receiptHash = spellPayment.castSpell{value: 0.1 ether}(13);

        // Alice enters layer 13 using receipt + sigil
        vm.prank(alice);
        gate.enterGateWithX402AndSigil(13, receiptHash, 1);

        assertTrue(gate.hasLayerAccess(alice, 13));
    }

    // ─── receive ETH ─────────────────────────────────────────────────────────

    receive() external payable {}
}
