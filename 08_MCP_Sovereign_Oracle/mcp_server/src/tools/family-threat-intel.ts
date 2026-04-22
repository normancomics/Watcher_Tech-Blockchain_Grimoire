/**
 * Grimoire Oracle — Family Threat Intelligence Tool
 *
 * Provides threat intelligence based on the 13 Family archetype framework.
 * Maps modern DeFi/blockchain threats to their archetypal power structures.
 */

import {
  FAMILY_PROFILES,
  EXPLOIT_ARCHETYPES,
  type FamilyProfile,
} from "../knowledge/archetypes.js";

export interface ThreatIntelReport {
  query: string;
  matchedFamily: FamilyProfile | null;
  fullResponse: string;
}

/**
 * Find a family by ID, name, or domain keyword.
 */
function findFamily(query: string): FamilyProfile | null {
  const q = query.toLowerCase().trim();

  // Direct ID match
  const direct = FAMILY_PROFILES.find((f) => f.id === q);
  if (direct) return direct;

  // Name match
  const nameMatch = FAMILY_PROFILES.find((f) =>
    f.name.toLowerCase().includes(q),
  );
  if (nameMatch) return nameMatch;

  // Domain keyword match
  const domainMatch = FAMILY_PROFILES.find((f) =>
    f.domain.toLowerCase().includes(q),
  );
  if (domainMatch) return domainMatch;

  // Exploit type match
  const exploitKeywords: Record<string, string> = {
    reentrancy: "bundy",
    mev: "rothschild",
    frontrun: "rothschild",
    "flash loan": "dupont",
    flash: "dupont",
    vampire: "rockefeller",
    liquidity: "rockefeller",
    bridge: "astor",
    "cross-chain": "astor",
    zk: "collins",
    "zero knowledge": "collins",
    supply: "van_duyn",
    backdoor: "li",
    oracle: "kennedy",
    governance: "russell",
    arbitrage: "freeman",
    routing: "onassis",
    incentive: "reynolds",
    yield: "reynolds",
  };

  for (const [keyword, familyId] of Object.entries(exploitKeywords)) {
    if (q.includes(keyword)) {
      return FAMILY_PROFILES.find((f) => f.id === familyId) ?? null;
    }
  }

  return null;
}

/**
 * Gets threat intelligence for a specific family archetype or threat domain.
 */
export function getFamilyThreatIntel(query: string): ThreatIntelReport {
  const family = findFamily(query);

  if (!family) {
    // Return overview of all families
    const familyList = FAMILY_PROFILES.map(
      (f) =>
        `| **${f.name}** | ${f.domain} | ${f.patron} | ${f.exploitArchetype} |`,
    ).join("\n");

    return {
      query,
      matchedFamily: null,
      fullResponse: [
        `# 🕵️ Grimoire Threat Intel: "${query}"`,
        "",
        "Could not match a specific Family archetype. Here is the full 13 Families threat landscape:",
        "",
        "| Family | Domain | Patron | Exploit Type |",
        "|--------|--------|--------|-------------|",
        familyList,
        "",
        "Query by family name (e.g., 'rothschild'), domain (e.g., 'banking'), or exploit type (e.g., 'mev').",
      ].join("\n"),
    };
  }

  // Find the associated exploit archetype
  const archetype = EXPLOIT_ARCHETYPES.find(
    (a) => a.id === family.exploitArchetype,
  );

  const response = [
    `# 🕵️ Grimoire Threat Intel: House of ${family.name}`,
    "",
    `**Patron:** ${family.patron}`,
    `**Domain:** ${family.domain}`,
    `**Exploit Archetype:** ${archetype?.grimoireName ?? family.exploitArchetype}`,
    "",
    "## Threat Profile",
    "",
    family.description,
    "",
    "## Known Threat Vectors",
    "",
    ...family.threatVectors.map((v) => `- 🎯 ${v}`),
    "",
    "## Recommended Defenses",
    "",
    ...family.defenseMeasures.map((d) => `- 🛡️ ${d}`),
    "",
  ];

  if (archetype) {
    response.push(
      `## Associated Exploit: ${archetype.grimoireName}`,
      "",
      archetype.description,
      "",
      "### Technical Indicators",
      ...archetype.indicators.map((i) => `- ⚠️ ${i}`),
      "",
      "### Solidity Patterns",
      ...archetype.solidityPatterns.map((p) => `- \`${p}\``),
      "",
      `### Defense Paradigm: ${archetype.defenseParadigm}`,
      "",
      archetype.defenseDescription,
    );
  }

  return {
    query,
    matchedFamily: family,
    fullResponse: response.join("\n"),
  };
}
