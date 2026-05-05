# @normancomics/grimoire-cli

Agentic builder CLI for the **Watcher Tech Blockchain Grimoire** — uses
[@kyegomez/OpenMythos](https://github.com/kyegomez/OpenMythos) (with offline mock mode)
to generate and expand the grimoire corpus.

## Quick Start

```bash
npm install
npm run build

# Validate corpus (no API key needed)
node dist/index.js validate

# Generate an entity (mock mode, dry run)
node dist/index.js generate --type entity --prompt "Your entity prompt" --mock --dry-run
```

## Commands

| Command | Description |
|---------|-------------|
| `init` | Scaffold corpus directory structure |
| `generate` | Generate corpus entries via OpenMythos or mock |
| `validate` | Validate all corpus files against schemas |
| `export` | Export corpus to JSON/YAML/Markdown bundle |

## Development

```bash
npm install      # Install dependencies
npm run build    # Compile TypeScript
npm test         # Run tests (25 tests, no API key needed)
npm run lint     # Lint source files
```

## Configuration

Copy `grimoire.config.json` and adjust paths and OpenMythos settings.
Set `"mode": "online"` and `OPENMYTHOS_API_KEY` env var for live generation.

See [docs/grimoire-cli.md](../../docs/grimoire-cli.md) for full documentation.
