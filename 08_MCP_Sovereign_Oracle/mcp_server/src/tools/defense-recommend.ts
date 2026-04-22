/**
 * Grimoire Oracle — Defense Recommendation Tool
 *
 * Provides defense recommendations from the 7 Defensive Paradigms
 * based on vulnerability type or exploit archetype.
 */

import {
  EXPLOIT_ARCHETYPES,
  DEFENSE_PARADIGMS,
  type ExploitArchetype,
  type DefenseParadigm,
} from "../knowledge/archetypes.js";

export interface DefenseRecommendation {
  vulnerability: string;
  matchedArchetype: ExploitArchetype | null;
  paradigm: DefenseParadigm | null;
  fullResponse: string;
}

/**
 * Finds the best matching archetype for a vulnerability description.
 */
function matchArchetype(vulnerabilityQuery: string): ExploitArchetype | null {
  const query = vulnerabilityQuery.toLowerCase();

  // Direct ID match
  const directMatch = EXPLOIT_ARCHETYPES.find((a) => query.includes(a.id));
  if (directMatch) return directMatch;

  // Keyword matching
  const keywordMap: Record<string, string> = {
    reentrant: "reentrancy",
    "re-entrant": "reentrancy",
    "re-entry": "reentrancy",
    callback: "reentrancy",
    recursive: "reentrancy",
    mev: "mev_extraction",
    frontrun: "mev_extraction",
    "front-run": "mev_extraction",
    sandwich: "mev_extraction",
    "transaction ordering": "mev_extraction",
    flash: "flash_loan",
    "flash loan": "flash_loan",
    "atomic loan": "flash_loan",
    vampire: "vampire_liquidity",
    liquidity: "vampire_liquidity",
    "liquidity drain": "vampire_liquidity",
    migration: "vampire_liquidity",
    bridge: "bridge_exploit",
    "cross-chain": "bridge_exploit",
    portal: "bridge_exploit",
    relay: "bridge_exploit",
    "zero knowledge": "zk_misuse",
    "zk proof": "zk_misuse",
    zksnark: "zk_misuse",
    nullifier: "zk_misuse",
    "supply chain": "supply_chain",
    backdoor: "supply_chain",
    selfdestruct: "supply_chain",
    proxy: "supply_chain",
    upgrade: "supply_chain",
  };

  for (const [keyword, archetypeId] of Object.entries(keywordMap)) {
    if (query.includes(keyword)) {
      return EXPLOIT_ARCHETYPES.find((a) => a.id === archetypeId) ?? null;
    }
  }

  return null;
}

/**
 * Gets defense recommendations for a vulnerability type.
 */
export function getDefenseRecommendation(
  vulnerabilityQuery: string,
): DefenseRecommendation {
  const archetype = matchArchetype(vulnerabilityQuery);

  if (!archetype) {
    // Return all paradigms as general guidance
    const allParadigms = DEFENSE_PARADIGMS.map(
      (p) =>
        `### ${p.grimoireName} (${p.name})\n**Targets:** ${p.targetExploit}\n\n${p.description}\n\n**Implementation:**\n${p.implementation.map((i) => `- ${i}`).join("\n")}\n\n**Tools:** ${p.tools.join(", ")}`,
    ).join("\n\n---\n\n");

    return {
      vulnerability: vulnerabilityQuery,
      matchedArchetype: null,
      paradigm: null,
      fullResponse: [
        `# 🛡️ Grimoire Defense: "${vulnerabilityQuery}"`,
        "",
        "Could not match a specific exploit archetype. Here are all 7 Defensive Paradigms from the Atlantean Defense Vault:",
        "",
        allParadigms,
      ].join("\n"),
    };
  }

  const paradigm =
    DEFENSE_PARADIGMS.find((p) => p.targetExploit === archetype.id) ?? null;

  const response = [
    `# 🛡️ Grimoire Defense: ${archetype.grimoireName}`,
    "",
    `**Matched Exploit Archetype:** ${archetype.name} (${archetype.grimoireName})`,
    `**Family Domain:** ${archetype.family}`,
    `**Severity:** ${archetype.severity}`,
    "",
    `## Threat Profile`,
    "",
    archetype.description,
    "",
    "### Known Attack Indicators",
    ...archetype.indicators.map((i) => `- ⚠️ ${i}`),
    "",
    "### Solidity Patterns to Watch",
    ...archetype.solidityPatterns.map((p) => `- \`${p}\``),
    "",
  ];

  if (paradigm) {
    response.push(
      `## Recommended Defense: ${paradigm.grimoireName}`,
      "",
      `**${paradigm.name}**`,
      "",
      paradigm.description,
      "",
      "### Implementation Steps",
      ...paradigm.implementation.map((step, i) => `${i + 1}. ${step}`),
      "",
      "### Recommended Tools",
      ...paradigm.tools.map((t) => `- ${t}`),
    );
  } else {
    response.push(
      `## Recommended Defense`,
      "",
      `**${archetype.defenseParadigm}**`,
      "",
      archetype.defenseDescription,
    );
  }

  return {
    vulnerability: vulnerabilityQuery,
    matchedArchetype: archetype,
    paradigm,
    fullResponse: response.join("\n"),
  };
}
