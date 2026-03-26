/**
 * Grimoire Oracle — Knowledge Base Loader
 *
 * Loads the documentation corpus from the Watcher Tech Blockchain Grimoire
 * repository into searchable, indexed knowledge chunks.
 */

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, extname, relative } from "node:path";

export interface KnowledgeChunk {
  id: string;
  source: string;
  section: string;
  content: string;
  tags: string[];
}

/**
 * Recursively discovers all markdown and text files in a directory.
 */
function discoverFiles(dir: string, extensions: string[]): string[] {
  const files: string[] = [];
  try {
    const entries = readdirSync(dir);
    for (const entry of entries) {
      const fullPath = join(dir, entry);
      try {
        const stat = statSync(fullPath);
        if (stat.isDirectory() && !entry.startsWith(".")) {
          files.push(...discoverFiles(fullPath, extensions));
        } else if (stat.isFile() && extensions.includes(extname(entry).toLowerCase())) {
          files.push(fullPath);
        }
      } catch {
        // Skip files we can't access
      }
    }
  } catch {
    // Skip directories we can't access
  }
  return files;
}

/**
 * Tags a chunk based on its content and source path.
 */
function inferTags(source: string, content: string): string[] {
  const tags: string[] = [];
  const lowerContent = content.toLowerCase();
  const lowerSource = source.toLowerCase();

  // Source-based tags
  if (lowerSource.includes("codex")) tags.push("codex");
  if (lowerSource.includes("core")) tags.push("core");
  if (lowerSource.includes("lineage")) tags.push("lineage");
  if (lowerSource.includes("knowledge_tree")) tags.push("knowledge-tree");
  if (lowerSource.includes("languages")) tags.push("languages");
  if (lowerSource.includes("13_families") || lowerSource.includes("families"))
    tags.push("families");
  if (lowerSource.includes("atlantean")) tags.push("atlantean");

  // Content-based tags
  if (lowerContent.includes("reentrancy") || lowerContent.includes("recursive"))
    tags.push("reentrancy");
  if (lowerContent.includes("mev") || lowerContent.includes("reordering"))
    tags.push("mev");
  if (lowerContent.includes("flash loan") || lowerContent.includes("flash_loan"))
    tags.push("flash-loan");
  if (lowerContent.includes("bridge") || lowerContent.includes("portal"))
    tags.push("bridge");
  if (lowerContent.includes("zero-knowledge") || lowerContent.includes("zk"))
    tags.push("zk");
  if (lowerContent.includes("liquidity") || lowerContent.includes("vampire"))
    tags.push("liquidity");
  if (lowerContent.includes("opcode") || lowerContent.includes("evm"))
    tags.push("evm");
  if (lowerContent.includes("defense") || lowerContent.includes("guard"))
    tags.push("defense");
  if (lowerContent.includes("watcher")) tags.push("watcher");
  if (lowerContent.includes("sage")) tags.push("sage");
  if (lowerContent.includes("sigil")) tags.push("sigil");

  return [...new Set(tags)];
}

/**
 * Splits file content into meaningful chunks (~1500 chars each)
 * using heading-based splitting for markdown, paragraph splitting for text.
 */
function splitIntoChunks(
  filePath: string,
  content: string,
  repoRoot: string,
): KnowledgeChunk[] {
  const relativePath = relative(repoRoot, filePath);
  const chunks: KnowledgeChunk[] = [];
  const ext = extname(filePath).toLowerCase();

  if (ext === ".md") {
    // Split by headings
    const sections = content.split(/^(#{1,3}\s+.+)$/m);
    let currentSection = "Introduction";
    let currentContent = "";

    for (const part of sections) {
      if (/^#{1,3}\s+/.test(part)) {
        // Save previous section
        if (currentContent.trim().length > 50) {
          chunks.push({
            id: `${relativePath}:${chunks.length}`,
            source: relativePath,
            section: currentSection,
            content: currentContent.trim(),
            tags: inferTags(relativePath, currentContent),
          });
        }
        currentSection = part.replace(/^#+\s+/, "").trim();
        currentContent = "";
      } else {
        currentContent += part;
      }
    }
    // Final section
    if (currentContent.trim().length > 50) {
      chunks.push({
        id: `${relativePath}:${chunks.length}`,
        source: relativePath,
        section: currentSection,
        content: currentContent.trim(),
        tags: inferTags(relativePath, currentContent),
      });
    }
  } else {
    // For .txt files, split by double newlines or by ~1500 char boundaries
    const paragraphs = content.split(/\n{2,}/);
    let buffer = "";
    let sectionIdx = 0;

    for (const para of paragraphs) {
      if (buffer.length + para.length > 1500 && buffer.length > 50) {
        chunks.push({
          id: `${relativePath}:${sectionIdx}`,
          source: relativePath,
          section: `Section ${sectionIdx + 1}`,
          content: buffer.trim(),
          tags: inferTags(relativePath, buffer),
        });
        buffer = "";
        sectionIdx++;
      }
      buffer += para + "\n\n";
    }
    if (buffer.trim().length > 50) {
      chunks.push({
        id: `${relativePath}:${sectionIdx}`,
        source: relativePath,
        section: `Section ${sectionIdx + 1}`,
        content: buffer.trim(),
        tags: inferTags(relativePath, buffer),
      });
    }
  }

  return chunks;
}

/**
 * Loads the entire Grimoire knowledge base from the repository root.
 */
export function loadKnowledgeBase(repoRoot: string): KnowledgeChunk[] {
  const allChunks: KnowledgeChunk[] = [];
  const searchDirs = [
    join(repoRoot, "docs"),
    join(repoRoot, "13_Families"),
    join(repoRoot, "Atlantean"),
    join(repoRoot, "contracts"),
  ];

  // Also load the Structure file directly
  const structurePath = join(repoRoot, "Structure");
  try {
    const content = readFileSync(structurePath, "utf-8");
    allChunks.push(...splitIntoChunks(structurePath, content, repoRoot));
  } catch {
    // Structure file may not exist
  }

  // Load README
  const readmePath = join(repoRoot, "README.md");
  try {
    const content = readFileSync(readmePath, "utf-8");
    allChunks.push(...splitIntoChunks(readmePath, content, repoRoot));
  } catch {
    // README may not exist
  }

  for (const dir of searchDirs) {
    const files = discoverFiles(dir, [".md", ".txt", ".sol"]);
    for (const file of files) {
      try {
        const content = readFileSync(file, "utf-8");
        allChunks.push(...splitIntoChunks(file, content, repoRoot));
      } catch {
        // Skip unreadable files
      }
    }
  }

  return allChunks;
}
