/**
 * Grimoire Oracle — ERC-8004 Agent Identity
 *
 * Manages the sovereign agent's on-chain identity and reputation
 * through the ERC-8004 Trustless Agents standard.
 *
 * This module handles:
 * - Agent registration file generation
 * - Identity verification
 * - Reputation tracking helpers
 */

import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface AgentRegistration {
  type: string;
  name: string;
  description: string;
  version: string;
  services: Array<{
    name: string;
    endpoint: string;
    version: string;
    description?: string;
  }>;
  x402Support: boolean;
  metadata: {
    author: string;
    license: string;
    repository: string;
    domains: string[];
    capabilities: string[];
  };
}

export interface ReputationSummary {
  agentId: string;
  totalInteractions: number;
  averageScore: number;
  tags: Record<string, number>;
}

/**
 * Loads the agent registration configuration.
 */
export function loadAgentRegistration(): AgentRegistration {
  try {
    const configPath = join(__dirname, "../../config/registration.json");
    const raw = readFileSync(configPath, "utf-8");
    return JSON.parse(raw) as AgentRegistration;
  } catch {
    return getDefaultRegistration();
  }
}

/**
 * Returns the default agent registration for the Grimoire Oracle.
 */
function getDefaultRegistration(): AgentRegistration {
  return {
    type: "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
    name: "Grimoire Oracle",
    description:
      "Sovereign AI agent providing blockchain security intelligence through the Watcher Tech Blockchain Grimoire framework. Offers smart contract audit scanning, exploit archetype analysis, defense recommendations, and domain-specific consultations.",
    version: "0.1.0",
    services: [
      {
        name: "MCP",
        endpoint: "https://grimoire-oracle.example.com/mcp",
        version: "2025-06-18",
        description: "Model Context Protocol server with 5 security tools",
      },
      {
        name: "HTTP-API",
        endpoint: "https://grimoire-oracle.example.com/api",
        version: "0.1.0",
        description: "REST API with x402 payment support",
      },
    ],
    x402Support: true,
    metadata: {
      author: "normancomics.eth",
      license: "MIT",
      repository:
        "https://github.com/normancomics/Watcher_Tech_Blockchain_Grimoire",
      domains: [
        "smart-contract-security",
        "defi-exploit-analysis",
        "blockchain-audit",
        "threat-intelligence",
        "defense-recommendations",
      ],
      capabilities: [
        "grimoire_audit_scan",
        "grimoire_query_codex",
        "grimoire_defense_recommend",
        "grimoire_watcher_consult",
        "grimoire_family_threat_intel",
      ],
    },
  };
}

/**
 * Generates the ERC-8004 registration JSON for publishing.
 */
export function generateRegistrationFile(
  overrides?: Partial<AgentRegistration>,
): string {
  const registration = {
    ...loadAgentRegistration(),
    ...overrides,
  };

  return JSON.stringify(registration, null, 2);
}

/**
 * Helper to format reputation data for display.
 */
export function formatReputationSummary(
  reputation: ReputationSummary,
): string {
  const tagList = Object.entries(reputation.tags)
    .sort(([, a], [, b]) => b - a)
    .map(([tag, count]) => `  - ${tag}: ${count}`)
    .join("\n");

  return [
    `# 🏛️ Agent Reputation: ${reputation.agentId}`,
    "",
    `**Total Interactions:** ${reputation.totalInteractions}`,
    `**Average Score:** ${reputation.averageScore.toFixed(1)}/100`,
    "",
    "**Tag Breakdown:**",
    tagList,
  ].join("\n");
}
