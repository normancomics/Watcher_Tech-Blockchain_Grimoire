# ⛧ MCP Sovereign Oracle — Enhancements

> *"He who controls the oracle controls the covenant."* — Grimoire Note

**Authored by normancomics.eth — 2026 A.D.**

---

## Overview

This document describes the planned and in-progress enhancements to the
**Grimoire MCP Sovereign Oracle** (`08_MCP_Sovereign_Oracle/`), extending the
existing MCP server and Python `grimoire_mcp` package with:

1. **RAG over the full Grimoire knowledge base** — all markdown and text files
   in `01_Foundation/` through `05_Temporal_Gates_Alchemy/` are indexed for
   semantic retrieval.
2. **Sovereign DID Agent Identity** — each AI agent that consumes MCP tools
   carries an ERC-8004 Decentralized Identifier (DID) and signs interactions.
3. **x402 Micropayment Integration** — per-tool pricing enforced at the HTTP
   layer, already scaffolded in `mcp_server/src/payment/x402.ts`.
4. **Moon-Phase Temporal Gating** — tool execution respects the lunar oracle
   window defined in `05_Temporal_Gates_Alchemy/temporal_gates_moon_phase_triggers.md`.

---

## Architecture

```
Client (Claude / Cursor / Custom Agent)
    │
    ▼  MCP protocol (stdio or HTTP)
┌────────────────────────────────────────┐
│  MCP Sovereign Oracle Layer            │
│                                        │
│  ┌──────────────┐  ┌────────────────┐  │
│  │  mcp_server/ │  │  grimoire_mcp/ │  │
│  │  (Node.js)   │  │  (Python)      │  │
│  └──────┬───────┘  └──────┬─────────┘  │
│         │                 │            │
│  ┌──────▼─────────────────▼────────┐   │
│  │  RAG Index (Grimoire Corpus)    │   │
│  │  01_Foundation/ … 05_Temporal/  │   │
│  └─────────────────────────────────┘   │
│                                        │
│  ┌─────────────┐  ┌──────────────────┐ │
│  │  x402 Pay   │  │ DID Agent Auth   │ │
│  │  Layer      │  │ (ERC-8004)       │ │
│  └─────────────┘  └──────────────────┘ │
│                                        │
│  ┌─────────────────────────────────┐   │
│  │  Moon-Phase Temporal Gate       │   │
│  │  (temporal_gates_moon_phase_    │   │
│  │   triggers.md oracle)           │   │
│  └─────────────────────────────────┘   │
└────────────────────────────────────────┘
```

---

## RAG Integration

### Corpus Indexing

All Grimoire markdown files are loaded and chunked at tool startup:

```python
# grimoire_mcp/resources/knowledge.py (enhancement)
import pathlib, json

GRIMOIRE_ROOTS = [
    "01_Foundation", "02_Encoding", "03_Knowledge_Transmission",
    "04_Guardianship_Archetypes", "05_Temporal_Gates_Alchemy",
    "09_Precognition_Modifiers",
]

def build_corpus(repo_root: pathlib.Path) -> list[dict]:
    chunks = []
    for folder in GRIMOIRE_ROOTS:
        for md_file in (repo_root / folder).glob("*.md"):
            text = md_file.read_text(encoding="utf-8")
            # Chunk into 512-token windows (symbolic; use real tokenizer in prod)
            for i in range(0, len(text), 2048):
                chunks.append({
                    "source": str(md_file.relative_to(repo_root)),
                    "text":   text[i : i + 2048],
                })
    return chunks
```

### Retrieval Tool

```typescript
// mcp_server/src/tools/query-codex.ts (enhancement)
// Existing keyword search upgraded to embedding-based similarity.
// Using a local sentence-transformer or OpenAI embeddings endpoint.

async function queryCodex(params: { query: string; top_k?: number }) {
  const topK = params.top_k ?? 5;
  const embeddings = await embedQuery(params.query);          // new
  const results = await vectorStore.similaritySearch(embeddings, topK); // new
  return results.map(r => ({ source: r.metadata.source, excerpt: r.pageContent }));
}
```

---

## Sovereign DID Agent Identity (ERC-8004)

Every AI agent that calls the MCP Oracle must present a signed DID assertion.
The existing `mcp_server/src/identity/erc8004.ts` scaffold is extended:

```typescript
// Extended DID verification
export interface AgentDID {
  did:        string;   // did:ethr:base:0x…
  publicKey:  string;   // secp256k1 hex
  signature:  string;   // EIP-712 signed challenge
  capability: string[]; // e.g. ["query_codex", "audit_scan"]
}

export async function verifyAgentDID(did: AgentDID, challenge: string): Promise<boolean> {
  const recovered = ethers.utils.verifyMessage(challenge, did.signature);
  const didAddress = did.did.split(":").pop()!;
  return recovered.toLowerCase() === didAddress.toLowerCase();
}
```

