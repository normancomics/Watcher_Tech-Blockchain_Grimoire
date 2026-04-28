#!/usr/bin/env node

/**
 * Grimoire Oracle — MCP Server (stdio transport)
 *
 * A sovereign MCP server that exposes 5 blockchain security intelligence
 * tools powered by the Watcher Tech Blockchain Grimoire knowledge base.
 *
 * Every tool call runs inside an isolated sandbox with:
 * - Per-tool security policies (input limits, output caps, timeouts)
 * - Frozen knowledge base snapshots (no shared mutable state)
 * - Input sanitization (null bytes, control chars, length enforcement)
 * - Error containment (tool failures never crash the server)
 * - Full audit trail (every execution logged)
 *
 * Usage:
 *   npx grimoire-oracle              # Run as MCP server (stdio)
 *   GRIMOIRE_REPO_PATH=/path/to/repo npx grimoire-oracle
 *
 * Tools:
 *   grimoire_audit_scan         — Scan Solidity code for 7 exploit archetypes
 *   grimoire_query_codex        — RAG query against the Grimoire knowledge base
 *   grimoire_defense_recommend  — Get defense recommendations for vulnerabilities
 *   grimoire_watcher_consult    — Consult a Watcher for domain expertise
 *   grimoire_family_threat_intel — Get threat intel from the 13 Families framework
 *   grimoire_quantum_entropy    — Generate post-quantum secure entropy proofs
 *   grimoire_rag_synthesis      — Multi-document RAG synthesis with citations
 *   grimoire_sovereign_invoke   — Full autonomous agent pipeline (all tools chained)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { loadKnowledgeBase } from "./knowledge/loader.js";
import { auditScan, formatAuditReport } from "./tools/audit-scan.js";
import { queryCodex } from "./tools/query-codex.js";
import { getDefenseRecommendation } from "./tools/defense-recommend.js";
import { consultWatcher } from "./tools/watcher-consult.js";
import { getFamilyThreatIntel } from "./tools/family-threat-intel.js";
import { generateQuantumEntropy } from "./tools/quantum-entropy.js";
import { synthesizeKnowledge } from "./tools/rag-synthesis.js";
import { sovereignInvoke } from "./tools/sovereign-invoke.js";
import {
  EXPLOIT_ARCHETYPES,
  WATCHER_DOMAINS,
  FAMILY_PROFILES,
  DEFENSE_PARADIGMS,
} from "./knowledge/archetypes.js";

import { sandboxExecute, getFrozenKnowledge } from "./sandbox/sandbox.js";
import { getAuditStats } from "./sandbox/audit-log.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── Knowledge Base Initialization ──────────────────────────────────

// Resolve the repo root (parent of mcp-server/)
const REPO_ROOT =
  process.env["GRIMOIRE_REPO_PATH"] ?? join(__dirname, "../..");

/**
 * Returns a frozen, immutable snapshot of the knowledge base.
 * Safe to share across concurrent sandbox executions.
 */
function getKnowledge() {
  return getFrozenKnowledge(() => loadKnowledgeBase(REPO_ROOT));
}

// ─── MCP Server Setup ───────────────────────────────────────────────

const server = new McpServer({
  name: "grimoire-oracle",
  version: "0.1.0",
});

// ─── Tool 1: Audit Scan ─────────────────────────────────────────────

server.tool(
  "grimoire_audit_scan",
  "Scan Solidity smart contract source code for the 7 exploit archetypes defined in the Watcher Tech Blockchain Grimoire. Detects patterns matching Reentrancy (Recursive Invocation), MEV (Gatekeeper's Reordering), Flash Loans (Instant Conjuration), Vampire Attacks (Luring Sacrificial Flow), Bridge Exploits (Portal Invocation), ZK Misuse (Cloaked Initiation), and Supply Chain Attacks (Artificer's Trojan).",
  {
    sourceCode: z
      .string()
      .describe(
        "The Solidity smart contract source code to audit",
      ),
    contractName: z
      .string()
      .optional()
      .describe("Optional name of the contract being audited"),
  },
  async ({ sourceCode, contractName }) => {
    const result = await sandboxExecute(
      "grimoire_audit_scan",
      { sourceCode, contractName },
      (inputs) => {
        const report = auditScan(
          inputs["sourceCode"] as string,
          inputs["contractName"] as string | undefined,
        );
        return formatAuditReport(report);
      },
      { transport: "stdio" },
    );

    return {
      content: [
        {
          type: "text" as const,
          text: result.output,
        },
      ],
    };
  },
);

