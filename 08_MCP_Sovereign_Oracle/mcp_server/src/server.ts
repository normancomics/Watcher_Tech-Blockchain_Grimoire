/**
 * Grimoire Oracle — HTTP Server with x402 Payment Support
 *
 * Exposes the Grimoire Oracle tools via REST API with x402 micropayment
 * middleware. This is the monetized HTTP interface — clients pay per tool
 * call using the x402 protocol.
 *
 * Every tool call runs inside an isolated sandbox with:
 * - Per-tool security policies (input limits, output caps, timeouts)
 * - Frozen knowledge base snapshots (no shared mutable state)
 * - Input sanitization (null bytes, control chars, length enforcement)
 * - Error containment (tool failures never crash the server)
 * - Full audit trail (every execution logged)
 *
 * Usage:
 *   npm run start:http                    # Start HTTP server
 *   PORT=8402 npm run start:http          # Custom port
 *   GRIMOIRE_REPO_PATH=/path npm run start:http
 *
 * Endpoints:
 *   GET  /                                # Server info + registration
 *   GET  /health                          # Health check
 *   POST /api/tools/grimoire_audit_scan   # Audit scan (x402 paid)
 *   POST /api/tools/grimoire_query_codex  # Codex query (x402 paid)
 *   POST /api/tools/grimoire_defense_recommend   # Defense (x402 paid)
 *   POST /api/tools/grimoire_watcher_consult     # Watcher (x402 paid)
 *   POST /api/tools/grimoire_family_threat_intel  # Threat intel (x402 paid)
 *   POST /api/tools/grimoire_quantum_entropy      # Quantum entropy (x402 paid)
 *   POST /api/tools/grimoire_rag_synthesis        # RAG synthesis (x402 paid)
 *   POST /api/tools/grimoire_sovereign_invoke     # Sovereign invoke (x402 paid)
 *   GET  /api/pricing                     # Pricing info
 *   GET  /api/audit-stats                 # Sandbox audit statistics
 *   GET  /.well-known/agent.json          # ERC-8004 registration
 */

import express from "express";
import { paymentMiddleware } from "x402-express";
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
import { loadPricingConfig, x402PaymentGuard } from "./payment/x402.js";
import { loadAgentRegistration } from "./identity/erc8004.js";
import { sandboxExecute, getFrozenKnowledge } from "./sandbox/sandbox.js";
import { getAuditStats } from "./sandbox/audit-log.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT =
  process.env["GRIMOIRE_REPO_PATH"] ?? join(__dirname, "../..");
const PORT = parseInt(process.env["PORT"] ?? "8402", 10);

// ─── Initialize ─────────────────────────────────────────────────────

const app = express();
app.use(express.json({ limit: "1mb" }));

const pricing = loadPricingConfig();
const registration = loadAgentRegistration();

// ─── x402-express paymentMiddleware ────────────────────────────────────
// Production-grade x402 payment enforcement via the Coinbase facilitator.
// RECEIVER_WALLET must be set in the environment (normancomics.eth address).
// Falls back gracefully if the env var is not yet populated (dev/test mode).

const RECEIVER_WALLET = process.env["RECEIVER_WALLET"] ?? "";

if (RECEIVER_WALLET) {
  app.use(
    paymentMiddleware(
      RECEIVER_WALLET as `0x${string}`,
      {
        "POST /api/tools/grimoire_audit_scan":          { price: "$0.50", network: "base" },
        "POST /api/tools/grimoire_query_codex":         { price: "$0.10", network: "base" },
        "POST /api/tools/grimoire_defense_recommend":   { price: "$0.25", network: "base" },
        "POST /api/tools/grimoire_watcher_consult":     { price: "$0.75", network: "base" },
        "POST /api/tools/grimoire_family_threat_intel": { price: "$0.30", network: "base" },
        "POST /api/tools/grimoire_quantum_entropy":     { price: "$0.40", network: "base" },
        "POST /api/tools/grimoire_rag_synthesis":       { price: "$0.20", network: "base" },
        "POST /api/tools/grimoire_sovereign_invoke":    { price: "$1.00", network: "base" },
      },
      { url: "https://x402.org/facilitator" },
    ),
  );
  console.log(`💳 x402-express paymentMiddleware registered (receiver: ${RECEIVER_WALLET})`);
} else {
  console.warn(
    "⚠️  RECEIVER_WALLET not set — x402-express paymentMiddleware is disabled. " +
    "Set RECEIVER_WALLET=<normancomics.eth address> to enable on-chain payment enforcement.",
  );
}

/**
 * Returns a frozen, immutable snapshot of the knowledge base.
 * Safe to share across concurrent sandbox executions.
 */
