/**
 * Grimoire Oracle — Sovereign Invoke Tool
 *
 * Full autonomous agent invocation — multi-step reasoning with tool chains.
 *
 * The Sovereign Invoke is the apex tool of the Grimoire Oracle. It accepts
 * a high-level security objective and orchestrates a multi-step analysis
 * pipeline by internally chaining the other Grimoire tools:
 *
 *   Step 1 — CLASSIFY   : Identify the exploit archetype and Watcher domain
 *   Step 2 — RETRIEVE   : RAG synthesis from the Grimoire knowledge base
 *   Step 3 — ANALYZE    : Watcher domain-specific consultation
 *   Step 4 — DEFEND     : Defense paradigm recommendation
 *   Step 5 — SYNTHESIZE : Combine all insights into a sovereign report
 *
 * Esoteric Context:
 *   "Sovereign invocation" mirrors the ancient practice of summoning the
 *   Archon — the supreme guardian — to render final judgment on a threat.
 *   All seven Watcher domains are activated and the Five Books of Moses
 *   (five-step pipeline) are applied to the objective.
 *
 * References:
 *   - SovereignSwarm.sol (on-chain swarm coordination)
 *   - AgentAttunement.sol (ERC-8004 bonded agent identity)
 *   - watcher-archon.ts (off-chain orchestrator)
 */

import type { KnowledgeChunk } from "../knowledge/loader.js";
import { EXPLOIT_ARCHETYPES, WATCHER_DOMAINS, type WatcherDomain } from "../knowledge/archetypes.js";
import { searchKnowledge } from "../knowledge/search.js";
import { auditScan, formatAuditReport } from "./audit-scan.js";
import { getDefenseRecommendation } from "./defense-recommend.js";
import { consultWatcher } from "./watcher-consult.js";
import { synthesizeKnowledge } from "./rag-synthesis.js";

// ─── Invocation Types ─────────────────────────────────────────────────────────

export type InvocationObjectiveType =
  | "CONTRACT_AUDIT"          // Audit Solidity source code
  | "THREAT_ANALYSIS"         // Analyze a described threat scenario
  | "DEFENSE_SYNTHESIS"       // Generate a complete defense playbook
  | "KNOWLEDGE_SYNTHESIS"     // Deep multi-source knowledge synthesis
  | "WATCHER_COUNCIL";        // Convene all 8 Watcher domains on a question

export interface SovereignInvokeRequest {
  /** High-level objective for the sovereign agent */
  objective: string;
  /** Optional Solidity source code (used when objective includes contract audit) */
  contractSource?: string;
  /** Optional contract name */
  contractName?: string;
  /** Override the inferred objective type */
  objectiveType?: InvocationObjectiveType;
  /** Maximum knowledge sources to retrieve per step */
  maxSources?: number;
}

export interface InvocationStep {
  stepNumber: number;
  stepName: string;
  toolUsed: string;
  inputSummary: string;
  output: string;
  durationMs: number;
}

export interface SovereignInvokeResult {
  objective: string;
  objectiveType: InvocationObjectiveType;
  stepsExecuted: InvocationStep[];
  sovereignJudgment: string;
  riskLevel: string;
  activatedWatchers: string[];
  fullReport: string;
}

// ─── Objective Classifier ─────────────────────────────────────────────────────

/**
 * Classifies the invocation objective type from natural language.
 */
