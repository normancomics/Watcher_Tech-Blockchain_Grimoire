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
  console.error("🛠️  Tools: grimoire_audit_scan, grimoire_query_codex, grimoire_defense_recommend, grimoire_watcher_consult, grimoire_family_threat_intel");
  console.error("📦 Resources: grimoire://archetypes, grimoire://watchers, grimoire://families, grimoire://defenses, grimoire://audit-stats");
}

main().catch((error: unknown) => {
  console.error("Fatal error starting Grimoire Oracle:", error);
  process.exit(1);
});
