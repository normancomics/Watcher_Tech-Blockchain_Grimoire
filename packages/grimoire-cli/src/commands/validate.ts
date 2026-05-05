/**
 * validate command — validate all corpus files against JSON schemas
 * and safety policy requirements.
 */

import { readdirSync, readFileSync, existsSync } from "node:fs";
import { resolve, join, extname } from "node:path";
import yaml from "js-yaml";
import { validateAgainstSchema, schemaForCorpusPath } from "../lib/schema-validator.js";
import { validateSafetyFields } from "../lib/safety.js";
import type { CommandContext } from "../lib/config.js";

interface FileResult {
  path: string;
  valid: boolean;
  errors: string[];
  warnings: string[];
}

export async function validateCommand(ctx: CommandContext): Promise<void> {
  const { config, flags, verbose } = ctx;

  const corpusRoot = resolve(config.corpus.rootDir);
  const schemasRoot = resolve(config.corpus.schemasDir);

  if (!existsSync(corpusRoot)) {
    console.error(`[grimoire validate] Corpus directory not found: ${corpusRoot}`);
    console.error("  Run 'grimoire init' to scaffold the corpus structure.");
    process.exit(1);
  }

  if (!existsSync(schemasRoot)) {
    console.error(`[grimoire validate] Schemas directory not found: ${schemasRoot}`);
    process.exit(1);
  }

  const onlyPath = flags.find((f) => !f.startsWith("-"));
  const results: FileResult[] = [];

  const subdirs = [
    config.corpus.entriesDir,
    config.corpus.entitiesDir,
    config.corpus.factionsDir,
    config.corpus.ritualsDir,
    config.corpus.timelinesDir,
  ];

  for (const subdir of subdirs) {
    const dirPath = join(corpusRoot, subdir);
    if (!existsSync(dirPath)) continue;

    const files = readdirSync(dirPath).filter(
      (f) => !f.startsWith(".") && [".md", ".yaml", ".yml", ".json"].includes(extname(f))
    );

    for (const file of files) {
      const filePath = join(dirPath, file);
      if (onlyPath && !filePath.includes(onlyPath)) continue;

      const result = validateFile(filePath, schemasRoot, verbose);
      results.push(result);
    }
  }

  // Print results
  let passCount = 0;
  let failCount = 0;

  for (const r of results) {
    const status = r.valid && r.errors.length === 0 ? "✓" : "✗";
    const label = r.valid && r.errors.length === 0 ? "PASS" : "FAIL";

    console.log(`  ${status} [${label}] ${r.path}`);

    if (r.errors.length > 0) {
      failCount++;
      r.errors.forEach((e) => console.log(`        ERROR: ${e}`));
    } else {
      passCount++;
    }

    if (r.warnings.length > 0) {
      r.warnings.forEach((w) => console.log(`        WARN:  ${w}`));
    }
  }

  console.log(
    `\n[grimoire validate] ${passCount} passed, ${failCount} failed (${results.length} total files)`
  );

  if (failCount > 0) {
    process.exit(1);
  }
}

function validateFile(filePath: string, schemasRoot: string, verbose: boolean): FileResult {
  const result: FileResult = { path: filePath, valid: true, errors: [], warnings: [] };
  const ext = extname(filePath);

  let data: Record<string, unknown>;

  try {
    const raw = readFileSync(filePath, "utf-8");

    if (ext === ".md") {
      // Parse YAML front-matter only
      const match = raw.match(/^---\n([\s\S]*?)\n---/);
      if (!match) {
        result.errors.push("Missing YAML front-matter (expected ---...--- block at top of file)");
        result.valid = false;
        return result;
      }
      data = yaml.load(match[1]) as Record<string, unknown>;
    } else if (ext === ".yaml" || ext === ".yml") {
      data = yaml.load(raw) as Record<string, unknown>;
    } else if (ext === ".json") {
      data = JSON.parse(raw) as Record<string, unknown>;
    } else {
      result.warnings.push(`Skipping unsupported file type: ${ext}`);
      return result;
    }
  } catch (err) {
    result.errors.push(`Parse error: ${(err as Error).message}`);
    result.valid = false;
    return result;
  }

  // Schema validation
  try {
    const schemaPath = schemaForCorpusPath(filePath, schemasRoot);
    const schemaResult = validateAgainstSchema(data, schemaPath);
    if (!schemaResult.valid) {
      result.valid = false;
      result.errors.push(...schemaResult.errors);
    }
  } catch (err) {
    result.warnings.push(`Schema lookup: ${(err as Error).message}`);
  }

  // Safety field validation
  const artifactType = inferArtifactType(filePath);
  if (artifactType) {
    const safetyErrors = validateSafetyFields(data, artifactType);
    if (safetyErrors.length > 0) {
      result.valid = false;
      result.errors.push(...safetyErrors.map((e) => `[SAFETY] ${e}`));
    }
  }

  return result;
}

function inferArtifactType(
  filePath: string
): "entry" | "entity" | "faction" | "ritual" | "timeline" | null {
  if (filePath.includes("/entries/")) return "entry";
  if (filePath.includes("/entities/")) return "entity";
  if (filePath.includes("/factions/")) return "faction";
  if (filePath.includes("/rituals/")) return "ritual";
  if (filePath.includes("/timelines/")) return "timeline";
  return null;
}