// ─── Tool 2: Query Codex ────────────────────────────────────────────

server.tool(
  "grimoire_query_codex",
  "Query the Watcher Tech Blockchain Grimoire knowledge base. Searches across 11,000+ lines of documentation covering blockchain security, DeFi exploits, Watcher hierarchies, the 7 Sages, 13 Families framework, EVM opcode mappings, portal mechanics, and defensive paradigms. Returns relevant passages with sources.",
  {
    query: z
      .string()
      .describe(
        "Search query — use keywords related to blockchain security, DeFi, exploits, watchers, sages, families, opcodes, etc.",
      ),
    maxResults: z
      .number()
      .min(1)
      .max(20)
      .optional()
      .describe("Maximum number of results to return (default: 5)"),
    filterTags: z
      .array(z.string())
      .optional()
      .describe(
        "Optional tags to filter results: watcher, sage, families, reentrancy, mev, flash-loan, bridge, zk, liquidity, evm, defense, sigil, codex, core, lineage",
      ),
  },
  async ({ query, maxResults, filterTags }) => {
    const knowledge = getKnowledge();

    const result = await sandboxExecute(
      "grimoire_query_codex",
      { query, maxResults, filterTags },
      (inputs) => {
        const queryResult = queryCodex(
          [...knowledge],  // Pass a copy so tool can't affect the frozen original
          inputs["query"] as string,
          {
            maxResults: inputs["maxResults"] as number | undefined,
            filterTags: inputs["filterTags"] as string[] | undefined,
          },
        );
        return queryResult.response;
      },
      { knowledge, transport: "stdio" },
    );

    return {
      content: [
        {
          type: "text" as const,
          text: result.output,
        },
      ],
    };
  },
);

// ─── Tool 3: Defense Recommend ──────────────────────────────────────

server.tool(
  "grimoire_defense_recommend",
  "Get defense recommendations from the 7 Atlantean Defensive Paradigms. Provide a vulnerability type (e.g., 'reentrancy', 'mev', 'flash loan', 'bridge exploit', 'zk', 'supply chain', 'liquidity drain') and receive detailed mitigation strategies, implementation steps, and recommended tools.",
  {
    vulnerability: z
      .string()
      .describe(
        "The vulnerability type or exploit description to get defense recommendations for. Examples: 'reentrancy', 'mev frontrunning', 'flash loan attack', 'cross-chain bridge', 'zero knowledge proof', 'supply chain backdoor', 'vampire liquidity drain'",
      ),
  },
  async ({ vulnerability }) => {
    const result = await sandboxExecute(
      "grimoire_defense_recommend",
      { vulnerability },
      (inputs) => {
        const rec = getDefenseRecommendation(
          inputs["vulnerability"] as string,
        );
        return rec.fullResponse;
      },
      { transport: "stdio" },
    );

    return {
      content: [
        {
          type: "text" as const,
          text: result.output,
        },
      ],
    };
  },
);

// ─── Tool 4: Watcher Consult ────────────────────────────────────────

