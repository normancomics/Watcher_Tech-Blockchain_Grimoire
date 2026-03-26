/**
 * Grimoire Oracle — Knowledge Search Engine
 *
 * Simple but effective TF-IDF-inspired search over the knowledge base
 * with tag boosting and section-aware ranking.
 */

import type { KnowledgeChunk } from "./loader.js";

export interface SearchResult {
  chunk: KnowledgeChunk;
  score: number;
  matchedTerms: string[];
}

/**
 * Tokenizes text into searchable terms.
 */
function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 2);
}

/**
 * Calculates term frequency for a set of tokens.
 */
function termFrequency(tokens: string[]): Map<string, number> {
  const freq = new Map<string, number>();
  for (const token of tokens) {
    freq.set(token, (freq.get(token) ?? 0) + 1);
  }
  return freq;
}

/**
 * Searches the knowledge base for chunks matching the query.
 */
export function searchKnowledge(
  chunks: KnowledgeChunk[],
  query: string,
  options: {
    maxResults?: number;
    tags?: string[];
    minScore?: number;
  } = {},
): SearchResult[] {
  const { maxResults = 10, tags = [], minScore = 0.01 } = options;
  const queryTokens = tokenize(query);
  const queryTerms = termFrequency(queryTokens);

  const results: SearchResult[] = [];

  for (const chunk of chunks) {
    const contentTokens = tokenize(chunk.content + " " + chunk.section);
    const contentTerms = termFrequency(contentTokens);

    let score = 0;
    const matchedTerms: string[] = [];

    // Term matching score
    for (const [term, queryCount] of queryTerms) {
      const contentCount = contentTerms.get(term) ?? 0;
      if (contentCount > 0) {
        // TF-IDF inspired: term frequency weighted by inverse document length
        const tf = contentCount / contentTokens.length;
        score += tf * queryCount;
        matchedTerms.push(term);
      }
    }

    // Boost for tag matches
    if (tags.length > 0) {
      const tagMatches = tags.filter((t) => chunk.tags.includes(t));
      score += tagMatches.length * 0.1;
    }

    // Boost for query tag matches (query terms that are also tags)
    for (const token of queryTokens) {
      if (chunk.tags.includes(token)) {
        score += 0.05;
      }
    }

    // Boost for section title match
    const sectionTokens = tokenize(chunk.section);
    for (const token of queryTokens) {
      if (sectionTokens.includes(token)) {
        score += 0.08;
      }
    }

    if (score >= minScore && matchedTerms.length > 0) {
      results.push({ chunk, score, matchedTerms });
    }
  }

  // Sort by score descending
  results.sort((a, b) => b.score - a.score);

  return results.slice(0, maxResults);
}

/**
 * Formats search results into a readable response.
 */
export function formatSearchResults(results: SearchResult[]): string {
  if (results.length === 0) {
    return "No matching knowledge found in the Grimoire corpus.";
  }

  const formatted = results.map((r, i) => {
    const tags = r.chunk.tags.length > 0 ? ` [${r.chunk.tags.join(", ")}]` : "";
    const preview =
      r.chunk.content.length > 500
        ? r.chunk.content.substring(0, 500) + "..."
        : r.chunk.content;

    return [
      `### Result ${i + 1} (score: ${r.score.toFixed(3)})`,
      `**Source:** ${r.chunk.source} → ${r.chunk.section}${tags}`,
      `**Matched terms:** ${r.matchedTerms.join(", ")}`,
      "",
      preview,
    ].join("\n");
  });

  return formatted.join("\n\n---\n\n");
}
