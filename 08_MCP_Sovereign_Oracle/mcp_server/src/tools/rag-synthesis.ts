/**
 * Grimoire Oracle — RAG Synthesis Tool
 *
 * Synthesizes multi-document answers from the Grimoire knowledge base,
 * producing responses with full citation chains and provenance tracking.
 *
 * Unlike grimoire_query_codex (which returns raw search results), this
 * tool performs a higher-order synthesis pass: it retrieves multiple
 * relevant knowledge chunks, identifies cross-document relationships,
 * and weaves them into a coherent, cited narrative response.
 *
 * Esoteric Context:
 *   The "synthesis" process mirrors the Seven Pillars of Wisdom (Proverbs 9:1):
 *   multiple streams of ancient knowledge are drawn together and distilled
 *   into a single unified truth. Each source in the citation chain represents
 *   one pillar of the Grimoire corpus.
 *
 * Features:
 *   - Multi-pass retrieval (broad → focused)
 *   - Cross-reference detection (identifies overlapping themes)
 *   - Citation chain with source provenance
 *   - Confidence scoring per source
 *   - Support for domain-filtered synthesis (Watcher domains, exploit archetypes)
 */

import type { KnowledgeChunk } from "../knowledge/loader.js";
import { searchKnowledge, type SearchResult } from "../knowledge/search.js";

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SynthesisRequest {
  /** Primary synthesis question or topic */
  query: string;
  /** Optional secondary queries for multi-angle synthesis */
  subQueries?: string[];
  /** Maximum sources to cite (1–20) */
  maxSources?: number;
  /** Knowledge tag filters (narrows corpus) */
  filterTags?: string[];
  /** If true, include cross-reference analysis */
  crossReference?: boolean;
  /** Synthesis depth: 'brief' | 'standard' | 'deep' */
  depth?: "brief" | "standard" | "deep";
}

export interface CitationEntry {
  sourceFile: string;
  section: string;
  relevanceScore: number;
  excerpt: string;
  tags: string[];
}

export interface SynthesisResult {
  query: string;
  synthesisBody: string;
  citations: CitationEntry[];
  crossReferences: string[];
  confidenceScore: number;   // 0–1
  pillarsActivated: number;  // out of 7 (Seven Pillars of Wisdom)
  fullResponse: string;
}

// ─── Cross-Reference Detector ─────────────────────────────────────────────────

/**
 * Identifies overlapping themes across retrieved chunks to surface
 * conceptual bridges (cross-references) between sources.
 */
function detectCrossReferences(results: SearchResult[]): string[] {
  if (results.length < 2) return [];

  const crossRefs: string[] = [];
  const tagSets = results.map((r) => new Set(r.chunk.tags));

  // Find pairs of sources sharing tags — these are cross-references
  for (let i = 0; i < results.length; i++) {
    for (let j = i + 1; j < results.length; j++) {
      const a = tagSets[i]!;
      const b = tagSets[j]!;
      const shared = [...a].filter((t) => b.has(t));
      if (shared.length > 0) {
        const nameA = results[i]!.chunk.section || results[i]!.chunk.source;
        const nameB = results[j]!.chunk.section || results[j]!.chunk.source;
        crossRefs.push(
          `↔ "${nameA}" ↔ "${nameB}" — shared themes: [${shared.join(", ")}]`,
        );
      }
    }
  }

  // Deduplicate
  return [...new Set(crossRefs)].slice(0, 10);
}

// ─── Synthesis Weaver ─────────────────────────────────────────────────────────

/**
 * Weaves multiple knowledge chunks into a coherent narrative synthesis.
 * Ordered by relevance score; each chunk contributes a paragraph.
 */
function weaveSynthesis(
  query: string,
  results: SearchResult[],
  depth: "brief" | "standard" | "deep",
): string {
  if (results.length === 0) {
    return `No knowledge found in the Grimoire corpus for query: "${query}". ` +
      "Consider broadening your query or removing tag filters.";
  }

  const maxChunks = depth === "brief" ? 3 : depth === "standard" ? 6 : results.length;
  const selected  = results.slice(0, maxChunks);

  const paragraphs: string[] = [];

  // Opening synthesis statement
  paragraphs.push(
    `## Grimoire Synthesis: ${query}\n\n` +
    `The following synthesis draws from ${selected.length} source${selected.length > 1 ? "s" : ""} ` +
    `within the Watcher Tech Blockchain Grimoire knowledge base, ordered by relevance.\n`,
  );

  // Body — one paragraph per source
  for (let i = 0; i < selected.length; i++) {
    const result = selected[i]!;
    const chunk  = result.chunk;
    const label  = `[${i + 1}]`;
    const header = chunk.section ? `*${chunk.section}*` : `*${chunk.source}*`;

    // Trim content to a meaningful excerpt (max 600 chars)
    const excerpt = chunk.content.trim().slice(0, 600);
    const truncated = chunk.content.length > 600 ? "…" : "";

    paragraphs.push(
      `### Source ${label} — ${header}\n` +
      `> Relevance: ${(result.score * 100).toFixed(1)}% | Tags: ${chunk.tags.join(", ") || "none"}\n\n` +
      `${excerpt}${truncated}\n`,
    );
  }

  if (depth === "deep" && selected.length > 1) {
    paragraphs.push(
      "---\n### Synthesis Commentary\n\n" +
      "Across the retrieved passages, several convergent themes emerge:\n\n" +
      selected
        .flatMap((r) => r.matchedTerms)
        .filter((t, i, a) => a.indexOf(t) === i)
        .slice(0, 12)
        .map((term) => `- **${term}** — appears across multiple Grimoire sources`)
        .join("\n"),
    );
  }

  return paragraphs.join("\n");
}

