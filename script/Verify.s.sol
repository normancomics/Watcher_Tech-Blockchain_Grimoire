// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Verify
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry script to verify all deployed WatcherTech contracts on Basescan.
 *
 * Usage (after Deploy.s.sol has been run):
 *   forge script script/Verify.s.sol --rpc-url base -vvvv
 *
 * Or verify each contract individually:
 *   forge verify-contract <ADDRESS> SpellPayment \
 *     --chain 8453 \
 *     --etherscan-api-key $BASESCAN_API_KEY \
 *     --constructor-args $(cast abi-encode "constructor(address)" 0x0000...0000)
 */

import {Script, console} from "forge-std/Script.sol";

contract Verify is Script {

    function run() external view {
        // ─── Read addresses from environment ─────────────────────────────────
        address sigilNFT      = vm.envAddress("SIGIL_NFT_ADDRESS");
        address arcanus       = vm.envAddress("ARCANUS_MATHEMATICA_ADDRESS");
        address spellPay      = vm.envAddress("SPELL_PAYMENT_ADDRESS");
        address watcherGate   = vm.envAddress("WATCHER_GATE_ADDRESS");
        address erc8004Reg    = vm.envAddress("ERC8004_REGISTRY_ADDRESS");
        address reputationReg = vm.envAddress("REPUTATION_REGISTRY_ADDRESS");
        address grimReg       = vm.envAddress("GRIMOIRE_REGISTRY_ADDRESS");
        address agentAtt      = vm.envAddress("AGENT_ATTUNEMENT_ADDRESS");
        address swarm         = vm.envAddress("SOVEREIGN_SWARM_ADDRESS");
        address knowledgeNFT  = vm.envAddress("KNOWLEDGE_NFT_ADDRESS");
        address ipfsReg       = vm.envAddress("IPFS_CONTENT_REGISTRY_ADDRESS");

        // ─── Print verification commands ─────────────────────────────────────
        console.log("Run the following forge verify-contract commands:\n");

        console.log("# SigilNFT (no constructor args)");
        console.log(
            "forge verify-contract", sigilNFT,
            "SigilNFT --chain 8453 --etherscan-api-key $BASESCAN_API_KEY"
        );

        console.log("\n# ArcanusMathematica (no constructor args)");
        console.log(
            "forge verify-contract", arcanus,
            "ArcanusMathematica --chain 8453 --etherscan-api-key $BASESCAN_API_KEY"
        );

        console.log("\n# SpellPayment (constructor arg: address watcherGate)");
        console.log(
            "forge verify-contract", spellPay,
            "SpellPayment --chain 8453 --etherscan-api-key $BASESCAN_API_KEY",
            string(abi.encodePacked(
                "--constructor-args $(cast abi-encode 'constructor(address)' ",
                vm.toString(watcherGate), ")"
            ))
        );

        console.log("\n# WatcherGate (constructor arg: address spellPayment)");
        console.log(
            "forge verify-contract", watcherGate,
            "WatcherGate --chain 8453 --etherscan-api-key $BASESCAN_API_KEY",
            string(abi.encodePacked(
                "--constructor-args $(cast abi-encode 'constructor(address)' ",
                vm.toString(spellPay), ")"
            ))
        );

        console.log("\n# GrimoireERC8004Registry (no constructor args)");
        console.log(
            "forge verify-contract", erc8004Reg,
            "GrimoireERC8004Registry --chain 8453 --etherscan-api-key $BASESCAN_API_KEY"
        );

        console.log("\n# GrimoireReputationRegistry (no constructor args)");
        console.log(
            "forge verify-contract", reputationReg,
            "GrimoireReputationRegistry --chain 8453 --etherscan-api-key $BASESCAN_API_KEY"
        );

        console.log("\n# GrimoireRegistry (no constructor args)");
        console.log(
            "forge verify-contract", grimReg,
            "GrimoireRegistry --chain 8453 --etherscan-api-key $BASESCAN_API_KEY"
        );

        console.log("\n# AgentAttunement (constructor arg: address erc8004Registry)");
        console.log(
            "forge verify-contract", agentAtt,
            "AgentAttunement --chain 8453 --etherscan-api-key $BASESCAN_API_KEY",
            string(abi.encodePacked(
                "--constructor-args $(cast abi-encode 'constructor(address)' ",
                vm.toString(erc8004Reg), ")"
            ))
        );

        console.log("\n# SovereignSwarm (constructor arg: address agentAttunement)");
        console.log(
            "forge verify-contract", swarm,
            "SovereignSwarm --chain 8453 --etherscan-api-key $BASESCAN_API_KEY",
            string(abi.encodePacked(
                "--constructor-args $(cast abi-encode 'constructor(address)' ",
                vm.toString(agentAtt), ")"
            ))
        );

        console.log("\n# KnowledgeNFT (constructor arg: address grimoireRegistry)");
        console.log(
            "forge verify-contract", knowledgeNFT,
            "KnowledgeNFT --chain 8453 --etherscan-api-key $BASESCAN_API_KEY",
            string(abi.encodePacked(
                "--constructor-args $(cast abi-encode 'constructor(address)' ",
                vm.toString(grimReg), ")"
            ))
        );

        console.log("\n# IPFSContentRegistry (no constructor args)");
        console.log(
            "forge verify-contract", ipfsReg,
            "IPFSContentRegistry --chain 8453 --etherscan-api-key $BASESCAN_API_KEY"
        );
    }
}
