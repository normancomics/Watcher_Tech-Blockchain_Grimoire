/**
 * Grimoire Oracle — Query Codex Tool
 *
 * RAG-style query against the Watcher Tech Blockchain Grimoire knowledge base.
 * Searches the documentation corpus and returns contextual answers.
 */

import type { KnowledgeChunk } from "../knowledge/loader.js";
import { searchKnowledge, formatSearchResults } from "../knowledge/search.js";

export interface CodexQueryResult {
  query: string;
  resultsFound: number;
  response: string;
  sources: string[];
}

/**
 * Queries the Grimoire codex for information.
 */
export function queryCodex(
  chunks: KnowledgeChunk[],
  query: string,
  options?: {
    maxResults?: number;
    filterTags?: string[];
  },
): CodexQueryResult {
  const maxResults = options?.maxResults ?? 5;
  const filterTags = options?.filterTags ?? [];

  const results = searchKnowledge(chunks, query, {
    maxResults,
    tags: filterTags,
  });

  const sources = [...new Set(results.map((r) => r.chunk.source))];
  const response = formatSearchResults(results);

  return {
    query,
    resultsFound: results.length,
    response:
      results.length > 0
        ? [
            `# 📜 Grimoire Codex: "${query}"`,
            "",
            `Found **${results.length}** relevant passages across **${sources.length}** source(s).`,
            "",
            response,
          ].join("\n")
        : `# 📜 Grimoire Codex: "${query}"\n\nNo matching passages found in the Grimoire corpus. Try broadening your query or using different keywords.\n\n**Available knowledge domains:** watchers, sages, families, reentrancy, mev, flash-loan, bridge, zk, liquidity, evm, defense, sigil`,
    sources,
  };
}