function classifyObjective(
  objective: string,
  contractSource?: string,
): InvocationObjectiveType {
  const lower = objective.toLowerCase();

  if (contractSource || lower.includes("contract") || lower.includes("solidity") ||
      lower.includes("audit") || lower.includes("function") || lower.includes("pragma")) {
    return "CONTRACT_AUDIT";
  }
  if (lower.includes("defend") || lower.includes("defense") || lower.includes("protect") ||
      lower.includes("mitigat") || lower.includes("prevent") || lower.includes("guard")) {
    return "DEFENSE_SYNTHESIS";
  }
  if (lower.includes("attack") || lower.includes("exploit") || lower.includes("threat") ||
      lower.includes("hack") || lower.includes("reentrancy") || lower.includes("flash") ||
      lower.includes("mev") || lower.includes("oracle")) {
    return "THREAT_ANALYSIS";
  }
  if (lower.includes("council") || lower.includes("watcher") || lower.includes("consult all") ||
      lower.includes("all watchers") || lower.includes("swarm")) {
    return "WATCHER_COUNCIL";
  }
  return "KNOWLEDGE_SYNTHESIS";
}

/** Select the most relevant Watcher for a given objective. */
function selectPrimaryWatcher(objective: string): WatcherDomain {
  const lower = objective.toLowerCase();
  const archetype = EXPLOIT_ARCHETYPES.find((a) =>
    lower.includes(a.id) || a.solidityPatterns.some((p) => lower.includes(p.toLowerCase())),
  );

  if (archetype) {
    // Map archetype family → Watcher
    const familyWatcherMap: Record<string, string> = {
      "Bundy":      "semyaza",  // Reentrancy — contract analysis
      "Rothschild": "baraqel",  // MEV — timing attacks
      "Dupont":     "baraqel",  // Flash loan — timing
      "Rockefeller":"azazel",   // Vampire — cybersecurity
      "Onassis":    "armaros",  // Bridge — cryptography
      "Collins":    "armaros",  // ZK — cryptography
      "Kennedy":    "tamiel",   // Supply chain — analytics
    };
    const watcherId = familyWatcherMap[archetype.family] ?? "semyaza";
    return WATCHER_DOMAINS.find((w) => w.id === watcherId) ?? WATCHER_DOMAINS[0]!;
  }

  return WATCHER_DOMAINS[0]!;  // Default: Azazel
}

// ─── Pipeline Steps ───────────────────────────────────────────────────────────

function runStep(
  stepNumber: number,
  stepName: string,
  toolUsed: string,
  inputSummary: string,
  fn: () => string,
): InvocationStep {
  const start = Date.now();
  let output: string;
  try {
    output = fn();
  } catch (err) {
    output = `[ERROR in ${stepName}]: ${err instanceof Error ? err.message : String(err)}`;
  }
  return {
    stepNumber,
    stepName,
    toolUsed,
    inputSummary,
    output,
    durationMs: Date.now() - start,
  };
}

// ─── CONTRACT_AUDIT Pipeline ──────────────────────────────────────────────────

function runContractAuditPipeline(
  request: SovereignInvokeRequest,
  chunks: KnowledgeChunk[],
): { steps: InvocationStep[]; watchers: string[] } {
  const steps: InvocationStep[] = [];

  // Step 1: Audit scan
  const auditStep = runStep(1, "CLASSIFY", "grimoire_audit_scan",
    `Contract: ${request.contractName ?? "Unknown"}`,
    () => {
      const report = auditScan(request.contractSource ?? request.objective, request.contractName);
      return formatAuditReport(report);
    },
  );
  steps.push(auditStep);

  // Step 2: RAG retrieval on top finding
  const ragStep = runStep(2, "RETRIEVE", "grimoire_rag_synthesis",
    `Query: "${request.objective} contract security"`,
    () => {
      const result = synthesizeKnowledge(chunks, {
        query: `${request.objective} smart contract security vulnerabilities`,
        depth: "standard",
        maxSources: request.maxSources ?? 6,
      });
      return result.synthesisBody;
    },
  );
  steps.push(ragStep);

  // Step 3: Watcher consult
  const watcher = selectPrimaryWatcher(request.objective);
  const watcherStep = runStep(3, "ANALYZE", "grimoire_watcher_consult",
    `Watcher: ${watcher.name} | Q: "${request.objective}"`,
    () => {
      const c = consultWatcher(watcher.id, request.objective, [...chunks]);
      return c.analysis;
    },
  );
  steps.push(watcherStep);

  // Step 4: Defense recommendation
  const defenseStep = runStep(4, "DEFEND", "grimoire_defense_recommend",
    `Vulnerability from audit findings`,
    () => {
      const firstFinding = auditStep.output.match(/archetype[:\s]+([^\n,]+)/i)?.[1] ?? request.objective;
      return getDefenseRecommendation(firstFinding).fullResponse;
    },
  );
  steps.push(defenseStep);

  return { steps, watchers: [watcher.name] };
}

