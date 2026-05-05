/**
 * export command — export the corpus to flat bundles (JSON, YAML, Markdown)
 *
 * Outputs are written to the configured export directory.
 * Does NOT auto-commit. Use git to track exported bundles.
 */

import { readdirSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, join, extname, basename } from "node:path";
import yaml from "js-yaml";
import { parseCorpusFile } from "../lib/corpus-utils.js";
import type { CommandContext } from "../lib/config.js";

interface ExportBundle {
  entries: Record<string, unknown>[];
  entities: Record<string, unknown>[];
  factions: Record<string, unknown>[];
  rituals: Record<string, unknown>[];
  timelines: Record<string, unknown>[];
  meta: {
    exportedAt: string;
    totalDocuments: number;
    schemaVersion: string;
  };
}

export async function exportCommand(ctx: CommandContext): Promise<void> {
  const { config, flags, verbose } = ctx;

  const formatIdx = flags.indexOf("--format");
  const formatOverride = formatIdx !== -1 ? flags[formatIdx + 1] : undefined;
  const formats = formatOverride
    ? [formatOverride as "json" | "yaml" | "markdown"]
    : config.export.formats;

  const corpusRoot = resolve(config.corpus.rootDir);
  const outputRoot = resolve(config.export.outputDir);

  if (!existsSync(corpusRoot)) {
    console.error(`[grimoire export] Corpus not found: ${corpusRoot}`);
    process.exit(1);
  }

  mkdirSync(outputRoot, { recursive: true });
  console.log(`[grimoire export] Exporting corpus to: ${outputRoot}`);

  const bundle: ExportBundle = {
    entries: [],
    entities: [],
    factions: [],
    rituals: [],
    timelines: [],
    meta: {
      exportedAt: new Date().toISOString(),
      totalDocuments: 0,
      schemaVersion: "1.0.0",
    },
  };

  const subdirMap: Array<{ subdir: string; key: keyof Omit<ExportBundle, "meta"> }> = [
    { subdir: config.corpus.entriesDir, key: "entries" },
    { subdir: config.corpus.entitiesDir, key: "entities" },
    { subdir: config.corpus.factionsDir, key: "factions" },
    { subdir: config.corpus.ritualsDir, key: "rituals" },
    { subdir: config.corpus.timelinesDir, key: "timelines" },
  ];

  for (const { subdir, key } of subdirMap) {
    const dirPath = join(corpusRoot, subdir);
    if (!existsSync(dirPath)) continue;

    const files = readdirSync(dirPath).filter(
      (f) => !f.startsWith(".") && [".md", ".yaml", ".yml", ".json"].includes(extname(f))
    );

    for (const file of files) {
      const filePath = join(dirPath, file);
      const parsed = parseCorpusFileForExport(filePath);
      if (parsed) {
        bundle[key].push(parsed);
        if (verbose) console.log(`  loaded: ${filePath}`);
      }
    }
  }

  const total =
    bundle.entries.length +
    bundle.entities.length +
    bundle.factions.length +
    bundle.rituals.length +
    bundle.timelines.length;

  bundle.meta.totalDocuments = total;

  // Write exports
  for (const format of formats) {
    const outPath = join(outputRoot, `grimoire-corpus.${format === "markdown" ? "md" : format}`);

    if (format === "json") {
      writeFileSync(outPath, JSON.stringify(bundle, null, 2) + "\n", "utf-8");
    } else if (format === "yaml") {
      writeFileSync(outPath, yaml.dump(bundle, { lineWidth: -1 }), "utf-8");
    } else if (format === "markdown") {
      writeFileSync(outPath, bundleToMarkdown(bundle), "utf-8");
    }

    console.log(`  ✓ Written: ${outPath}`);
  }

  console.log(`\n[grimoire export] Done. ${total} documents exported in format(s): ${formats.join(", ")}`);
}

function parseCorpusFileForExport(filePath: string): Record<string, unknown> | null {
  const parsed = parseCorpusFile(filePath);
  if (!parsed) return null;
  // Add source file annotation for export metadata
  parsed["_source_file"] = basename(filePath);
  return parsed;
}

function bundleToMarkdown(bundle: ExportBundle): string {
  const lines: string[] = [
    "# Grimoire Corpus Export",
    "",
    `> Exported: ${bundle.meta.exportedAt}`,
    `> Total documents: ${bundle.meta.totalDocuments}`,
    `> Schema version: ${bundle.meta.schemaVersion}`,
    "",
    "---",
    "",
  ];

  const sections: Array<{ title: string; items: Record<string, unknown>[] }> = [
    { title: "## Entries", items: bundle.entries },
    { title: "## Entities", items: bundle.entities },
    { title: "## Factions", items: bundle.factions },
    { title: "## Rituals", items: bundle.rituals },
    { title: "## Timelines", items: bundle.timelines },
  ];

  for (const { title, items } of sections) {
    if (items.length === 0) continue;
    lines.push(title, "");
    for (const item of items) {
      const name = (item["title"] ?? item["name"] ?? item["id"] ?? "Untitled") as string;
      const status = (item["epistemic_status"] ?? "unknown") as string;
      const src = (item["_source_file"] ?? "") as string;
      lines.push(`### ${name}`);
      lines.push(`*Epistemic status: ${status}* | Source: \`${src}\``);
      lines.push("");
      if (item["description"]) lines.push(`${item["description"]}`, "");
      if (item["_body"]) lines.push(`${item["_body"]}`, "");
      lines.push("---", "");
    }
  }

  return lines.join("\n");
}
