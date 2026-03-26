/**
 * Grimoire Oracle — HTTP Server with x402 Payment Support
 *
 * Exposes the Grimoire Oracle tools via REST API with x402 micropayment
 * middleware. This is the monetized HTTP interface — clients pay per tool
 * call using the x402 protocol.
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
 *   GET  /api/pricing                     # Pricing info
 *   GET  /.well-known/agent.json          # ERC-8004 registration
 */

import express from "express";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { loadKnowledgeBase, type KnowledgeChunk } from "./knowledge/loader.js";
import { auditScan, formatAuditReport } from "./tools/audit-scan.js";
import { queryCodex } from "./tools/query-codex.js";
import { getDefenseRecommendation } from "./tools/defense-recommend.js";
import { consultWatcher } from "./tools/watcher-consult.js";
import { getFamilyThreatIntel } from "./tools/family-threat-intel.js";
import { loadPricingConfig, x402PaymentGuard } from "./payment/x402.js";
import { loadAgentRegistration } from "./identity/erc8004.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT =
  process.env["GRIMOIRE_REPO_PATH"] ?? join(__dirname, "../..");
const PORT = parseInt(process.env["PORT"] ?? "8402", 10);

// ─── Initialize ─────────────────────────────────────────────────────

const app = express();
app.use(express.json({ limit: "1mb" }));

const pricing = loadPricingConfig();
const registration = loadAgentRegistration();

let knowledgeBase: KnowledgeChunk[] = [];
function ensureKnowledgeLoaded(): KnowledgeChunk[] {
  if (knowledgeBase.length === 0) {
    knowledgeBase = loadKnowledgeBase(REPO_ROOT);
    console.log(
      `📚 Knowledge base loaded: ${knowledgeBase.length} chunks from ${REPO_ROOT}`,
    );
  }
  return knowledgeBase;
}

// ─── Public Endpoints ───────────────────────────────────────────────

app.get("/", (_req, res) => {
  res.json({
    name: "Grimoire Oracle",
    version: "0.1.0",
    description:
      "Sovereign MCP Server for blockchain security intelligence, powered by the Watcher Tech Blockchain Grimoire",
    tools: Object.entries(pricing.tools).map(([name, config]) => ({
      name,
      price: `${config.price} ${pricing.currency}`,
      description: config.description,
    })),
    endpoints: {
      mcp: "Use stdio transport (see README)",
      api: "/api/tools/:toolName",
      pricing: "/api/pricing",
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
  const chunks = ensureKnowledgeLoaded();
  res.json({
    status: "ok",
    knowledgeChunks: chunks.length,
    tools: Object.keys(pricing.tools).length,
    uptime: process.uptime(),
  });
});

app.get("/api/pricing", (_req, res) => {
  res.json(pricing);
});

// ERC-8004 well-known registration endpoint
app.get("/.well-known/agent.json", (_req, res) => {
  res.json(registration);
});

// ─── Paid Tool Endpoints ────────────────────────────────────────────

// Tool: Audit Scan
app.post("/api/tools/grimoire_audit_scan",
  x402PaymentGuard("grimoire_audit_scan", pricing),
  (req, res) => {
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

  const report = auditScan(sourceCode, contractName);
  const formatted = formatAuditReport(report);

  res.json({
    tool: "grimoire_audit_scan",
    result: {
      summary: report.summary,
      riskLevel: report.riskLevel,
      findingsCount: report.findingsCount,
      formatted,
    },
  });
});

// Tool: Query Codex
app.post("/api/tools/grimoire_query_codex",
  x402PaymentGuard("grimoire_query_codex", pricing),
  (req, res) => {
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

  const chunks = ensureKnowledgeLoaded();
  const result = queryCodex(chunks, query, { maxResults, filterTags });

  res.json({
    tool: "grimoire_query_codex",
    result: {
      query: result.query,
      resultsFound: result.resultsFound,
      sources: result.sources,
      response: result.response,
    },
  });
});

// Tool: Defense Recommend
app.post("/api/tools/grimoire_defense_recommend",
  x402PaymentGuard("grimoire_defense_recommend", pricing),
  (req, res) => {
  const { vulnerability } = req.body as { vulnerability?: string };

  if (!vulnerability) {
    res
      .status(400)
      .json({ error: "vulnerability is required in the request body" });
    return;
  }

  const result = getDefenseRecommendation(vulnerability);

  res.json({
    tool: "grimoire_defense_recommend",
    result: {
      vulnerability: result.vulnerability,
      matchedArchetype: result.matchedArchetype?.name ?? null,
      paradigm: result.paradigm?.name ?? null,
      response: result.fullResponse,
    },
  });
});

// Tool: Watcher Consult
app.post("/api/tools/grimoire_watcher_consult",
  x402PaymentGuard("grimoire_watcher_consult", pricing),
  (req, res) => {
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

  const chunks = ensureKnowledgeLoaded();
  const result = consultWatcher(watcher, question, chunks);

  res.json({
    tool: "grimoire_watcher_consult",
    result: {
      watcher: result.watcher.name,
      domain: result.watcher.domain,
      relatedKnowledge: result.relatedKnowledge,
      analysis: result.analysis,
    },
  });
});

// Tool: Family Threat Intel
app.post("/api/tools/grimoire_family_threat_intel",
  x402PaymentGuard("grimoire_family_threat_intel", pricing),
  (req, res) => {
  const { query } = req.body as { query?: string };

  if (!query) {
    res
      .status(400)
      .json({ error: "query is required in the request body" });
    return;
  }

  const result = getFamilyThreatIntel(query);

  res.json({
    tool: "grimoire_family_threat_intel",
    result: {
      query: result.query,
      matchedFamily: result.matchedFamily?.name ?? null,
      response: result.fullResponse,
    },
  });
});

// ─── Start Server ───────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`🔮 Grimoire Oracle HTTP Server started on port ${PORT}`);
  console.log(`📚 Knowledge base root: ${REPO_ROOT}`);
  console.log(`💰 x402 payments: ${pricing.network} / ${pricing.currency}`);
  console.log(`🏛️  ERC-8004 registration: /.well-known/agent.json`);
  console.log(`\nEndpoints:`);
  console.log(`  GET  http://localhost:${PORT}/`);
  console.log(`  GET  http://localhost:${PORT}/health`);
  console.log(`  GET  http://localhost:${PORT}/api/pricing`);
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
