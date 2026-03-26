/**
 * Grimoire Oracle — Audit Scan Tool
 *
 * Scans Solidity source code for the 7 exploit archetypes defined
 * in the Watcher Tech Blockchain Grimoire.
 */

import { EXPLOIT_ARCHETYPES, type ExploitArchetype } from "../knowledge/archetypes.js";

export interface AuditFinding {
  archetype: ExploitArchetype;
  line: number;
  matchedPattern: string;
  context: string;
  confidence: "high" | "medium" | "low";
}

export interface AuditReport {
  summary: string;
  riskLevel: "critical" | "high" | "medium" | "low" | "clean";
  findingsCount: number;
  findings: AuditFinding[];
  recommendations: string[];
  archetypesCovered: string[];
}

/**
 * Scans Solidity source code for known exploit patterns.
 */
export function auditScan(sourceCode: string, contractName?: string): AuditReport {
  const lines = sourceCode.split("\n");
  const findings: AuditFinding[] = [];
  const name = contractName ?? "Unknown Contract";

  for (const archetype of EXPLOIT_ARCHETYPES) {
    for (const pattern of archetype.solidityPatterns) {
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.includes(pattern)) {
          // Determine confidence based on surrounding context
          const contextStart = Math.max(0, i - 3);
          const contextEnd = Math.min(lines.length, i + 4);
          const context = lines.slice(contextStart, contextEnd).join("\n");
          const confidence = determineConfidence(archetype, line, context, lines, i);

          findings.push({
            archetype,
            line: i + 1,
            matchedPattern: pattern,
            context,
            confidence,
          });
        }
      }
    }

    // Also check for indicator patterns
    for (const indicator of archetype.indicators) {
      const indicatorLower = indicator.toLowerCase();
      // These are descriptive — check if the code pattern matches
      if (indicatorLower.includes("missing") && indicatorLower.includes("reentrancyguard")) {
        if (
          sourceCode.includes("call{value:") &&
          !sourceCode.includes("nonReentrant") &&
          !sourceCode.includes("ReentrancyGuard")
        ) {
          findings.push({
            archetype,
            line: 0,
            matchedPattern: indicator,
            context: "Contract uses external calls but lacks ReentrancyGuard",
            confidence: "high",
          });
        }
      }
    }
  }

  // Deduplicate by line + archetype
  const seen = new Set<string>();
  const uniqueFindings = findings.filter((f) => {
    const key = `${f.archetype.id}:${f.line}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  // Determine overall risk level
  const riskLevel = determineRiskLevel(uniqueFindings);
  const recommendations = generateRecommendations(uniqueFindings);

  const summary = generateSummary(name, uniqueFindings, riskLevel);

  return {
    summary,
    riskLevel,
    findingsCount: uniqueFindings.length,
    findings: uniqueFindings,
    recommendations,
    archetypesCovered: EXPLOIT_ARCHETYPES.map((a) => a.name),
  };
}

function determineConfidence(
  archetype: ExploitArchetype,
  line: string,
  context: string,
  allLines: string[],
  lineIdx: number,
): "high" | "medium" | "low" {
  // High confidence: pattern found without corresponding defense
  if (archetype.id === "reentrancy") {
    // Check if there's a state update after the external call
    const afterCall = allLines.slice(lineIdx + 1, lineIdx + 5).join(" ");
    if (afterCall.includes("=") && !context.includes("nonReentrant")) {
      return "high";
    }
    return "medium";
  }

  if (archetype.id === "flash_loan") {
    if (line.includes("flashLoan") || line.includes("executeOperation")) {
      return "medium"; // Using flash loans isn't inherently bad
    }
    return "low";
  }

  if (archetype.id === "supply_chain") {
    if (line.includes("selfdestruct") || line.includes("delegatecall")) {
      return "high";
    }
    return "medium";
  }

  return "medium";
}

function determineRiskLevel(
  findings: AuditFinding[],
): "critical" | "high" | "medium" | "low" | "clean" {
  if (findings.length === 0) return "clean";

  const highConfidenceCritical = findings.filter(
    (f) => f.confidence === "high" && f.archetype.severity === "critical",
  );
  if (highConfidenceCritical.length > 0) return "critical";

  const highFindings = findings.filter(
    (f) => f.confidence === "high" || f.archetype.severity === "critical",
  );
  if (highFindings.length > 0) return "high";

  const mediumFindings = findings.filter((f) => f.confidence === "medium");
  if (mediumFindings.length > 2) return "medium";

  return "low";
}

function generateRecommendations(findings: AuditFinding[]): string[] {
  const recommendations: string[] = [];
  const seenArchetypes = new Set<string>();

  for (const finding of findings) {
    if (!seenArchetypes.has(finding.archetype.id)) {
      seenArchetypes.add(finding.archetype.id);
      recommendations.push(
        `**${finding.archetype.grimoireName} Defense (${finding.archetype.defenseParadigm}):** ${finding.archetype.defenseDescription}`,
      );
    }
  }

  if (recommendations.length === 0) {
    recommendations.push(
      "No critical patterns detected. Continue with standard security practices and consider a full manual audit before deployment.",
    );
  }

  return recommendations;
}

function generateSummary(
  contractName: string,
  findings: AuditFinding[],
  riskLevel: string,
): string {
  const archetypeBreakdown = new Map<string, number>();
  for (const f of findings) {
    archetypeBreakdown.set(
      f.archetype.grimoireName,
      (archetypeBreakdown.get(f.archetype.grimoireName) ?? 0) + 1,
    );
  }

  const breakdown = [...archetypeBreakdown.entries()]
    .map(([name, count]) => `  - ${name}: ${count} finding(s)`)
    .join("\n");

  return [
    `# 🔮 Grimoire Audit Report: ${contractName}`,
    "",
    `**Overall Risk Level:** ${riskLevel.toUpperCase()}`,
    `**Total Findings:** ${findings.length}`,
    `**Archetypes Scanned:** ${EXPLOIT_ARCHETYPES.length}`,
    "",
    findings.length > 0
      ? `## Archetype Breakdown\n${breakdown}`
      : "✅ No exploit archetype patterns detected.",
  ].join("\n");
}

/**
 * Formats an audit report for MCP tool response.
 */
export function formatAuditReport(report: AuditReport): string {
  const sections: string[] = [report.summary, ""];

  if (report.findings.length > 0) {
    sections.push("## Detailed Findings\n");
    for (const finding of report.findings) {
      sections.push(
        [
          `### ${finding.archetype.grimoireName} (${finding.archetype.name})`,
          `- **Line:** ${finding.line === 0 ? "Global" : finding.line}`,
          `- **Pattern:** \`${finding.matchedPattern}\``,
          `- **Confidence:** ${finding.confidence}`,
          `- **Severity:** ${finding.archetype.severity}`,
          `- **Family:** ${finding.archetype.family}`,
          "",
          "```solidity",
          finding.context,
          "```",
          "",
        ].join("\n"),
      );
    }

    sections.push("## Recommendations\n");
    for (const rec of report.recommendations) {
      sections.push(`- ${rec}`);
    }
  }

  return sections.join("\n");
}
