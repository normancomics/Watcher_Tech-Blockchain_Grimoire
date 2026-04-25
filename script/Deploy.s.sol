// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Deploy
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry deployment script for the full WatcherTech Blockchain Grimoire suite.
 *
 * Deployment order (dependency-respecting):
 *   Step 1:  Deploy SigilNFT
 *   Step 2:  Deploy ArcanusMathematica
 *   Step 3:  Deploy SpellPayment(address(0)) — WatcherGate address wired in Step 7
 *   Step 4:  Deploy WatcherGate(spellPaymentAddress)
 *   Step 5:  Deploy GrimoireERC8004Registry
 *   Step 6:  Deploy GrimoireReputationRegistry
 *
 * Post-deploy wiring:
 *   Step 7:  SpellPayment.setWatcherGate(watcherGate)
 *   Step 8:  WatcherGate.setERC8004Registry(registry)
 *   Step 9:  ArcanusMathematica.setWatcherGate(watcherGate)
 *   Step 10: WatcherGate.configureLayer(1..13) with SigilNFT address
 *   Step 11: WatcherGate.activateLayer(1) — first layer open
 *   Step 12: GrimoireERC8004Registry.registerAgent(deployer, "ipfs://PLACEHOLDER_CID")
 *   Step 13: WatcherGate.registerAgent(deployer)
 *   Step 14: console.log all deployed addresses
 *
 * Usage:
 *   forge script script/Deploy.s.sol --rpc-url base --broadcast --verify -vvvv
 */

import {Script, console} from "forge-std/Script.sol";

import {SpellPayment}               from "../06_Contracts/SpellPayment.sol";
import {SigilNFT}                   from "../06_Contracts/SigilNFT.sol";
import {WatcherGate, AuthMode}      from "../06_Contracts/WatcherGate.sol";
import {ArcanusMathematica}         from "../06_Contracts/ArcanusMathematica.sol";
import {GrimoireERC8004Registry}    from "../erc8004-registry/GrimoireERC8004Registry.sol";
import {GrimoireReputationRegistry} from "../erc8004-registry/GrimoireReputationRegistry.sol";

contract Deploy is Script {

    // ─── Layer configuration ──────────────────────────────────────────────────

    uint256[14] internal LAYER_PRICES = [
        uint256(0),
        0.0001 ether,   // Layer  1
        0.0002 ether,   // Layer  2
        0.0005 ether,   // Layer  3
        0.001  ether,   // Layer  4
        0.002  ether,   // Layer  5
        0.004  ether,   // Layer  6
        0.007  ether,   // Layer  7
        0.01   ether,   // Layer  8
        0.025  ether,   // Layer  9
        0.05   ether,   // Layer 10
        0.07   ether,   // Layer 11
        0.09   ether,   // Layer 12
        0.1    ether    // Layer 13
    ];

    // ─── Run ──────────────────────────────────────────────────────────────────

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // ── Step 1: SigilNFT ─────────────────────────────────────────────────
        SigilNFT sigilNFT = new SigilNFT();
        console.log("SigilNFT deployed at:", address(sigilNFT));

        // ── Step 2: ArcanusMathematica ───────────────────────────────────────
        ArcanusMathematica arcanus = new ArcanusMathematica();
        console.log("ArcanusMathematica deployed at:", address(arcanus));

        // ── Step 3: SpellPayment (WatcherGate address unknown yet) ───────────
        SpellPayment spellPayment = new SpellPayment(address(0));
        console.log("SpellPayment deployed at:", address(spellPayment));

        // ── Step 4: WatcherGate ──────────────────────────────────────────────
        WatcherGate watcherGate = new WatcherGate(address(spellPayment));
        console.log("WatcherGate deployed at:", address(watcherGate));

        // ── Step 5: GrimoireERC8004Registry ─────────────────────────────────
        GrimoireERC8004Registry registry = new GrimoireERC8004Registry();
        console.log("GrimoireERC8004Registry deployed at:", address(registry));

        // ── Step 6: GrimoireReputationRegistry ──────────────────────────────
        GrimoireReputationRegistry reputation = new GrimoireReputationRegistry();
        console.log("GrimoireReputationRegistry deployed at:", address(reputation));

        // ── Step 7: Wire SpellPayment → WatcherGate ──────────────────────────
        spellPayment.setWatcherGate(address(watcherGate));

        // ── Step 8: Wire WatcherGate → ERC-8004 Registry ─────────────────────
        watcherGate.setERC8004Registry(address(registry));

        // ── Step 9: Wire ArcanusMathematica → WatcherGate ────────────────────
        arcanus.setWatcherGate(address(watcherGate));

        // ── Step 10: Configure all 13 layers ─────────────────────────────────
        for (uint8 i = 1; i <= 13; i++) {
            AuthMode mode;
            address  sigil;

            if (i <= 3) {
                mode  = AuthMode.PAYMENT_ONLY;
                sigil = address(0);
            } else if (i <= 12) {
                mode  = AuthMode.SIGIL_ONLY;
                sigil = address(sigilNFT);
            } else {
                // Layer 13: DUAL_AUTH (forced by WatcherGate)
                mode  = AuthMode.DUAL_AUTH;
                sigil = address(sigilNFT);
            }

            // Deterministic encoded key from layer index
            bytes32 encodedKey = keccak256(abi.encodePacked("LAYER_", i, "_ENOCHIAN_KEY"));

            watcherGate.configureLayer(
                i,
                LAYER_PRICES[i],
                1 days,
                mode,
                sigil,
                encodedKey
            );
        }

        // ── Step 11: Activate layer 1 only ───────────────────────────────────
        watcherGate.activateLayer(1);

        // ── Step 12: Register deployer as agent in ERC-8004 registry ─────────
        registry.registerAgent(deployer, "ipfs://PLACEHOLDER_CID");
        console.log("Deployer registered as agent:", deployer);

        // ── Step 13: Register deployer as verified agent in WatcherGate ──────
        watcherGate.registerAgent(deployer);

        vm.stopBroadcast();

        // ── Step 14: Print summary ────────────────────────────────────────────
        console.log("\n══════════════════════════════════════════════════");
        console.log("  DEPLOYMENT COMPLETE — Base Mainnet (8453)");
        console.log("══════════════════════════════════════════════════");
        console.log("SigilNFT:                  ", address(sigilNFT));
        console.log("ArcanusMathematica:        ", address(arcanus));
        console.log("SpellPayment:              ", address(spellPayment));
        console.log("WatcherGate:               ", address(watcherGate));
        console.log("GrimoireERC8004Registry:   ", address(registry));
        console.log("GrimoireReputationRegistry:", address(reputation));
        console.log("Deployer:                  ", deployer);
        console.log("══════════════════════════════════════════════════");
        console.log("\nNext steps:");
        console.log("  1. Upload agentcard.json to IPFS");
        console.log("  2. Call registry.setAgentURI(1, 'ipfs://<REAL_CID>')");
        console.log("  3. Update .env with deployed addresses");
        console.log("  4. Run: forge script script/Verify.s.sol --rpc-url base");
    }
}
