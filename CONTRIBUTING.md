# Contributing to the Watcher Tech Blockchain Grimoire

Thank you for your interest in contributing to **MU 𒉙⍤ 𐤌𐤏 — Sovereign Blockchain Grimoire**.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [How to Contribute](#how-to-contribute)
3. [Corpus Contributions](#corpus-contributions)
4. [Smart Contract Contributions](#smart-contract-contributions)
5. [CLI / Tooling Contributions](#cli--tooling-contributions)
6. [Content Policy & Safety Rails](#content-policy--safety-rails)
7. [Commit Conventions](#commit-conventions)
8. [Pull Request Process](#pull-request-process)

---

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

---

## How to Contribute

1. **Fork** the repository.
2. **Clone** your fork locally.
3. Create a **feature branch**: `git checkout -b feat/your-feature-name`.
4. Make your changes (see type-specific guides below).
5. **Lint** and **validate** your work:
   ```bash
   # For CLI / TypeScript changes
   cd packages/grimoire-cli && npm run lint && npm test

   # For corpus entries
   cd packages/grimoire-cli && npm run validate
   ```
6. **Commit** following the [commit conventions](#commit-conventions).
7. Open a **Pull Request** using the provided [PR template](.github/pull_request_template.md).

---

## Corpus Contributions

The `corpus/` directory stores all lore content. Every entry **must** include:

| Field | Requirement |
|-------|-------------|
| `epistemic_status` | One of: `documented`, `contested`, `speculative`, `fiction` |
| `citations` | Array (may be empty for `fiction`; required for `documented`) |

### Markdown entries (`corpus/entries/`)

```markdown
---
id: my-entry-id
title: My Entry Title
epistemic_status: speculative
citations: []
tags: [watcher, blockchain]
created: YYYY-MM-DD
---

Content here...
```

### YAML artifacts (`corpus/entities/`, `corpus/factions/`, `corpus/rituals/`)

See `schemas/*.schema.json` for the full field specifications.

### JSON timelines (`corpus/timelines/`)

See `schemas/timeline.schema.json`.

---

## Smart Contract Contributions

- All Solidity files go in `06_Contracts/` or `technical-grimoire/smart-contracts/`.
- Target **Base chain** (chainId 8453) only.
- Include NatSpec documentation on every public function.
- Run `forge test` before submitting.

---

## CLI / Tooling Contributions

The agentic builder CLI lives in `packages/grimoire-cli/`.

```bash
cd packages/grimoire-cli
npm install
npm run build
npm test
npm run lint
```

When adding a new command, follow the pattern in `src/commands/` and register it in `src/index.ts`.

---

## Content Policy & Safety Rails

All contributions must comply with our [Safety Policy](SAFETY.md). In short:

- **No actionable exploit step-by-step instructions.** Describe attack patterns at an abstract/defensive level.
- **Label all generated content** with an appropriate `epistemic_status`.
- **Security-related content** must focus on defensive descriptions, threat modeling, and protective measures.

Submissions that violate the safety policy will be closed without review.

---

## Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | When to use |
|--------|-------------|
| `feat:` | New feature or corpus entry |
| `fix:` | Bug fix |
| `docs:` | Documentation only |
| `corpus:` | New or updated corpus content |
| `schema:` | Schema changes |
| `chore:` | Tooling, CI, dependency updates |
| `security:` | Security-related changes |

Examples:
```
feat: add Gadreel faction entity YAML
corpus: add moon-phase blockchain timing entry
fix: correct validate command JSON output path
```

---

## Pull Request Process

1. Fill in the [PR template](.github/pull_request_template.md) completely.
2. Ensure all CI checks pass.
3. At least one maintainer must approve before merge.
4. Squash commits are preferred for corpus additions; merge commits for feature branches.

---

*MU 𒉙⍤ 𐤌𐤏 — normancomics.eth 2026 A.D.*
