// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Deploy
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry deployment script for the full WatcherTech Blockchain Grimoire suite.
 *
 * Deployment order (dependency-respecting):
 *   Step 1:  Deploy SigilNFT
 *   Step 2:  Deploy Level13SigilNFT
 *   Step 3:  Deploy ArcanusMathematica
 *   Step 4:  Deploy SpellPayment(address(0)) — WatcherGate address wired in Step 9
 *   Step 5:  Deploy WatcherGate(spellPaymentAddress)
 *   Step 6:  Deploy MuWatcherGate(level13SigilNFT, address(0), treasury)
 *   Step 7:  Deploy GrimoireERC8004Registry
 *   Step 8:  Deploy GrimoireReputationRegistry
 *   Step 9:  Deploy AtlanteanDefenseVault(USDC)
 *
 * Post-deploy wiring:
 *   Step 10: SpellPayment.setWatcherGate(watcherGate)
 *   Step 11: WatcherGate.setERC8004Registry(registry)
 *   Step 12: ArcanusMathematica.setWatcherGate(watcherGate)
 *   Step 13: WatcherGate.configureLayer(1..13) with SigilNFT address
 *   Step 14: WatcherGate.activateLayer(1) — first layer open
 *   Step 15: GrimoireERC8004Registry.registerAgent(deployer, "ipfs://PLACEHOLDER_CID")
 *   Step 16: WatcherGate.registerAgent(deployer)
 *   Step 17: console.log all deployed addresses
 *
 * Usage:
 *   forge script script/Deploy.s.sol --rpc-url base --broadcast --verify -vvvv
 */

import {Script, console} from "forge-std/Script.sol";

import {SpellPayment}               from "../06_Contracts/SpellPayment.sol";
import {SigilNFT}                   from "../06_Contracts/SigilNFT.sol";
import {Level13SigilNFT}            from "../06_Contracts/Level13SigilNFT.sol";
import {WatcherGate, AuthMode}      from "../06_Contracts/WatcherGate.sol";
import {MuWatcherGate}              from "../06_Contracts/MuWatcherGate.sol";
import {ArcanusMathematica}         from "../06_Contracts/ArcanusMathematica.sol";
import {AtlanteanDefenseVault}      from "../06_Contracts/AtlanteanDefenseVault.sol";
import {IERC20}                     from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

        // ── Step 2: Level13SigilNFT ──────────────────────────────────────────
        Level13SigilNFT level13Sigil = new Level13SigilNFT();
        console.log("Level13SigilNFT deployed at:", address(level13Sigil));

        // ── Step 3: ArcanusMathematica ───────────────────────────────────────
        ArcanusMathematica arcanus = new ArcanusMathematica();
        console.log("ArcanusMathematica deployed at:", address(arcanus));

        // ── Step 4: SpellPayment (WatcherGate address unknown yet) ───────────
        SpellPayment spellPayment = new SpellPayment(address(0));
        console.log("SpellPayment deployed at:", address(spellPayment));

        // ── Step 5: WatcherGate ──────────────────────────────────────────────
        WatcherGate watcherGate = new WatcherGate(address(spellPayment));
        console.log("WatcherGate deployed at:", address(watcherGate));

        // ── Step 6: MuWatcherGate ────────────────────────────────────────────
        // Treasury = deployer for initial setup; update via updateAddresses post-deploy
        MuWatcherGate muGate = new MuWatcherGate(
            address(level13Sigil),
            address(0),   // Superfluid CFAv1 — set post-deploy when known
            deployer      // Treasury (deployer initially)
        );
        console.log("MuWatcherGate deployed at:", address(muGate));

        // ── Step 7: GrimoireERC8004Registry ─────────────────────────────────
        GrimoireERC8004Registry registry = new GrimoireERC8004Registry();
        console.log("GrimoireERC8004Registry deployed at:", address(registry));

        // ── Step 8: GrimoireReputationRegistry ──────────────────────────────
        GrimoireReputationRegistry reputation = new GrimoireReputationRegistry();
        console.log("GrimoireReputationRegistry deployed at:", address(reputation));

        // ── Step 9: AtlanteanDefenseVault ────────────────────────────────────
        // USDC on Base mainnet: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
        // On testnet, replace with the appropriate mock USDC address.
        address usdcBase = vm.envOr("USDC_ADDRESS", address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913));
        AtlanteanDefenseVault vault = new AtlanteanDefenseVault(IERC20(usdcBase));
        console.log("AtlanteanDefenseVault deployed at:", address(vault));

        // ── Step 10: Wire SpellPayment → WatcherGate ─────────────────────────
        spellPayment.setWatcherGate(address(watcherGate));

        // ── Step 11: Wire WatcherGate → ERC-8004 Registry ────────────────────
        watcherGate.setERC8004Registry(address(registry));

        // ── Step 12: Wire ArcanusMathematica → WatcherGate ───────────────────
        arcanus.setWatcherGate(address(watcherGate));

        // ── Step 13: Configure all 13 layers ──────────────────────────────────
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

        // ── Step 14: Activate layer 1 only ───────────────────────────────────
        watcherGate.activateLayer(1);

        // ── Step 15: Register deployer as agent in ERC-8004 registry ─────────
        registry.registerAgent(deployer, "ipfs://PLACEHOLDER_CID");
        console.log("Deployer registered as agent:", deployer);

        // ── Step 16: Register deployer as verified agent in WatcherGate ──────
        watcherGate.registerAgent(deployer);

        vm.stopBroadcast();

        // ── Step 17: Print summary ────────────────────────────────────────────
        console.log("\n══════════════════════════════════════════════════");
        console.log("  DEPLOYMENT COMPLETE — Base Mainnet (8453)");
        console.log("══════════════════════════════════════════════════");
        console.log("SigilNFT:                  ", address(sigilNFT));
        console.log("Level13SigilNFT:           ", address(level13Sigil));
        console.log("ArcanusMathematica:        ", address(arcanus));
        console.log("SpellPayment:              ", address(spellPayment));
        console.log("WatcherGate:               ", address(watcherGate));
        console.log("MuWatcherGate:             ", address(muGate));
        console.log("AtlanteanDefenseVault:     ", address(vault));
        console.log("GrimoireERC8004Registry:   ", address(registry));
        console.log("GrimoireReputationRegistry:", address(reputation));
        console.log("Deployer:                  ", deployer);
        console.log("══════════════════════════════════════════════════");
        console.log("\nNext steps:");
        console.log("  1. Upload agentcard.json to IPFS");
        console.log("  2. Call registry.setAgentURI(1, 'ipfs://<REAL_CID>')");
        console.log("  3. Call muGate.updateAddresses(0, <SUPERFLUID_FORWARDER>, <TREASURY>)");
        console.log("  4. Update .env with deployed addresses");
        console.log("  5. Run: forge script script/Verify.s.sol --rpc-url base");
    }
}