function getKnowledge() {
  return getFrozenKnowledge(() => {
    const chunks = loadKnowledgeBase(REPO_ROOT);
    console.log(
      `📚 Knowledge base loaded: ${chunks.length} chunks from ${REPO_ROOT}`,
    );
    return chunks;
  });
}

// ─── Public Endpoints ───────────────────────────────────────────────

app.get("/", (_req, res) => {
  res.json({
    name: "Grimoire Oracle",
    version: "0.1.0",
    description:
      "Sovereign MCP Server for blockchain security intelligence, powered by the Watcher Tech Blockchain Grimoire",
    sandbox: {
      enabled: true,
      features: [
        "per-tool security policies",
        "input sanitization",
        "output size limits",
        "execution timeouts",
        "frozen knowledge snapshots",
        "error containment",
        "full audit trail",
      ],
    },
    tools: Object.entries(pricing.tools).map(([name, config]) => ({
      name,
      price: `${config.price} ${pricing.currency}`,
      description: config.description,
    })),
    endpoints: {
      mcp: "Use stdio transport (see README)",
      api: "/api/tools/:toolName",
      pricing: "/api/pricing",
      auditStats: "/api/audit-stats",
      registration: "/.well-known/agent.json",
      health: "/health",
    },
    x402: {
      supported: true,
      network: pricing.network,
      currency: pricing.currency,
      receiverAddress: pricing.receiverAddress,
    },
  });
});

app.get("/health", (_req, res) => {
  const knowledge = getKnowledge();
  const stats = getAuditStats();
  res.json({
    status: "ok",
    sandbox: "enabled",
    knowledgeChunks: knowledge.length,
    tools: Object.keys(pricing.tools).length,
    uptime: process.uptime(),
    auditStats: {
      totalExecutions: stats.totalExecutions,
      successRate: stats.successRate,
      totalViolations: stats.totalViolations,
    },
  });
});

app.get("/api/pricing", (_req, res) => {
  res.json(pricing);
});

app.get("/api/audit-stats", (_req, res) => {
  res.json(getAuditStats());
});

// ERC-8004 well-known registration endpoint
app.get("/.well-known/agent.json", (_req, res) => {
  res.json(registration);
});

// ─── Paid Tool Endpoints ────────────────────────────────────────────

// Tool: Audit Scan
app.post("/api/tools/grimoire_audit_scan",
  x402PaymentGuard("grimoire_audit_scan", pricing),
  async (req, res) => {
  const { sourceCode, contractName } = req.body as {
    sourceCode?: string;
    contractName?: string;
  };

  if (!sourceCode) {
    res
      .status(400)
      .json({ error: "sourceCode is required in the request body" });
    return;
  }

  const result = await sandboxExecute(
    "grimoire_audit_scan",
    { sourceCode, contractName },
    (inputs) => {
      const report = auditScan(
        inputs["sourceCode"] as string,
        inputs["contractName"] as string | undefined,
      );
      const formatted = formatAuditReport(report);
      return JSON.stringify({
        summary: report.summary,
        riskLevel: report.riskLevel,
        findingsCount: report.findingsCount,
        formatted,
      });
    },
    { transport: "http" },
  );

  try {
    const parsed = JSON.parse(result.output) as Record<string, unknown>;
    res.json({
      tool: "grimoire_audit_scan",
      sandbox: { durationMs: result.durationMs, timedOut: result.timedOut, violations: result.violations },
      result: parsed,
    });
  } catch {
    res.json({
      tool: "grimoire_audit_scan",
      sandbox: { durationMs: result.durationMs, timedOut: result.timedOut, violations: result.violations },
      result: { formatted: result.output },
    });
  }
});

// Tool: Query Codex
app.post("/api/tools/grimoire_query_codex",
  x402PaymentGuard("grimoire_query_codex", pricing),
  async (req, res) => {
  const { query, maxResults, filterTags } = req.body as {
    query?: string;
    maxResults?: number;
    filterTags?: string[];
  };

  if (!query) {
    res
      .status(400)
      .json({ error: "query is required in the request body" });
    return;
  }

  const knowledge = getKnowledge();

  const result = await sandboxExecute(
    "grimoire_query_codex",
    { query, maxResults, filterTags },
    (inputs) => {
      const queryResult = queryCodex(
        [...knowledge],
        inputs["query"] as string,
        {
          maxResults: inputs["maxResults"] as number | undefined,
          filterTags: inputs["filterTags"] as string[] | undefined,
        },
      );
      return JSON.stringify({
        query: queryResult.query,
        resultsFound: queryResult.resultsFound,
        sources: queryResult.sources,
        response: queryResult.response,
      });
    },
    { knowledge, transport: "http" },
  );

  try {
    const parsed = JSON.parse(result.output) as Record<string, unknown>;
    res.json({
      tool: "grimoire_query_codex",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: parsed,
    });
  } catch {
    res.json({
      tool: "grimoire_query_codex",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: { response: result.output },
    });
  }
});