server.tool(
  "grimoire_watcher_consult",
  "Consult one of the 8 Watcher specialist agents for domain-specific blockchain security expertise. Each Watcher has a unique domain: Azazel (cybersecurity), Semyaza (contract analysis), Armaros (cryptography), Baraqel (MEV/timing), Kokabiel (EVM/gas), Tamiel (on-chain analytics), Ramiel (recovery/forensics), Daniel (advanced research).",
  {
    watcher: z
      .string()
      .describe(
        "The Watcher to consult — by name (azazel, semyaza, armaros, baraqel, kokabiel, tamiel, ramiel, daniel) or by domain keyword (security, contract, cryptography, mev, gas, analytics, recovery, research)",
      ),
    question: z
      .string()
      .describe(
        "The question or topic to consult the Watcher about",
      ),
  },
  async ({ watcher, question }) => {
    const knowledge = getKnowledge();

    const result = await sandboxExecute(
      "grimoire_watcher_consult",
      { watcher, question },
      (inputs) => {
        const consultation = consultWatcher(
          inputs["watcher"] as string,
          inputs["question"] as string,
          [...knowledge],  // Copy for isolation
        );
        return consultation.analysis;
      },
      { knowledge, transport: "stdio" },
    );

    return {
      content: [
        {
          type: "text" as const,
          text: result.output,
        },
      ],
    };
  },
);

// ─── Tool 5: Family Threat Intel ────────────────────────────────────

server.tool(
  "grimoire_family_threat_intel",
  "Get threat intelligence from the 13 Family archetype framework. Each Family represents a distinct threat domain with specific attack vectors and defenses. Query by family name (Rothschild, Rockefeller, etc.), domain (banking, energy, etc.), or exploit type (mev, reentrancy, flash loan, etc.).",
  {
    query: z
      .string()
      .describe(
        "The family name, domain, or exploit type to get threat intelligence for. Examples: 'rothschild', 'banking', 'mev', 'bundy', 'reentrancy', 'dupont', 'flash loan'",
      ),
  },
  async ({ query }) => {
    const result = await sandboxExecute(
      "grimoire_family_threat_intel",
      { query },
      (inputs) => {
        const intel = getFamilyThreatIntel(
          inputs["query"] as string,
        );
        return intel.fullResponse;
      },
      { transport: "stdio" },
    );

    return {
      content: [
        {
          type: "text" as const,
          text: result.output,
        },
      ],
    };
  },
);

// ─── Tool 6: Quantum Entropy ─────────────────────────────────────────

server.tool(
  "grimoire_quantum_entropy",
  "Generate post-quantum secure entropy and verifiable randomness proofs using the Enochian/Kabbalistic mixing framework. Outputs are formatted for use with CRYSTALS-Kyber, CRYSTALS-Dilithium, and SPHINCS+ post-quantum algorithms. Supports optional commit-reveal pairs for on-chain randomness commitments on Base chain.",
  {
    bytes: z
      .number()
      .min(1)
      .max(4096)
      .optional()
      .describe("Number of entropy bytes to generate (1–4096, default: 32)"),
    encoding: z
      .enum(["hex", "base64", "binary-description"])
      .optional()
      .describe("Output encoding format (default: hex)"),
    planet: z
      .enum(["saturn", "jupiter", "mars", "sun", "venus", "mercury", "moon"])
      .optional()
      .describe("Planetary kamea mixing matrix — saturn=Kyber, jupiter=Dilithium, mars=SPHINCS+"),
    angel: z
      .string()
      .optional()
      .describe("Enochian angel persona (uriel, raphael, michael, gabriel, saraqael, remiel, raguel)"),
    commitReveal: z
      .boolean()
      .optional()
      .describe("If true, generate a commit-reveal pair for on-chain randomness commitment"),
    useCase: z
      .string()
      .optional()
      .describe("Describe the intended use case (informational, influences mixing label)"),
  },
  async ({ bytes, encoding, planet, angel, commitReveal, useCase }) => {
    const result = await sandboxExecute(
      "grimoire_quantum_entropy",
      { bytes, encoding, planet, angel, commitReveal, useCase },
      (inputs) => {
        const entropy = generateQuantumEntropy({
          bytes:       inputs["bytes"] as number | undefined,
          encoding:    inputs["encoding"] as "hex" | "base64" | "binary-description" | undefined,
          planet:      inputs["planet"] as "saturn" | "jupiter" | "mars" | "sun" | "venus" | "mercury" | "moon" | undefined,
          angel:       inputs["angel"] as string | undefined,
          commitReveal: inputs["commitReveal"] as boolean | undefined,
          useCase:     inputs["useCase"] as string | undefined,
        });
        return entropy.fullReport;
      },
      { transport: "stdio" },
    );

    return {
      content: [
        {
          type: "text" as const,
          text: result.output,
        },
      ],
    };
  },
);