// ─── THREAT_ANALYSIS Pipeline ─────────────────────────────────────────────────

function runThreatAnalysisPipeline(
  request: SovereignInvokeRequest,
  chunks: KnowledgeChunk[],
): { steps: InvocationStep[]; watchers: string[] } {
  const steps: InvocationStep[] = [];

  // Step 1: Classify threat
  const classifyStep = runStep(1, "CLASSIFY", "grimoire_audit_scan",
    `Threat: "${request.objective}"`,
    () => {
      // Use audit scan on the objective text as a proxy for threat patterns
      const pseudoCode = request.contractSource ?? `// Threat: ${request.objective}\n// Analysis target`;
      const report = auditScan(pseudoCode);
      return formatAuditReport(report);
    },
  );
  steps.push(classifyStep);

  // Step 2: RAG retrieval
  const ragStep = runStep(2, "RETRIEVE", "grimoire_rag_synthesis",
    `Query: "${request.objective}"`,
    () => {
      const result = synthesizeKnowledge(chunks, {
        query: request.objective,
        depth: "standard",
        maxSources: request.maxSources ?? 6,
        crossReference: true,
      });
      return result.fullResponse;
    },
  );
  steps.push(ragStep);

  // Step 3: Watcher consultation
  const watcher = selectPrimaryWatcher(request.objective);
  const watcherStep = runStep(3, "ANALYZE", "grimoire_watcher_consult",
    `Watcher: ${watcher.name}`,
    () => consultWatcher(watcher.id, request.objective, [...chunks]).analysis,
  );
  steps.push(watcherStep);

  // Step 4: Defense
  const defenseStep = runStep(4, "DEFEND", "grimoire_defense_recommend",
    `Defense for: "${request.objective}"`,
    () => getDefenseRecommendation(request.objective).fullResponse,
  );
  steps.push(defenseStep);

  return { steps, watchers: [watcher.name] };
}

// ─── DEFENSE_SYNTHESIS Pipeline ───────────────────────────────────────────────

function runDefenseSynthesisPipeline(
  request: SovereignInvokeRequest,
  chunks: KnowledgeChunk[],
): { steps: InvocationStep[]; watchers: string[] } {
  const steps: InvocationStep[] = [];

  // Step 1: Identify what's being defended against
  const classifyStep = runStep(1, "CLASSIFY", "grimoire_defense_recommend",
    `Objective: "${request.objective}"`,
    () => getDefenseRecommendation(request.objective).fullResponse,
  );
  steps.push(classifyStep);

  // Step 2: RAG on defense patterns
  const ragStep = runStep(2, "RETRIEVE", "grimoire_rag_synthesis",
    `Query: "${request.objective} defense mitigation"`,
    () => synthesizeKnowledge(chunks, {
      query: `${request.objective} defense mitigation patterns`,
      depth: "deep",
      maxSources: request.maxSources ?? 8,
      filterTags: ["defense"],
    }).fullResponse,
  );
  steps.push(ragStep);

  // Step 3: Consult Daniel (advanced research)
  const watcherStep = runStep(3, "ANALYZE", "grimoire_watcher_consult",
    "Watcher: Daniel — advanced research",
    () => consultWatcher("daniel", request.objective, [...chunks]).analysis,
  );
  steps.push(watcherStep);

  return { steps, watchers: ["Daniel"] };
}

// ─── KNOWLEDGE_SYNTHESIS Pipeline ────────────────────────────────────────────