// Tool: Defense Recommend
app.post("/api/tools/grimoire_defense_recommend",
  x402PaymentGuard("grimoire_defense_recommend", pricing),
  async (req, res) => {
  const { vulnerability } = req.body as { vulnerability?: string };

  if (!vulnerability) {
    res
      .status(400)
      .json({ error: "vulnerability is required in the request body" });
    return;
  }

  const result = await sandboxExecute(
    "grimoire_defense_recommend",
    { vulnerability },
    (inputs) => {
      const rec = getDefenseRecommendation(inputs["vulnerability"] as string);
      return JSON.stringify({
        vulnerability: rec.vulnerability,
        matchedArchetype: rec.matchedArchetype?.name ?? null,
        paradigm: rec.paradigm?.name ?? null,
        response: rec.fullResponse,
      });
    },
    { transport: "http" },
  );

  try {
    const parsed = JSON.parse(result.output) as Record<string, unknown>;
    res.json({
      tool: "grimoire_defense_recommend",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: parsed,
    });
  } catch {
    res.json({
      tool: "grimoire_defense_recommend",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: { response: result.output },
    });
  }
});

// Tool: Watcher Consult
app.post("/api/tools/grimoire_watcher_consult",
  x402PaymentGuard("grimoire_watcher_consult", pricing),
  async (req, res) => {
  const { watcher, question } = req.body as {
    watcher?: string;
    question?: string;
  };

  if (!watcher || !question) {
    res
      .status(400)
      .json({
        error:
          "Both watcher and question are required in the request body",
      });
    return;
  }

  const knowledge = getKnowledge();

  const result = await sandboxExecute(
    "grimoire_watcher_consult",
    { watcher, question },
    (inputs) => {
      const consultation = consultWatcher(
        inputs["watcher"] as string,
        inputs["question"] as string,
        [...knowledge],
      );
      return JSON.stringify({
        watcher: consultation.watcher.name,
        domain: consultation.watcher.domain,
        relatedKnowledge: consultation.relatedKnowledge,
        analysis: consultation.analysis,
      });
    },
    { knowledge, transport: "http" },
  );

  try {
    const parsed = JSON.parse(result.output) as Record<string, unknown>;
    res.json({
      tool: "grimoire_watcher_consult",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: parsed,
    });
  } catch {
    res.json({
      tool: "grimoire_watcher_consult",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: { analysis: result.output },
    });
  }
});

// Tool: Family Threat Intel
app.post("/api/tools/grimoire_family_threat_intel",
  x402PaymentGuard("grimoire_family_threat_intel", pricing),
  async (req, res) => {
  const { query } = req.body as { query?: string };

  if (!query) {
    res
      .status(400)
      .json({ error: "query is required in the request body" });
    return;
  }

  const result = await sandboxExecute(
    "grimoire_family_threat_intel",
    { query },
    (inputs) => {
      const intel = getFamilyThreatIntel(inputs["query"] as string);
      return JSON.stringify({
        query: intel.query,
        matchedFamily: intel.matchedFamily?.name ?? null,
        response: intel.fullResponse,
      });
    },
    { transport: "http" },
  );

  try {
    const parsed = JSON.parse(result.output) as Record<string, unknown>;
    res.json({
      tool: "grimoire_family_threat_intel",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: parsed,
    });
  } catch {
    res.json({
      tool: "grimoire_family_threat_intel",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: { response: result.output },
    });
  }
});

// ─── Endpoint 6: Quantum Entropy ─────────────────────────────────────

app.post("/api/tools/grimoire_quantum_entropy",
  x402PaymentGuard("grimoire_quantum_entropy", pricing),
  async (req, res) => {
  const { bytes, encoding, planet, angel, commitReveal, useCase } = req.body as {
    bytes?: number;
    encoding?: "hex" | "base64" | "binary-description";
    planet?: "saturn" | "jupiter" | "mars" | "sun" | "venus" | "mercury" | "moon";
    angel?: string;
    commitReveal?: boolean;
    useCase?: string;
  };

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
      return JSON.stringify({
        entropy:       entropy.entropy,
        entropyBits:   entropy.entropyBits,
        algorithm:     entropy.algorithm,
        pqcSuite:      entropy.pqcSuite,
        angel:         entropy.angel,
        planet:        entropy.planet,
        commit:        entropy.commit,
        revealKey:     entropy.revealKey,
        provenanceHash: entropy.provenanceHash,
        timestamp:     entropy.timestamp,
        report:        entropy.fullReport,
      });
    },
    { transport: "http" },
  );

  try {
    const parsed = JSON.parse(result.output) as Record<string, unknown>;
    res.json({
      tool: "grimoire_quantum_entropy",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: parsed,
    });
  } catch {
    res.json({
      tool: "grimoire_quantum_entropy",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: { report: result.output },
    });
  }
});