// ─── Tool 7: RAG Synthesis ───────────────────────────────────────────

server.tool(
  "grimoire_rag_synthesis",
  "Perform multi-document RAG synthesis over the Watcher Tech Blockchain Grimoire knowledge base. Unlike grimoire_query_codex (which returns raw search results), this tool synthesizes multiple sources into a coherent cited narrative — activating the Seven Pillars of Wisdom framework. Supports sub-queries for multi-angle synthesis and cross-reference detection between sources.",
  {
    query: z
      .string()
      .describe("Primary synthesis question or topic"),
    subQueries: z
      .array(z.string())
      .max(3)
      .optional()
      .describe("Optional secondary queries for multi-angle synthesis (max 3)"),
    maxSources: z
      .number()
      .min(1)
      .max(20)
      .optional()
      .describe("Maximum number of sources to cite (default: 8)"),
    filterTags: z
      .array(z.string())
      .optional()
      .describe("Narrow the corpus by tags: watcher, sage, families, reentrancy, mev, flash-loan, bridge, zk, defense, sigil, codex"),
    crossReference: z
      .boolean()
      .optional()
      .describe("If true, detect and report cross-references between sources (default: true)"),
    depth: z
      .enum(["brief", "standard", "deep"])
      .optional()
      .describe("Synthesis depth: brief=3 sources, standard=6, deep=all (default: standard)"),
  },
  async ({ query, subQueries, maxSources, filterTags, crossReference, depth }) => {
    const knowledge = getKnowledge();

    const result = await sandboxExecute(
      "grimoire_rag_synthesis",
      { query, subQueries, maxSources, filterTags, crossReference, depth },
      (inputs) => {
        const synthesis = synthesizeKnowledge([...knowledge], {
          query:          inputs["query"] as string,
          subQueries:     inputs["subQueries"] as string[] | undefined,
          maxSources:     inputs["maxSources"] as number | undefined,
          filterTags:     inputs["filterTags"] as string[] | undefined,
          crossReference: inputs["crossReference"] as boolean | undefined,
          depth:          inputs["depth"] as "brief" | "standard" | "deep" | undefined,
        });
        return synthesis.fullResponse;
      },
      { knowledge, transport: "stdio" },
    );

    return {
      content: [
        {
          type: "text" as const,
          text: result.output,
        },
      ],
    };
  },
);

// ─── Tool 8: Sovereign Invoke ────────────────────────────────────────