// ─── Main Synthesis Function ──────────────────────────────────────────────────

/**
 * Performs multi-document RAG synthesis over the Grimoire knowledge base.
 */
export function synthesizeKnowledge(
  chunks: KnowledgeChunk[],
  request: SynthesisRequest,
): SynthesisResult {
  const {
    query,
    subQueries    = [],
    maxSources    = 8,
    filterTags    = [],
    crossReference = true,
    depth         = "standard",
  } = request;

  // ── Pass 1: Primary query retrieval ────────────────────────────────────────
  const primaryResults = searchKnowledge(chunks, query, {
    maxResults: maxSources,
    tags: filterTags,
    minScore: 0.01,
  });

  // ── Pass 2: Sub-query retrieval (multi-angle synthesis) ────────────────────
  const secondaryResults: SearchResult[] = [];
  for (const sq of subQueries.slice(0, 3)) {   // max 3 sub-queries
    const sqResults = searchKnowledge(chunks, sq, {
      maxResults: Math.ceil(maxSources / 2),
      tags: filterTags,
      minScore: 0.01,
    });
    secondaryResults.push(...sqResults);
  }

  // ── Merge and deduplicate by chunk ID ─────────────────────────────────────
  const seen = new Set<string>();
  const allResults: SearchResult[] = [];
  for (const r of [...primaryResults, ...secondaryResults]) {
    if (!seen.has(r.chunk.id)) {
      seen.add(r.chunk.id);
      allResults.push(r);
    }
  }

  // Sort by score descending
  allResults.sort((a, b) => b.score - a.score);
  const finalResults = allResults.slice(0, maxSources);

  // ── Cross-reference analysis ───────────────────────────────────────────────
  const crossRefs = crossReference ? detectCrossReferences(finalResults) : [];

  // ── Build citations ────────────────────────────────────────────────────────
  const citations: CitationEntry[] = finalResults.map((r) => ({
    sourceFile:     r.chunk.source,
    section:        r.chunk.section,
    relevanceScore: r.score,
    excerpt:        r.chunk.content.trim().slice(0, 200),
    tags:           r.chunk.tags,
  }));

  // ── Confidence score: average of top-3 result scores (capped at 1.0) ──────
  const top3     = finalResults.slice(0, 3);
  const avgScore = top3.length > 0
    ? top3.reduce((acc, r) => acc + r.score, 0) / top3.length
    : 0;
  const confidence = Math.min(avgScore * 5, 1.0);  // scale to 0–1 range

  // ── Seven Pillars: count distinct knowledge domains activated ─────────────
  const activatedDomains = new Set(finalResults.flatMap((r) => r.chunk.tags));
  const pillars = [
    "watcher", "sage", "families", "reentrancy", "mev", "flash-loan", "defense",
  ];
  const pillarsActivated = pillars.filter((p) => activatedDomains.has(p)).length;

  // ── Weave synthesis body ───────────────────────────────────────────────────
  const synthesisBody = weaveSynthesis(query, finalResults, depth);

  // ── Full formatted response ────────────────────────────────────────────────
  const fullResponse = formatSynthesisResponse({
    query,
    synthesisBody,
    citations,
    crossRefs,
    confidence,
    pillarsActivated,
    depth,
  });

  return {
    query,
    synthesisBody,
    citations,
    crossReferences: crossRefs,
    confidenceScore:  confidence,
    pillarsActivated,
    fullResponse,
  };
}

// ─── Response Formatter ───────────────────────────────────────────────────────

function formatSynthesisResponse(params: {
  query: string;
  synthesisBody: string;
  citations: CitationEntry[];
  crossRefs: string[];
  confidence: number;
  pillarsActivated: number;
  depth: string;
}): string {
  const lines: string[] = [
    "📜 GRIMOIRE RAG SYNTHESIS",
    "═══════════════════════════════════════════════════════════",
    "",
    `Query        : "${params.query}"`,
    `Sources      : ${params.citations.length}`,
    `Confidence   : ${(params.confidence * 100).toFixed(1)}%`,
    `Pillars (7)  : ${params.pillarsActivated} activated`,
    `Depth        : ${params.depth}`,
    "",
    "═══════════════════════════════════════════════════════════",
    "",
    params.synthesisBody,
  ];

  if (params.crossRefs.length > 0) {
    lines.push(
      "",
      "---",
      "## Cross-References Detected",
      ...params.crossRefs,
    );
  }

  lines.push(
    "",
    "---",
    "## Citation Index",
    "",
    ...params.citations.map((c, i) =>
      `[${i + 1}] **${c.section || c.sourceFile}** — score: ${(c.relevanceScore * 100).toFixed(1)}% | ${c.tags.join(", ")}`,
    ),
    "",
    "═══════════════════════════════════════════════════════════",
    "Watcher Tech Blockchain Grimoire — normancomics.eth 2026",
  );

  return lines.join("\n");
}