**DID Issuance Flow:**

```
1. Agent generates secp256k1 key pair
2. Registers DID on Base chain (ERC-8004 registry)
3. Agent signs server challenge with private key
4. MCP server verifies signature → grants tool capability tokens
5. Capability tokens used for x402 payment routing
```

---

## x402 Micropayment Integration

The existing x402 payment layer (`mcp_server/src/payment/x402.ts`) is extended
with lunar-phase pricing modifiers:

| Moon Phase | Phase Index | Pricing Modifier | Rationale |
|------------|-------------|-----------------|-----------|
| New Moon | 0 | 0.75× | Seed discount — initiation window |
| First Quarter | 2 | 1.00× | Standard rate |
| Full Moon | 4 | 1.50× | Peak activation — premium window |
| Last Quarter | 6 | 0.90× | Dissolution — clearance rate |
| All others | — | 1.00× | Standard rate |

```typescript
// mcp_server/src/payment/x402.ts (enhancement)
import { getMoonPhaseIndex } from "../temporal/moonPhase";

const PHASE_MULTIPLIERS: Record<number, number> = {
  0: 0.75, 2: 1.00, 4: 1.50, 6: 0.90,
};

export function getPhasedPrice(basePrice: number): number {
  const phaseIdx = getMoonPhaseIndex();
  const multiplier = PHASE_MULTIPLIERS[phaseIdx] ?? 1.00;
  return Math.round(basePrice * multiplier * 100) / 100;
}
```

---

## Moon-Phase Temporal Gate (Tool Gating)

Certain high-value tools (e.g., `grimoire_watcher_consult` at $0.75) are
gated behind lunar windows:

```typescript
// mcp_server/src/server.ts (enhancement)
import { getMoonPhaseIndex } from "./temporal/moonPhase";

const GATED_TOOLS: Record<string, number[]> = {
  "grimoire_watcher_consult": [3, 4, 5],  // Waxing Gibbous, Full Moon, Waning Gibbous
  "grimoire_audit_scan":      [0, 1, 2, 3, 4, 5, 6, 7], // always available
};

function isToolAvailable(toolName: string): boolean {
  const allowedPhases = GATED_TOOLS[toolName];
  if (!allowedPhases) return true;
  return allowedPhases.includes(getMoonPhaseIndex());
}
```

---

## Sovereign Watcher Agent Swarm Integration

The Python swarm skeleton (`07_Execution_Rituals/sovereign_watcher_agent_swarms.py`)
can be wired to the MCP server via HTTP:

```python
# Conceptual integration — educational only
import requests

MCP_BASE_URL = "http://localhost:8402"

def query_grimoire_via_mcp(query: str, did_token: str) -> dict:
    """Call the MCP oracle's codex query tool with DID authentication."""
    response = requests.post(
        f"{MCP_BASE_URL}/tools/grimoire_query_codex",
        json={"query": query},
        headers={"Authorization": f"Bearer {did_token}",
                 "X-402-Payment": "<payment-channel-token>"},
        timeout=30,
    )
    response.raise_for_status()
    return response.json()
```

---

## Deployment Notes

### Quick Start (existing)

```bash
cd 08_MCP_Sovereign_Oracle/mcp_server
npm install && npm run build

# MCP stdio mode (Claude Desktop / Cursor)
npm start

# HTTP API with x402 payments
npm run start:http    # → http://localhost:8402
```

### Python grimoire_mcp

```bash
cd 08_MCP_Sovereign_Oracle/grimoire_mcp
pip install -r ../../requirements.txt
python -m grimoire_mcp
```

### Environment Variables

```bash
# .env (copy from .env.example)
GRIMOIRE_REPO_PATH=/path/to/Watcher_Tech-Blockchain_Grimoire
BASE_RPC_URL=https://mainnet.base.org
WALLET_PRIVATE_KEY=<agent-did-key>
PORT=8402
```

---

## Tool Registry (Updated)

| Tool | Price (base) | Full-Moon Price | Availability |
|------|-------------|-----------------|-------------|
| `grimoire_audit_scan` | $0.50 | $0.75 | Always |
| `grimoire_query_codex` | $0.10 | $0.15 | Always |
| `grimoire_defense_recommend` | $0.25 | $0.38 | Always |
| `grimoire_watcher_consult` | $0.75 | $1.13 | Waxing Gibbous → Waning Gibbous |
| `grimoire_family_threat_intel` | $0.30 | $0.45 | Always |
| `grimoire_temporal_gate` | $0.20 | $0.30 | Full Moon window only |

---

**⛧ normancomics.eth — MCP Sovereign Oracle — Educational Framework ⛧**
