/**
 * init command — scaffold a new grimoire corpus directory structure
 */

import { mkdirSync, writeFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import type { CommandContext } from "../lib/config.js";

const DIRS = ["entries", "entities", "factions", "rituals", "timelines"];

const SAMPLE_CONFIG = {
  openmythos: {
    mode: "mock",
    model: "mythos-v1",
    apiKey: "",
    baseUrl: "https://api.openmythos.dev/v1",
    timeout: 30000,
  },
  corpus: {
    rootDir: "./corpus",
    schemasDir: "./schemas",
    entriesDir: "entries",
    entitiesDir: "entities",
    factionsDir: "factions",
    ritualsDir: "rituals",
    timelinesDir: "timelines",
  },
  generation: {
    seed: 42,
    deterministicMode: true,
    defaultEpistemicStatus: "speculative",
    requireCitationsFor: ["documented"],
    autoLabel: true,
  },
  safety: {
    enableContentFilter: true,
    rejectExploitInstructions: true,
    requireDefensiveFocusOnSecurity: true,
    allowedEpistemicStatuses: ["documented", "contested", "speculative", "fiction"],
  },
  export: {
    outputDir: "./dist/corpus-export",
    formats: ["json"],
    includeSchemas: true,
  },
};

export async function initCommand(ctx: CommandContext): Promise<void> {
  const { config, flags } = ctx;
  const targetDir = flags.find((f) => !f.startsWith("-")) ?? ".";
  const corpusRoot = resolve(targetDir, config.corpus.rootDir);
  const schemasRoot = resolve(targetDir, config.corpus.schemasDir);

  console.log(`[grimoire init] Scaffolding corpus in: ${corpusRoot}`);

  // Create corpus subdirectories
  for (const dir of DIRS) {
    const full = resolve(corpusRoot, dir);
    if (!existsSync(full)) {
      mkdirSync(full, { recursive: true });
      console.log(`  created: ${full}`);
    } else {
      console.log(`  exists:  ${full}`);
    }
  }

  // Create schemas directory
  if (!existsSync(schemasRoot)) {
    mkdirSync(schemasRoot, { recursive: true });
    console.log(`  created: ${schemasRoot}`);
  }

  // Write sample config if not already present
  const configPath = resolve(targetDir, "grimoire.config.json");
  if (!existsSync(configPath)) {
    writeFileSync(configPath, JSON.stringify(SAMPLE_CONFIG, null, 2) + "\n", "utf-8");
    console.log(`  created: ${configPath}`);
  } else {
    console.log(`  exists:  ${configPath} (skipped)`);
  }

  // Write .gitkeep files to preserve empty dirs
  for (const dir of DIRS) {
    const keepFile = resolve(corpusRoot, dir, ".gitkeep");
    if (!existsSync(keepFile)) {
      writeFileSync(keepFile, "", "utf-8");
    }
  }

  console.log("\n[grimoire init] ✓ Done. Next steps:");
  console.log("  1. Edit grimoire.config.json to set your corpus paths and OpenMythos API key");
  console.log("  2. Run: grimoire generate --type entry --prompt 'Your topic'");
  console.log("  3. Run: grimoire validate");
  console.log("\n  See docs/grimoire-cli.md for full usage guide.");
}
