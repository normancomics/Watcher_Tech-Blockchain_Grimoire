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
 *   Step 7:  Deploy GrimoireRegistry    (on-chain knowledge registry)
 *   Step 8:  Deploy AgentAttunement     (ERC-8004 agent bonding)
 *   Step 9:  Deploy SovereignSwarm      (multi-agent coordination)
 *   Step 10: Deploy KnowledgeNFT        (ERC-721 knowledge tokens)
 *   Step 11: Deploy IPFSContentRegistry (IPFS/Arweave proof-of-authority)
 *
 * Post-deploy wiring:
 *   Step 12: SpellPayment.setWatcherGate(watcherGate)
 *   Step 13: WatcherGate.setERC8004Registry(registry)
 *   Step 14: ArcanusMathematica.setWatcherGate(watcherGate)
 *   Step 15: WatcherGate.configureLayer(1..13) with SigilNFT address
 *   Step 16: WatcherGate.activateLayer(1) — first layer open
 *   Step 17: GrimoireERC8004Registry.registerAgent(deployer, "ipfs://PLACEHOLDER_CID")
 *   Step 18: WatcherGate.registerAgent(deployer)
 *   Step 19: console.log all deployed addresses
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
import {GrimoireRegistry}           from "../06_Contracts/GrimoireRegistry.sol";
import {AgentAttunement}            from "../06_Contracts/AgentAttunement.sol";
import {SovereignSwarm}             from "../06_Contracts/SovereignSwarm.sol";
import {KnowledgeNFT}               from "../06_Contracts/KnowledgeNFT.sol";
import {IPFSContentRegistry}        from "../06_Contracts/IPFSContentRegistry.sol";

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
        GrimoireERC8004Registry erc8004Registry = new GrimoireERC8004Registry();
        console.log("GrimoireERC8004Registry deployed at:", address(erc8004Registry));

        // ── Step 6: GrimoireReputationRegistry ──────────────────────────────
        GrimoireReputationRegistry reputation = new GrimoireReputationRegistry();
        console.log("GrimoireReputationRegistry deployed at:", address(reputation));

        // ── Step 7: GrimoireRegistry (on-chain knowledge layer) ──────────────
        GrimoireRegistry grimoireRegistry = new GrimoireRegistry();
        console.log("GrimoireRegistry deployed at:", address(grimoireRegistry));

        // ── Step 8: AgentAttunement (ERC-8004 bonding + reputation) ──────────
        AgentAttunement agentAttunement = new AgentAttunement(address(erc8004Registry));
        console.log("AgentAttunement deployed at:", address(agentAttunement));

        // ── Step 9: SovereignSwarm (multi-agent task coordination) ────────────
        SovereignSwarm sovereignSwarm = new SovereignSwarm(address(agentAttunement));
        console.log("SovereignSwarm deployed at:", address(sovereignSwarm));

        // ── Step 10: KnowledgeNFT (ERC-721 knowledge tokens) ─────────────────
        KnowledgeNFT knowledgeNFT = new KnowledgeNFT(address(grimoireRegistry));
        console.log("KnowledgeNFT deployed at:", address(knowledgeNFT));

        // ── Step 11: IPFSContentRegistry (proof-of-authority IPFS anchor) ─────
        IPFSContentRegistry ipfsRegistry = new IPFSContentRegistry();
        console.log("IPFSContentRegistry deployed at:", address(ipfsRegistry));

        // ── Step 12: Wire SpellPayment → WatcherGate ─────────────────────────
        spellPayment.setWatcherGate(address(watcherGate));

        // ── Step 13: Wire WatcherGate → ERC-8004 Registry ────────────────────
        watcherGate.setERC8004Registry(address(erc8004Registry));

        // ── Step 14: Wire ArcanusMathematica → WatcherGate ───────────────────
        arcanus.setWatcherGate(address(watcherGate));

        // ── Step 15: Configure all 13 layers ──────────────────────────────────
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

        // ── Step 16: Activate layer 1 only ────────────────────────────────────
        watcherGate.activateLayer(1);

        // ── Step 17: Register deployer as agent in ERC-8004 registry ──────────
        erc8004Registry.registerAgent(deployer, "ipfs://PLACEHOLDER_CID");
        console.log("Deployer registered as agent:", deployer);

        // ── Step 18: Register deployer as verified agent in WatcherGate ───────
        watcherGate.registerAgent(deployer);

        vm.stopBroadcast();

        // ── Step 19: Print summary ─────────────────────────────────────────────
        console.log("\n══════════════════════════════════════════════════════════");
        console.log("  DEPLOYMENT COMPLETE — Watcher Tech Blockchain Grimoire");
        console.log("══════════════════════════════════════════════════════════");
        console.log("");
        console.log("── Core Gate Infrastructure ──");
        console.log("SigilNFT:                  ", address(sigilNFT));
        console.log("ArcanusMathematica:        ", address(arcanus));
        console.log("SpellPayment:              ", address(spellPayment));
        console.log("WatcherGate:               ", address(watcherGate));
        console.log("");
        console.log("── Agent Identity & Registry ──");
        console.log("GrimoireERC8004Registry:   ", address(erc8004Registry));
        console.log("GrimoireReputationRegistry:", address(reputation));
        console.log("AgentAttunement:           ", address(agentAttunement));
        console.log("SovereignSwarm:            ", address(sovereignSwarm));
        console.log("");
        console.log("── Knowledge & Storage ──");
        console.log("GrimoireRegistry:          ", address(grimoireRegistry));
        console.log("KnowledgeNFT:              ", address(knowledgeNFT));
        console.log("IPFSContentRegistry:       ", address(ipfsRegistry));
        console.log("");
        console.log("Deployer:                  ", deployer);
        console.log("══════════════════════════════════════════════════════════");
        console.log("\nNext steps:");
        console.log("  1. Upload agentcard.json to IPFS");
        console.log("  2. Call erc8004Registry.setAgentURI(1, 'ipfs://<REAL_CID>')");
        console.log("  3. Update .env with deployed addresses");
        console.log("  4. Run: forge script script/Verify.s.sol --rpc-url base");
        console.log("  5. Register first Grimoire entries via GrimoireRegistry.submitEntry()");
        console.log("  6. Register IPFS content via IPFSContentRegistry.registerContent()");
    }
}
