#!/usr/bin/env node
/**
 * Grimoire CLI — Agentic builder for the Watcher Tech Blockchain Grimoire
 *
 * Commands:
 *   init      — scaffold a new grimoire corpus directory
 *   generate  — generate/expand corpus entries using OpenMythos (or mock mode)
 *   validate  — validate all corpus files against JSON schemas
 *   export    — export corpus to flat JSON/YAML/Markdown bundles
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { initCommand } from "./commands/init.js";
import { generateCommand } from "./commands/generate.js";
import { validateCommand } from "./commands/validate.js";
import { exportCommand } from "./commands/export.js";
import type { GrimoireConfig } from "./lib/config.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

const VERSION = "1.0.0";

function loadConfig(configPath?: string): GrimoireConfig {
  const paths = [
    configPath,
    "grimoire.config.json",
    "grimoire.config.yaml",
    resolve(__dirname, "../grimoire.config.json"),
  ].filter(Boolean) as string[];

  for (const p of paths) {
    if (existsSync(p)) {
      try {
        return JSON.parse(readFileSync(p, "utf-8")) as GrimoireConfig;
      } catch {
        console.error(`[grimoire] Failed to parse config at ${p}`);
        process.exit(1);
      }
    }
  }

  // Return sensible defaults if no config found
  return defaultConfig();
}

function defaultConfig(): GrimoireConfig {
  return {
    openmythos: {
      mode: "mock",
      model: "mythos-v1",
      apiKey: "",
      baseUrl: "https://api.openmythos.dev/v1",
      timeout: 30000,
    },
    corpus: {
      rootDir: "../../corpus",
      schemasDir: "../../schemas",
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
      outputDir: "dist/corpus-export",
      formats: ["json"],
      includeSchemas: true,
    },
  };
}

function printHelp(): void {
  console.log(`
Grimoire CLI v${VERSION} — Watcher Tech Blockchain Grimoire Agentic Builder

USAGE
  grimoire <command> [options]

COMMANDS
  init      Scaffold a new grimoire corpus directory structure
  generate  Generate or expand corpus entries using OpenMythos (or mock mode)
  validate  Validate all corpus files against JSON schemas
  export    Export corpus to flat JSON/YAML/Markdown bundles

OPTIONS
  --config <path>   Path to grimoire.config.json (default: ./grimoire.config.json)
  --mock            Force offline/mock mode regardless of config
  --seed <number>   Override random seed for deterministic generation
  --verbose         Enable verbose output
  --help            Show this help message
  --version         Show version number

EXAMPLES
  grimoire init
  grimoire generate --type entity --mock
  grimoire validate
  grimoire export --format json

SAFETY
  All generated content is labeled with epistemic_status and filtered for
  actionable exploit instructions before being written to disk.
  See SAFETY.md for the full content policy.

DOCS
  See docs/grimoire-cli.md for full usage guide and CI integration.
`);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
    printHelp();
    return;
  }

  if (args.includes("--version") || args.includes("-v")) {
    console.log(`grimoire-cli v${VERSION}`);
    return;
  }

  const command = args[0];
  const flags = args.slice(1);

  // Parse global flags
  const configIdx = flags.indexOf("--config");
  const configPath = configIdx !== -1 ? flags[configIdx + 1] : undefined;
  const forceMock = flags.includes("--mock");
  const verbose = flags.includes("--verbose");
  const seedIdx = flags.indexOf("--seed");
  const seedOverride = seedIdx !== -1 ? parseInt(flags[seedIdx + 1], 10) : undefined;

  const config = loadConfig(configPath);

  if (forceMock) config.openmythos.mode = "mock";
  if (seedOverride !== undefined) config.generation.seed = seedOverride;

  const ctx = { config, flags, verbose };

  try {
    switch (command) {
      case "init":
        await initCommand(ctx);
        break;
      case "generate":
        await generateCommand(ctx);
        break;
      case "validate":
        await validateCommand(ctx);
        break;
      case "export":
        await exportCommand(ctx);
        break;
      default:
        console.error(`[grimoire] Unknown command: ${command}`);
        console.error("Run 'grimoire --help' for usage.");
        process.exit(1);
    }
  } catch (err) {
    console.error(`[grimoire] Error: ${(err as Error).message}`);
    if (verbose) console.error(err);
    process.exit(1);
  }
}

main();