// ─── Endpoint 7: RAG Synthesis ───────────────────────────────────────

app.post("/api/tools/grimoire_rag_synthesis",
  x402PaymentGuard("grimoire_rag_synthesis", pricing),
  async (req, res) => {
  const { query, subQueries, maxSources, filterTags, crossReference, depth } = req.body as {
    query?: string;
    subQueries?: string[];
    maxSources?: number;
    filterTags?: string[];
    crossReference?: boolean;
    depth?: "brief" | "standard" | "deep";
  };

  if (!query) {
    res.status(400).json({ error: "query is required in the request body" });
    return;
  }

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
      return JSON.stringify({
        query:            synthesis.query,
        citationCount:    synthesis.citations.length,
        pillarsActivated: synthesis.pillarsActivated,
        confidenceScore:  synthesis.confidenceScore,
        crossReferences:  synthesis.crossReferences,
        citations:        synthesis.citations,
        response:         synthesis.fullResponse,
      });
    },
    { knowledge, transport: "http" },
  );

  try {
    const parsed = JSON.parse(result.output) as Record<string, unknown>;
    res.json({
      tool: "grimoire_rag_synthesis",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: parsed,
    });
  } catch {
    res.json({
      tool: "grimoire_rag_synthesis",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: { response: result.output },
    });
  }
});

// ─── Endpoint 8: Sovereign Invoke ────────────────────────────────────

app.post("/api/tools/grimoire_sovereign_invoke",
  x402PaymentGuard("grimoire_sovereign_invoke", pricing),
  async (req, res) => {
  const { objective, contractSource, contractName, objectiveType, maxSources } = req.body as {
    objective?: string;
    contractSource?: string;
    contractName?: string;
    objectiveType?: "CONTRACT_AUDIT" | "THREAT_ANALYSIS" | "DEFENSE_SYNTHESIS" | "KNOWLEDGE_SYNTHESIS" | "WATCHER_COUNCIL";
    maxSources?: number;
  };

  if (!objective) {
    res.status(400).json({ error: "objective is required in the request body" });
    return;
  }

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
      return JSON.stringify({
        objective:          invocation.objective,
        objectiveType:      invocation.objectiveType,
        riskLevel:          invocation.riskLevel,
        activatedWatchers:  invocation.activatedWatchers,
        stepsExecuted:      invocation.stepsExecuted.length,
        sovereignJudgment:  invocation.sovereignJudgment,
        fullReport:         invocation.fullReport,
      });
    },
    { knowledge, transport: "http" },
  );

  try {
    const parsed = JSON.parse(result.output) as Record<string, unknown>;
    res.json({
      tool: "grimoire_sovereign_invoke",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: parsed,
    });
  } catch {
    res.json({
      tool: "grimoire_sovereign_invoke",
      sandbox: { timedOut: result.timedOut, violations: result.violations },
      result: { report: result.output },
    });
  }
});

// ─── Start Server ───────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`🔮 Grimoire Oracle HTTP Server started on port ${PORT}`);
  console.log(`📚 Knowledge base root: ${REPO_ROOT}`);
  console.log(`🛡️  Sandbox: ENABLED — all tools run in isolated execution contexts`);
  console.log(`💰 x402 payments: ${pricing.network} / ${pricing.currency}`);
  console.log(`🏛️  ERC-8004 registration: /.well-known/agent.json`);
  console.log(`\nEndpoints:`);
  console.log(`  GET  http://localhost:${PORT}/`);
  console.log(`  GET  http://localhost:${PORT}/health`);
  console.log(`  GET  http://localhost:${PORT}/api/pricing`);
  console.log(`  GET  http://localhost:${PORT}/api/audit-stats`);
  console.log(`  GET  http://localhost:${PORT}/.well-known/agent.json`);
  console.log(`  POST http://localhost:${PORT}/api/tools/grimoire_audit_scan`);
  console.log(`  POST http://localhost:${PORT}/api/tools/grimoire_query_codex`);
  console.log(
    `  POST http://localhost:${PORT}/api/tools/grimoire_defense_recommend`,
  );
  console.log(
    `  POST http://localhost:${PORT}/api/tools/grimoire_watcher_consult`,
  );
  console.log(
    `  POST http://localhost:${PORT}/api/tools/grimoire_family_threat_intel`,
  );
});