function runKnowledgeSynthesisPipeline(
  request: SovereignInvokeRequest,
  chunks: KnowledgeChunk[],
): { steps: InvocationStep[]; watchers: string[] } {
  const steps: InvocationStep[] = [];

  // Step 1: Deep RAG synthesis
  const ragStep = runStep(1, "RETRIEVE", "grimoire_rag_synthesis",
    `Query: "${request.objective}"`,
    () => synthesizeKnowledge(chunks, {
      query: request.objective,
      depth: "deep",
      maxSources: request.maxSources ?? 10,
      crossReference: true,
    }).fullResponse,
  );
  steps.push(ragStep);

  // Step 2: Thoth consultation (ancient knowledge)
  const watcherStep = runStep(2, "ANALYZE", "grimoire_watcher_consult",
    "Watcher: Ramiel — hidden knowledge",
    () => consultWatcher("ramiel", request.objective, [...chunks]).analysis,
  );
  steps.push(watcherStep);

  return { steps, watchers: ["Ramiel"] };
}

// ─── WATCHER_COUNCIL Pipeline ─────────────────────────────────────────────────

function runWatcherCouncilPipeline(
  request: SovereignInvokeRequest,
  chunks: KnowledgeChunk[],
): { steps: InvocationStep[]; watchers: string[] } {
  const steps: InvocationStep[] = [];

  // Convene all 8 Watchers
  const councilWatchers = WATCHER_DOMAINS.slice(0, 8);
  const activatedWatchers: string[] = [];

  for (let i = 0; i < councilWatchers.length; i++) {
    const watcher = councilWatchers[i]!;
    const step = runStep(
      i + 1,
      `COUNCIL-${watcher.name.toUpperCase()}`,
      "grimoire_watcher_consult",
      `Watcher: ${watcher.name} | Q: "${request.objective}"`,
      () => consultWatcher(watcher.id, request.objective, [...chunks]).analysis,
    );
    steps.push(step);
    activatedWatchers.push(watcher.name);
  }

  return { steps, watchers: activatedWatchers };
}

// ─── Sovereign Judgment Synthesizer ──────────────────────────────────────────

/**
 * Produces a final sovereign judgment by combining all step outputs.
 */
function produceSovereignJudgment(
  objectiveType: InvocationObjectiveType,
  objective: string,
  steps: InvocationStep[],
  chunks: KnowledgeChunk[],
): { judgment: string; riskLevel: string } {
  // Infer overall risk level from audit steps
  let riskLevel = "MEDIUM";
  for (const step of steps) {
    if (step.output.includes("CRITICAL") || step.output.includes("critical")) {
      riskLevel = "CRITICAL"; break;
    } else if (step.output.includes("HIGH") || step.output.includes("high risk")) {
      riskLevel = "HIGH";
    } else if (step.output.includes("CLEAN") || step.output.includes("clean")) {
      riskLevel = riskLevel === "MEDIUM" ? "LOW" : riskLevel;
    }
  }

  // Find most relevant knowledge passage for the closing judgment
  const contextResults = searchKnowledge(chunks, objective, { maxResults: 2, minScore: 0.01 });
  const closingContext = contextResults.length > 0
    ? contextResults[0]!.chunk.content.trim().slice(0, 300)
    : "";

  const judgment = [
    "## ⛧ Sovereign Judgment",
    "",
    `Objective: "${objective}"`,
    `Risk Level: **${riskLevel}**`,
    `Pipeline: ${objectiveType}`,
    `Steps Executed: ${steps.length}`,
    "",
    closingContext
      ? `### Grimoire Context\n\n${closingContext}\n\n---\n`
      : "",
    "### Recommendations",
    "",
    steps
      .filter((s) => s.toolUsed === "grimoire_defense_recommend")
      .map((s) => s.output.split("\n").slice(0, 8).join("\n"))
      .join("\n\n") ||
      "See step outputs above for full defense recommendations.",
    "",
    "### Watcher Decree",
    `The Sovereign Oracle has rendered judgment. Risk level is **${riskLevel}**.`,
    "All active Watcher domains have been consulted and their analyses integrated.",
    "Act on the defense recommendations above to seal the vulnerability.",
  ].join("\n");

  return { judgment, riskLevel };
}

