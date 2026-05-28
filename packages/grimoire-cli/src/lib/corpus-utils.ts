/**
 * Shared corpus file parsing utilities.
 */

import { readFileSync } from "node:fs";
import { extname } from "node:path";
import yaml from "js-yaml";

/**
 * Regex that matches YAML front-matter at the top of a Markdown file.
 * Requires the closing '---' to be followed by a newline, ensuring consistent
 * parsing across files with or without a trailing blank line.
 */
export const FRONTMATTER_RE = /^---\n([\s\S]*?)\n---\n([\s\S]*)/;

export interface ParsedMarkdown {
  frontMatter: Record<string, unknown>;
  body: string;
}

/**
 * Parse a corpus file (Markdown, YAML, or JSON) and return a plain object.
 * Returns null if the file cannot be parsed.
 */
export function parseCorpusFile(filePath: string): Record<string, unknown> | null {
  try {
    const raw = readFileSync(filePath, "utf-8");
    const ext = extname(filePath);

    if (ext === ".md") {
      const parsed = parseMarkdown(raw);
      if (!parsed) return null;
      const data = { ...parsed.frontMatter };
      data["_body"] = parsed.body;
      return data;
    } else if (ext === ".yaml" || ext === ".yml") {
      return yaml.load(raw) as Record<string, unknown>;
    } else if (ext === ".json") {
      return JSON.parse(raw) as Record<string, unknown>;
    }
  } catch {
    // Caller should handle null
  }
  return null;
}

/**
 * Parse the YAML front-matter and body from a Markdown string.
 * Returns null if no front-matter is found.
 */
export function parseMarkdown(raw: string): ParsedMarkdown | null {
  const match = FRONTMATTER_RE.exec(raw);
  if (!match) return null;
  return {
    frontMatter: yaml.load(match[1]) as Record<string, unknown>,
    body: match[2]?.trim() ?? "",
  };
}
