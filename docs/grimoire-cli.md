# Grimoire CLI — Usage Guide

The **Grimoire Builder CLI** (`packages/grimoire-cli`) is an agentic command-line tool that uses **@kyegomez/OpenMythos** (with offline mock mode) to generate, validate, and export corpus entries for the Watcher Tech Blockchain Grimoire.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Commands](#commands)
   - [init](#init)
   - [generate](#generate)
   - [validate](#validate)
   - [export](#export)
4. [Configuration](#configuration)
5. [OpenMythos Integration](#openmythos-integration)
6. [Safety Rails](#safety-rails)
7. [CI Integration](#ci-integration)

---

## Quick Start

```bash
cd packages/grimoire-cli
npm install
npm run build

# Validate existing corpus (no API key needed)
node dist/index.js validate

# Generate a mock entity (offline, deterministic)
node dist/index.js generate --type entity --prompt "Penemue, teacher of writing" --mock --dry-run

# Export the full corpus to JSON
node dist/index.js export --format json
```

---

## Installation

### Prerequisites

- **Node.js** 18+
- **npm** 9+ (or compatible package manager)

### Steps

```bash
# From the repo root
cd packages/grimoire-cli
npm install
npm run build
```

This compiles TypeScript to `dist/` and makes the CLI available as:

```bash
node dist/index.js <command>
```

Optionally, install globally for the `grimoire` command:

```bash
npm install -g .
grimoire --help
```

---

## Commands

### `init`

Scaffold a new corpus directory structure.

```bash
grimoire init [target-directory]
```

**What it does:**
- Creates `corpus/{entries,entities,factions,rituals,timelines}/` directories
- Creates a `schemas/` directory
- Writes a default `grimoire.config.json`

**Example:**
```bash
grimoire init .
# → corpus/entries/
# → corpus/entities/
# → corpus/factions/
# → corpus/rituals/
# → corpus/timelines/
# → grimoire.config.json
```

---

### `generate`

Generate corpus entries using OpenMythos (or mock mode).

```bash
grimoire generate --type <type> --prompt <text> [options]
```

**Options:**

| Flag | Description | Default |
|------|-------------|---------|
| `--type` | Artifact type: `entry`, `entity`, `faction`, `ritual`, `timeline` | `entry` |
| `--prompt` | Generation prompt (required) | — |
| `--status` | `epistemic_status`: `documented`, `contested`, `speculative`, `fiction` | `speculative` |
| `--count` | Number of artifacts to generate | `1` |
| `--mock` | Force offline mock mode | from config |
| `--seed` | Override PRNG seed for deterministic output | `42` |
| `--dry-run` | Preview output without writing to disk | false |
| `--commit` | Auto-commit generated files after writing | false |

**Examples:**

```bash
# Generate a mock entity (dry run, no files written)
grimoire generate --type entity --prompt "Azazel, forger of weapons" --mock --dry-run

# Generate a speculative timeline (writes to corpus/timelines/)
grimoire generate --type timeline --prompt "From Enoch to Ethereum: key events" --status speculative

# Generate with a specific seed for reproducible output
grimoire generate --type faction --prompt "The Rosicrucian protocols" --seed 1337

# Generate and auto-commit
grimoire generate --type entry --prompt "Moon phases and MEV patterns" --commit
```

**Safety behavior:**
- All output is filtered through `src/lib/safety.ts` before being written
- Content matching exploit-instruction patterns is **blocked**
- Content is **not** auto-committed unless `--commit` is passed
- All generated files include `epistemic_status` (defaults to `speculative` in online mode, `fiction` in mock mode)

---

### `validate`

Validate all corpus files against JSON schemas and safety policy.

```bash
grimoire validate [path-filter]
```

**What it validates:**
- **Schema compliance**: all required fields present and correct types
- **Safety fields**: `epistemic_status` present, `citations` array present, `documented` entries have ≥1 citation
- **Ritual safety**: `defensive_focus: true` required

**Examples:**

```bash
# Validate all corpus files
grimoire validate

# Validate only entity files
grimoire validate entities/
```

**Exit codes:**
- `0` — all files pass
- `1` — one or more files fail validation

---

### `export`

Export the full corpus to a flat bundle file.

```bash
grimoire export [options]
```

**Options:**

| Flag | Description | Default |
|------|-------------|---------|
| `--format` | Output format: `json`, `yaml`, `markdown` | from config |

**Examples:**

```bash
# Export as JSON (default)
grimoire export

# Export as YAML
grimoire export --format yaml

# Export as Markdown
grimoire export --format markdown
```

**Output location:** `dist/corpus-export/grimoire-corpus.<format>`

> ℹ The export output directory is `.gitignore`d by default. Commit exports explicitly when needed.

---

## Configuration

The CLI looks for `grimoire.config.json` in this order:
1. Path from `--config` flag
2. `./grimoire.config.json` (current directory)
3. Built-in defaults

### Full configuration reference

```json
{
  "openmythos": {
    "mode": "mock",           // "mock" | "online"
    "model": "mythos-v1",     // OpenMythos model name
    "apiKey": "",             // Set OPENMYTHOS_API_KEY env var instead
    "baseUrl": "https://api.openmythos.dev/v1",
    "timeout": 30000
  },
  "corpus": {
    "rootDir": "../../corpus",
    "schemasDir": "../../schemas",
    "entriesDir": "entries",
    "entitiesDir": "entities",
    "factionsDir": "factions",
    "ritualsDir": "rituals",
    "timelinesDir": "timelines"
  },
  "generation": {
    "seed": 42,
    "deterministicMode": true,
    "defaultEpistemicStatus": "speculative",
    "requireCitationsFor": ["documented"],
    "autoLabel": true
  },
  "safety": {
    "enableContentFilter": true,
    "rejectExploitInstructions": true,
    "requireDefensiveFocusOnSecurity": true,
    "allowedEpistemicStatuses": ["documented", "contested", "speculative", "fiction"]
  },
  "export": {
    "outputDir": "../../dist/corpus-export",
    "formats": ["json"],
    "includeSchemas": true
  }
}
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `OPENMYTHOS_API_KEY` | API key for online mode (overrides `apiKey` in config) |

---

## OpenMythos Integration

The CLI uses `@kyegomez/OpenMythos` as an **optional dependency**. When not installed, it automatically falls back to **mock mode**.

### Online mode

1. Install the library: `npm install @kyegomez/openmythos`
2. Set your API key: `export OPENMYTHOS_API_KEY=your-key`
3. Set mode in config: `"openmythos": { "mode": "online" }`
4. Run: `grimoire generate --type entry --prompt "..."`

### Mock mode (default, no API key needed)

Mock mode uses a seeded PRNG to generate deterministic placeholder content that:
- Conforms to all corpus schemas
- Includes required `epistemic_status` and `citations` fields
- Can be reviewed and replaced with real content

```bash
grimoire generate --type entity --prompt "Tamiel, teacher of astronomy" --mock
```

### Adapter location

`packages/grimoire-cli/src/lib/openmythos.ts` — implements the adapter pattern:
- Tries to dynamically `import('@kyegomez/openmythos')` at runtime
- Falls back to mock if not installed
- Exposes a unified `OpenMythosAdapter` class

---

## Safety Rails

See [SAFETY.md](../SAFETY.md) for the full content policy. The CLI enforces:

### 1. Content filter (`src/lib/safety.ts`)

Blocks content containing:
- Numbered exploit step sequences
- Hardcoded private keys or mnemonic phrases
- "How to exploit" instructional patterns
- `selfdestruct` calls targeting real addresses

### 2. Defensive framing requirement

Security-related content (detected by keyword) must include defensive framing indicators. The filter checks for terms like:
- `defensive_focus: true`
- "Defensive pattern", "countermeasure", "guard", "protect against"

### 3. Schema validation

`grimoire validate` checks:
- `epistemic_status` field present in all corpus files
- `citations` array present in all corpus files
- `documented` entries have ≥1 citation
- `ritual` entries have `defensive_focus: true`

---

## CI Integration

### GitHub Actions workflow

Add this to `.github/workflows/ci.yml` to validate the corpus on every push:

```yaml
name: Grimoire Corpus Validation

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: packages/grimoire-cli/package-lock.json

      - name: Install CLI dependencies
        run: npm ci
        working-directory: packages/grimoire-cli

      - name: Build CLI
        run: npm run build
        working-directory: packages/grimoire-cli

      - name: Run tests
        run: npm test
        working-directory: packages/grimoire-cli

      - name: Validate corpus
        run: node dist/index.js validate
        working-directory: packages/grimoire-cli
```

### Key CI behaviors

- **Mock mode is the default** — no API key needed for CI validation or test runs
- **Validate exits with code 1** on failure — CI jobs will fail correctly
- **Generate does not auto-commit** without explicit `--commit` flag — no accidental writes in CI

---

*MU 𒉙⍤ 𐤌𐤏 — normancomics.eth 2026 A.D.*