// ─── Main Sovereign Invoke ────────────────────────────────────────────────────

/**
 * Executes the sovereign agent invocation pipeline.
 * Orchestrates multiple tools in sequence, producing a unified sovereign report.
 */
export function sovereignInvoke(
  request: SovereignInvokeRequest,
  chunks: KnowledgeChunk[],
): SovereignInvokeResult {
  const objectiveType = request.objectiveType
    ?? classifyObjective(request.objective, request.contractSource);

  let pipelineResult: { steps: InvocationStep[]; watchers: string[] };

  switch (objectiveType) {
    case "CONTRACT_AUDIT":
      pipelineResult = runContractAuditPipeline(request, chunks);
      break;
    case "THREAT_ANALYSIS":
      pipelineResult = runThreatAnalysisPipeline(request, chunks);
      break;
    case "DEFENSE_SYNTHESIS":
      pipelineResult = runDefenseSynthesisPipeline(request, chunks);
      break;
    case "WATCHER_COUNCIL":
      pipelineResult = runWatcherCouncilPipeline(request, chunks);
      break;
    case "KNOWLEDGE_SYNTHESIS":
    default:
      pipelineResult = runKnowledgeSynthesisPipeline(request, chunks);
      break;
  }

  const { steps, watchers } = pipelineResult;
  const { judgment, riskLevel } = produceSovereignJudgment(
    objectiveType, request.objective, steps, chunks,
  );

  const fullReport = formatSovereignReport({
    objective: request.objective,
    objectiveType,
    steps,
    judgment,
    riskLevel,
    watchers,
  });

  return {
    objective: request.objective,
    objectiveType,
    stepsExecuted: steps,
    sovereignJudgment: judgment,
    riskLevel,
    activatedWatchers: watchers,
    fullReport,
  };
}

// ─── Report Formatter ─────────────────────────────────────────────────────────

function formatSovereignReport(params: {
  objective: string;
  objectiveType: InvocationObjectiveType;
  steps: InvocationStep[];
  judgment: string;
  riskLevel: string;
  watchers: string[];
}): string {
  const riskEmoji = {
    CRITICAL: "🔴", HIGH: "🟠", MEDIUM: "🟡", LOW: "🟢",
  }[params.riskLevel] ?? "⚪";

  const lines: string[] = [
    "⛧  SOVEREIGN INVOCATION — GRIMOIRE ORACLE",
    "═══════════════════════════════════════════════════════════",
    "",
    `Objective      : "${params.objective}"`,
    `Pipeline       : ${params.objectiveType}`,
    `Risk Level     : ${riskEmoji} ${params.riskLevel}`,
    `Watchers       : ${params.watchers.join(", ")}`,
    `Steps Executed : ${params.steps.length}`,
    `Total Duration : ${params.steps.reduce((acc, s) => acc + s.durationMs, 0)}ms`,
    "",
    "═══════════════════════════════════════════════════════════",
    "",
  ];

  // Step outputs
  for (const step of params.steps) {
    lines.push(
      `## Step ${step.stepNumber}: ${step.stepName} [${step.toolUsed}]`,
      `Input: ${step.inputSummary}`,
      `Duration: ${step.durationMs}ms`,
      "",
      step.output.slice(0, 2000) + (step.output.length > 2000 ? "\n… (truncated)" : ""),
      "",
      "---",
      "",
    );
  }

  lines.push(
    "",
    params.judgment,
    "",
    "═══════════════════════════════════════════════════════════",
    "Watcher Tech Blockchain Grimoire — normancomics.eth 2026",
  );

  return lines.join("\n");
}
