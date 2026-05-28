# Safety Policy — Content Labeling & Security Guidelines

## Overview

The **Watcher Tech Blockchain Grimoire** covers advanced blockchain security research, esoteric history, and adversarial smart-contract threat modeling. This document defines the content labeling system and security content policy that all contributors and the agentic builder CLI must follow.

---

## 1. Epistemic Status Labels

Every corpus entry must declare an `epistemic_status` to distinguish how well-supported the content is:

| Status | Meaning | Citation Required |
|--------|---------|-------------------|
| `documented` | Supported by verifiable historical or technical sources | **Yes** (at least one) |
| `contested` | Some evidence exists but experts disagree | Recommended |
| `speculative` | Reasoned extrapolation without strong evidence | Optional |
| `fiction` | Narrative/lore framing, explicitly not factual | No |

### Inline labeling

Generated content must include a visible notice at the top of any document where `epistemic_status` is `speculative` or `fiction`:

```markdown
> ⚠️ **Epistemic status: speculative** — This entry reflects reasoned extrapolation and has not been independently verified.
```

---

## 2. No Actionable Exploit Instructions Policy

### Prohibited content

The grimoire builder CLI and all human contributors **must not** produce:

- Step-by-step instructions for exploiting live smart contracts or production systems
- Working exploit code targeting specific deployed contracts
- Wallet private keys, mnemonic phrases, or sensitive credentials (even example ones that look real)
- Tools or scripts designed to automate attacks against real systems without explicit authorized scope
- Content that provides material uplift to an attacker beyond what is widely available in published CVEs or academic research

### Permitted content

Security-related content **may** include:

- Abstract descriptions of exploit *patterns* and *archetypes* (e.g., reentrancy, oracle manipulation) at an educational level
- Defensive code patterns, guard implementations, and audit checklists
- Historical post-mortems of disclosed blockchain exploits (with citations to public disclosure)
- Threat modeling frameworks and risk-assessment methodologies
- Smart contract audit tooling (slither, foundry, echidna, etc.) usage examples
- Conceptual "ritual analogue" mappings (e.g., "reentrancy ↔ Serpent ritual") as symbolic/lore framing

---

## 3. Safety Rails in the Grimoire CLI

The `packages/grimoire-cli/src/lib/safety.ts` module enforces these rules programmatically:

### Content filter

The CLI runs all generated output through a content filter before writing to disk. The filter:

1. **Blocks** output containing patterns associated with actionable exploit code (private keys, `selfdestruct` with live addresses, etc.)
2. **Flags** output that contains step-by-step numbered instructions in a security context
3. **Requires** that any output tagged `security` or `exploit` include a `defensive_focus: true` field in YAML/JSON or a `> **Defensive context:**` callout in Markdown

### Labeling enforcement

- The `validate` command checks that all corpus files contain required `epistemic_status` fields
- The `generate` command always applies a label based on the generation mode (`fiction` for uncited AI output, `speculative` for seeded generation, `documented` only when citations are explicitly supplied)

---

## 4. Moon-Phase & Ritual Content

Content exploring correlations between ritual timing, moon phases, and blockchain event timing is permitted as **speculative** or **fiction** lore content. It must:

- Be clearly labeled with the appropriate `epistemic_status`
- Not be presented as instructions for illegal market manipulation or front-running on live networks
- Frame timing observations as historical/pattern analysis, not as operational guidance

---

## 5. Reporting Safety Violations

If you discover content in this repository that violates this policy, please:

1. Open a **private security advisory** via GitHub's Security tab, **or**
2. Email the maintainer directly (contact listed in GitHub profile)

Do not open a public issue for content that itself contains sensitive material.

---

## 6. AI-Generated Content

All content produced by the Grimoire Builder CLI is:

- Automatically labeled with `epistemic_status: fiction` or `speculative` unless overridden with explicit citations
- Subject to the content filter in `safety.ts` before being written to disk
- Not automatically committed — the user must explicitly invoke `grimoire generate --commit` to persist outputs

---

*MU 𒉙⍤ 𐤌𐤏 — normancomics.eth 2026 A.D.*
