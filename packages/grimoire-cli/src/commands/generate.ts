/**
 * generate command — generate/expand corpus entries using OpenMythos (or mock mode)
 *
 * Safety: All generated content is filtered before being written to disk.
 * Content is NOT auto-committed. Use --commit flag to commit outputs.
 */

import { writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";
import { execFileSync } from "node:child_process";
import yaml from "js-yaml";
import { OpenMythosAdapter } from "../lib/openmythos.js";
import { checkContent, addEpistemicNotice, validateSafetyFields } from "../lib/safety.js";
import type { CommandContext, EpistemicStatus } from "../lib/config.js";
import type { ArtifactType } from "../lib/openmythos.js";

const TYPE_TO_DIR: Record<ArtifactType, string> = {
  entry: "entries",
  entity: "entities",
  faction: "factions",
  ritual: "rituals",
  timeline: "timelines",
};

const TYPE_TO_EXT: Record<ArtifactType, string> = {
  entry: ".md",
  entity: ".yaml",
  faction: ".yaml",
  ritual: ".yaml",
  timeline: ".json",
};

export async function generateCommand(ctx: CommandContext): Promise<void> {
  const { config, flags, verbose } = ctx;

  // Parse generate-specific flags
  const typeIdx = flags.indexOf("--type");
  const type = (typeIdx !== -1 ? flags[typeIdx + 1] : "entry") as ArtifactType;

  const promptIdx = flags.indexOf("--prompt");
  const prompt = promptIdx !== -1 ? flags[promptIdx + 1] : undefined;

  const statusIdx = flags.indexOf("--status");
  const epistemicStatus = (
    statusIdx !== -1 ? flags[statusIdx + 1] : config.generation.defaultEpistemicStatus
  ) as EpistemicStatus;

  const countIdx = flags.indexOf("--count");
  const count = countIdx !== -1 ? parseInt(flags[countIdx + 1], 10) : 1;

  const commitFlag = flags.includes("--commit");
  const dryRun = flags.includes("--dry-run");

  if (!prompt) {
    console.error("[grimoire generate] Error: --prompt <text> is required");
    console.error("  Example: grimoire generate --type entity --prompt 'Gadreel, watcher of weapons'");
    process.exit(1);
  }

  const validTypes: ArtifactType[] = ["entry", "entity", "faction", "ritual", "timeline"];
  if (!validTypes.includes(type)) {
    console.error(`[grimoire generate] Error: --type must be one of: ${validTypes.join(", ")}`);
    process.exit(1);
  }

  const adapter = new OpenMythosAdapter(config.openmythos, config.generation.seed);
  await adapter.initialize();

  const modeLabel = adapter.isMock ? "mock (offline)" : "online";
  console.log(`[grimoire generate] Mode: ${modeLabel} | Type: ${type} | Count: ${count}`);
  console.log(`[grimoire generate] Prompt: "${prompt}"`);

  const corpusRoot = resolve(config.corpus.rootDir);
  const subdir = TYPE_TO_DIR[type];
  const outputDir = join(corpusRoot, subdir);

  if (!existsSync(outputDir) && !dryRun) {
    mkdirSync(outputDir, { recursive: true });
  }

  let successCount = 0;
  let failCount = 0;

  for (let i = 0; i < count; i++) {
    if (verbose || count > 1) console.log(`\n  Generating ${i + 1}/${count}...`);

    const result = await adapter.generate({
      type,
      prompt,
      epistemicStatus,
      seed: config.generation.seed + i,
    });

    // Safety check
    const contentStr = JSON.stringify(result.content);
    const safetyResult = checkContent(contentStr, type === "ritual");
    if (!safetyResult.safe) {
      console.error(
        `  [SAFETY BLOCKED] ${safetyResult.reason}\n  Flagged: ${safetyResult.flaggedPatterns.join(", ")}`
      );
      failCount++;
      continue;
    }

    // Safety field validation
    const safetyErrors = validateSafetyFields(
      result.content as Record<string, unknown>,
      type
    );
    if (safetyErrors.length > 0) {
      console.warn(`  [SAFETY WARNING] Missing required safety fields:`);
      safetyErrors.forEach((e) => console.warn(`    - ${e}`));
    }

    // Serialize content
    const ext = TYPE_TO_EXT[type];
    const filename = `${result.id}${ext}`;
    const outputPath = join(outputDir, filename);

    let serialized: string;
    if (ext === ".md") {
      const frontMatter = {
        id: result.content["id"],
        title: result.content["title"] ?? result.content["name"],
        epistemic_status: result.content["epistemic_status"] ?? epistemicStatus,
        citations: result.content["citations"] ?? [],
        tags: result.content["tags"] ?? [],
        created: result.content["created"],
        generated_by: result.generatedBy,
      };
      const body = (result.content["body"] as string) ?? "";
      serialized = `---\n${yaml.dump(frontMatter).trim()}\n---\n\n${body}\n`;
      serialized = addEpistemicNotice(serialized, epistemicStatus, "markdown");
    } else if (ext === ".yaml") {
      serialized = yaml.dump(result.content, { lineWidth: -1 });
    } else {
      serialized = JSON.stringify(result.content, null, 2) + "\n";
    }

    if (dryRun) {
      console.log(`\n  [DRY RUN] Would write: ${outputPath}`);
      console.log("  " + "-".repeat(60));
      console.log(serialized.split("\n").map((l) => "  " + l).join("\n"));
      successCount++;
    } else {
      writeFileSync(outputPath, serialized, "utf-8");
      console.log(`  ✓ Written: ${outputPath}`);
      successCount++;
    }
  }

  console.log(`\n[grimoire generate] Done. ${successCount} succeeded, ${failCount} blocked by safety filter.`);

  if (!dryRun && !commitFlag && successCount > 0) {
    console.log(
      "\n  ℹ Generated files are NOT committed. Review them and run:\n" +
        "    git add corpus/ && git commit -m 'corpus: add generated entries'\n" +
        "  Or re-run with --commit to commit automatically after generation."
    );
  }

  if (!dryRun && commitFlag && successCount > 0) {
    await autoCommit(config.corpus.rootDir, count, type);
  }
}

async function autoCommit(rootDir: string, count: number, type: string): Promise<void> {
  try {
    execFileSync("git", ["add", rootDir], { stdio: "inherit" });
    execFileSync(
      "git",
      ["commit", "-m", `corpus: add ${count} generated ${type} entries [grimoire-cli]`],
      { stdio: "inherit" }
    );
    console.log("[grimoire generate] ✓ Changes committed.");
  } catch {
    console.warn("[grimoire generate] Auto-commit failed. Commit manually.");
  }
}
