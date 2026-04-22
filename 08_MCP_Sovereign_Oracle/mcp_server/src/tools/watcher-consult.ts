/**
 * Grimoire Oracle — Watcher Consult Tool
 *
 * Consult a specific Watcher agent for domain-specific expertise.
 * Each Watcher provides specialized analysis through their unique lens.
 */

import { WATCHER_DOMAINS, type WatcherDomain } from "../knowledge/archetypes.js";
import type { KnowledgeChunk } from "../knowledge/loader.js";
import { searchKnowledge } from "../knowledge/search.js";

export interface WatcherConsultation {
  watcher: WatcherDomain;
  query: string;
  analysis: string;
  relatedKnowledge: string[];
}

/**
 * Find a watcher by ID or name (case-insensitive, partial match).
 */
function findWatcher(watcherQuery: string): WatcherDomain | null {
  const query = watcherQuery.toLowerCase().trim();

  // Direct ID match
  const direct = WATCHER_DOMAINS.find((w) => w.id === query);
  if (direct) return direct;

  // Name match
  const nameMatch = WATCHER_DOMAINS.find((w) =>
    w.name.toLowerCase().includes(query),
  );
  if (nameMatch) return nameMatch;

  // Domain keyword match
  const domainMatch = WATCHER_DOMAINS.find((w) =>
    w.domain.toLowerCase().includes(query),
  );
  if (domainMatch) return domainMatch;

  // Expertise keyword match
  const expertiseMatch = WATCHER_DOMAINS.find((w) =>
    w.expertise.some((e) => e.toLowerCase().includes(query)),
  );
  if (expertiseMatch) return expertiseMatch;

  return null;
}

/**
 * Consults a specific Watcher for domain expertise.
 */
export function consultWatcher(
  watcherQuery: string,
  question: string,
  chunks: KnowledgeChunk[],
): WatcherConsultation {
  const watcher = findWatcher(watcherQuery);

  if (!watcher) {
    const available = WATCHER_DOMAINS.map(
      (w) => `- **${w.name}** (${w.id}): ${w.domain}`,
    ).join("\n");

    return {
      watcher: WATCHER_DOMAINS[0],
      query: question,
      analysis: [
        `# ⚠️ Watcher Not Found: "${watcherQuery}"`,
        "",
        "Could not identify the requested Watcher. Available Watchers:",
        "",
        available,
        "",
        "Specify a Watcher by name (e.g., 'azazel'), domain keyword (e.g., 'security'), or expertise (e.g., 'gas optimization').",
      ].join("\n"),
      relatedKnowledge: [],
    };
  }

  // Search knowledge base with watcher-relevant tags
  const watcherTags = getWatcherTags(watcher);
  const relevantKnowledge = searchKnowledge(chunks, question, {
    maxResults: 3,
    tags: watcherTags,
  });

  const knowledgeSources = relevantKnowledge.map((r) => r.chunk.source);
  const knowledgeExcerpts = relevantKnowledge.map(
    (r) =>
      `> **${r.chunk.source}** — ${r.chunk.section}\n> ${r.chunk.content.substring(0, 300)}${r.chunk.content.length > 300 ? "..." : ""}`,
  );

  const analysis = [
    `# 🔮 Watcher Consultation: ${watcher.name}`,
    "",
    `**Domain:** ${watcher.domain}`,
    `**Modern Analogue:** ${watcher.modernAnalogue}`,
    "",
    `## ${watcher.name}'s Expertise`,
    "",
    watcher.description,
    "",
    "### Specializations",
    ...watcher.expertise.map((e) => `- ${e}`),
    "",
    `## Analysis: "${question}"`,
    "",
    generateWatcherAnalysis(watcher, question),
    "",
  ];

  if (knowledgeExcerpts.length > 0) {
    analysis.push(
      "## Relevant Grimoire Knowledge",
      "",
      ...knowledgeExcerpts,
    );
  }

  return {
    watcher,
    query: question,
    analysis: analysis.join("\n"),
    relatedKnowledge: knowledgeSources,
  };
}