server.tool(
  "grimoire_sovereign_invoke",
  "Execute a full autonomous sovereign agent invocation — multi-step pipeline that orchestrates audit scan, RAG synthesis, Watcher consultation, and defense recommendation into a single sovereign judgment report. Use this for comprehensive security assessments, threat analyses, or deep knowledge synthesis. The Archon convenes all relevant Watcher domains and delivers a final decree. WARNING: This is the most expensive tool (1.00 USD) — it runs 4–8 internal tool steps.",
  {
    objective: z
      .string()
      .describe("High-level objective for the sovereign agent. Examples: 'Audit this contract for reentrancy', 'Analyze the threat of flash loan governance attacks', 'Defend against MEV frontrunning'"),
    contractSource: z
      .string()
      .optional()
      .describe("Optional Solidity source code (triggers CONTRACT_AUDIT pipeline if provided)"),
    contractName: z
      .string()
      .optional()
      .describe("Optional name of the contract (used in audit reports)"),
    objectiveType: z
      .enum(["CONTRACT_AUDIT", "THREAT_ANALYSIS", "DEFENSE_SYNTHESIS", "KNOWLEDGE_SYNTHESIS", "WATCHER_COUNCIL"])
      .optional()
      .describe("Override the inferred pipeline type. WATCHER_COUNCIL convenes all 8 Watchers."),
    maxSources: z
      .number()
      .min(1)
      .max(20)
      .optional()
      .describe("Maximum knowledge sources per retrieval step (default: 6)"),
  },
  async ({ objective, contractSource, contractName, objectiveType, maxSources }) => {
    const knowledge = getKnowledge();

    const result = await sandboxExecute(
      "grimoire_sovereign_invoke",
      { objective, contractSource, contractName, objectiveType, maxSources },
      (inputs) => {
        const invocation = sovereignInvoke(
          {
            objective:      inputs["objective"] as string,
            contractSource: inputs["contractSource"] as string | undefined,
            contractName:   inputs["contractName"] as string | undefined,
            objectiveType:  inputs["objectiveType"] as "CONTRACT_AUDIT" | "THREAT_ANALYSIS" | "DEFENSE_SYNTHESIS" | "KNOWLEDGE_SYNTHESIS" | "WATCHER_COUNCIL" | undefined,
            maxSources:     inputs["maxSources"] as number | undefined,
          },
          [...knowledge],
        );
        return invocation.fullReport;
      },
      { knowledge, transport: "stdio" },
    );

    return {
      content: [
        {
          type: "text" as const,
          text: result.output,
        },
      ],
    };
  },
);

// ─── Resources: Expose structured data ──────────────────────────────

server.resource(
  "archetypes",
  "grimoire://archetypes",
  async () => ({
    contents: [
      {
        uri: "grimoire://archetypes",
        mimeType: "application/json",
        text: JSON.stringify(EXPLOIT_ARCHETYPES, null, 2),
      },
    ],
  }),
);

server.resource(
  "watchers",
  "grimoire://watchers",
  async () => ({
    contents: [
      {
        uri: "grimoire://watchers",
        mimeType: "application/json",
        text: JSON.stringify(WATCHER_DOMAINS, null, 2),
      },
    ],
  }),
);

server.resource(
  "families",
  "grimoire://families",
  async () => ({
    contents: [
      {
        uri: "grimoire://families",
        mimeType: "application/json",
        text: JSON.stringify(FAMILY_PROFILES, null, 2),
      },
    ],
  }),
);

server.resource(
  "defenses",
  "grimoire://defenses",
  async () => ({
    contents: [
      {
        uri: "grimoire://defenses",
        mimeType: "application/json",
        text: JSON.stringify(DEFENSE_PARADIGMS, null, 2),
      },
    ],
  }),
);

// ─── Resource: Audit Stats ──────────────────────────────────────────

server.resource(
  "audit-stats",
  "grimoire://audit-stats",
  async () => ({
    contents: [
      {
        uri: "grimoire://audit-stats",
        mimeType: "application/json",
        text: JSON.stringify(getAuditStats(), null, 2),
      },
    ],
  }),
);

// ─── Start Server ───────────────────────────────────────────────────

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Log to stderr (stdout is used for MCP protocol)
  console.error("🔮 Grimoire Oracle MCP Server started");
  console.error(`📚 Knowledge base root: ${REPO_ROOT}`);
  console.error("⚡ Transport: stdio");
  console.error("🛡️  Sandbox: ENABLED — all tools run in isolated execution contexts");
  console.error("🛠️  Tools: grimoire_audit_scan, grimoire_query_codex, grimoire_defense_recommend, grimoire_watcher_consult, grimoire_family_threat_intel, grimoire_quantum_entropy, grimoire_rag_synthesis, grimoire_sovereign_invoke");
  console.error("📦 Resources: grimoire://archetypes, grimoire://watchers, grimoire://families, grimoire://defenses, grimoire://audit-stats");
}

main().catch((error: unknown) => {
  console.error("Fatal error starting Grimoire Oracle:", error);
  process.exit(1);
});