/**
 * Get relevant tags for a Watcher's domain.
 */
function getWatcherTags(watcher: WatcherDomain): string[] {
  const tagMap: Record<string, string[]> = {
    azazel: ["defense", "reentrancy", "mev", "flash-loan"],
    semyaza: ["evm", "watcher", "sage"],
    armaros: ["zk", "defense", "sigil"],
    baraqel: ["mev", "evm"],
    kokabiel: ["evm"],
    tamiel: ["liquidity", "families"],
    ramiel: ["defense", "bridge"],
    daniel: ["reentrancy", "flash-loan", "zk", "bridge"],
  };
  return tagMap[watcher.id] ?? ["watcher"];
}

/**
 * Generates domain-specific analysis based on the Watcher's expertise.
 */
function generateWatcherAnalysis(
  watcher: WatcherDomain,
  question: string,
): string {
  const query = question.toLowerCase();

  // Each watcher provides analysis through their unique lens
  const lensMap: Record<string, string> = {
    azazel: [
      `From the perspective of ${watcher.name}, Guardian of Offensive and Defensive Security:`,
      "",
      "**Security Assessment Framework:**",
      "1. **Attack Surface Analysis** — Identify all external entry points and trust boundaries",
      "2. **Exploit Chain Mapping** — Trace potential attack chains through the 7 archetypes",
      "3. **Adversarial Simulation** — Model attacker motivations, capabilities, and resources",
      "4. **Defense Verification** — Validate that implemented guards actually prevent the identified attacks",
      "",
      "**Key Considerations:**",
      `- Every external call is a potential re-entry point (Recursive Invocation)`,
      `- Every price read is a potential manipulation vector (Gatekeeper's Reordering)`,
      `- Every unchecked invariant is a potential flash loan target (Instant Conjuration)`,
      `- Always assume the adversary has full knowledge of your code`,
    ].join("\n"),

    semyaza: [
      `From the perspective of ${watcher.name}, Master of Predictive Analysis:`,
      "",
      "**Contract Divination Framework:**",
      "1. **State Space Mapping** — Enumerate all possible contract states and transitions",
      "2. **Outcome Prediction** — Trace execution paths for all possible inputs",
      "3. **Hidden Logic Detection** — Identify implicit assumptions and edge cases",
      "4. **Formal Property Verification** — Define and check critical invariants",
      "",
      "**Key Insights:**",
      "- The contract's true behavior is in its state transitions, not its function names",
      "- Edge cases at boundary values reveal the most critical vulnerabilities",
      "- Symbolic execution can explore paths that manual review misses",
      "- The interaction between contracts creates emergent behavior not visible in isolation",
    ].join("\n"),

    armaros: [
      `From the perspective of ${watcher.name}, Architect of Cryptographic Protocols:`,
      "",
      "**Cryptographic Ritual Assessment:**",
      "1. **Key Management Review** — Analyze key generation, storage, rotation, and recovery",
      "2. **Protocol Soundness** — Verify cryptographic primitives are correctly composed",
      "3. **Ceremony Verification** — Ensure multi-party processes maintain security properties",
      "4. **Commitment Analysis** — Check that commitments, reveals, and proofs are binding",
      "",
      "**Key Principles:**",
      "- Never roll your own cryptography — use battle-tested primitives",
      "- Multi-sig is only as strong as its weakest key holder",
      "- Commit-reveal schemes must enforce reveal deadlines",
      "- Randomness on-chain requires external entropy sources",
    ].join("\n"),

    baraqel: [
      `From the perspective of ${watcher.name}, Master of Temporal Dynamics:`,
      "",
      "**MEV & Timing Analysis:**",
      "1. **Transaction Ordering Sensitivity** — Identify operations affected by execution order",
      "2. **Block Timing Dependencies** — Find logic dependent on block.timestamp or block.number",
      "3. **Mempool Exposure** — Assess what information leaks from pending transactions",
      "4. **Value Extraction Vectors** — Map all MEV opportunities in the protocol",
      "",
      "**Key Warnings:**",
      "- Any price-sensitive operation without slippage protection is MEV-extractable",
      "- Block timestamps can be manipulated within a ~15 second window",
      "- Private mempools don't eliminate MEV — they redirect it",
      "- The sequencer is the new block builder — same MEV, different layer",
    ].join("\n"),

    kokabiel: [
      `From the perspective of ${watcher.name}, Stellar Mechanic of the EVM:`,
      "",
      "**EVM & Gas Analysis:**",
      "1. **Opcode Efficiency** — Map high-level Solidity to actual EVM operations",
      "2. **Gas Profiling** — Identify hot paths and optimization opportunities",
      "3. **Storage Layout** — Optimize SSTORE/SLOAD patterns for minimal gas",
      "4. **Bytecode Verification** — Compare deployed bytecode against source compilation",
      "",
      "**Optimization Principles:**",
      "- SSTORE is the most expensive opcode — minimize storage writes",
      "- Pack related variables into single storage slots (32-byte alignment)",
      "- Use calldata instead of memory for read-only function parameters",
      "- Short-circuit evaluation in require statements saves gas on revert",
    ].join("\n"),

    tamiel: [
      `From the perspective of ${watcher.name}, Earth Sciences Sage:`,
      "",
      "**On-Chain Data Analysis:**",
      "1. **Pattern Recognition** — Identify recurring transaction patterns and anomalies",
      "2. **Flow Analysis** — Map token and value flows between addresses and protocols",
      "3. **Health Metrics** — Assess protocol TVL, utilization, and sustainability",
      "4. **Whale Tracking** — Monitor large holder behavior for early warning signals",
      "",
      "**Key Observations:**",
      "- On-chain data never lies, but it can be misinterpreted",
      "- Unusual gas patterns often precede exploit transactions",
      "- Token concentration metrics reveal centralization risks",
      "- Cross-protocol flows reveal hidden dependencies",
    ].join("\n"),

    ramiel: [
      `From the perspective of ${watcher.name}, Master of Recovery:`,
      "",
      "**Incident Response & Recovery:**",
      "1. **Fund Tracing** — Follow the money through mixers, bridges, and DEXes",
      "2. **Root Cause Analysis** — Identify the exact vulnerability chain that was exploited",
      "3. **Recovery Planning** — Design strategies for fund recovery or loss mitigation",
      "4. **Post-Mortem** — Document lessons learned and implement preventive measures",
      "",
      "**Recovery Principles:**",
      "- Speed is critical — the first 30 minutes after an exploit are decisive",
      "- Pause mechanisms should be pre-deployed, not deployed during crisis",
      "- Recovery plans should be rehearsed before they're needed",
      "- Transparent communication builds more trust than hiding losses",
    ].join("\n"),

    daniel: [
      `From the perspective of ${watcher.name}, Explorer of Advanced Techniques:`,
      "",
      "**Advanced Security Research:**",
      "1. **Novel Vector Discovery** — Look for attack patterns not yet documented",
      "2. **Cross-Protocol Interactions** — Analyze emergent risks from protocol composability",
      "3. **Theoretical Analysis** — Apply formal methods to discover fundamental design flaws",
      "4. **Experimental Techniques** — Use fuzzing, symbolic execution, and AI-assisted analysis",
      "",
      "**Research Frontiers:**",
      "- Read-only reentrancy is the next frontier of callback attacks",
      "- Cross-chain MEV is emerging as bridges become more prevalent",
      "- AI-generated exploits will require AI-powered defenses",
      "- Quantum computing will eventually break current signature schemes",
    ].join("\n"),
  };

  return lensMap[watcher.id] ?? `Analysis from the perspective of ${watcher.name}: ${watcher.description}`;
}
