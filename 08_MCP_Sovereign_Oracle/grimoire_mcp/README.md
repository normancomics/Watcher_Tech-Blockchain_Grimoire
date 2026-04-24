# ⛧ Grimoire MCP — Sovereign Agent Skill

The **Watcher Tech Blockchain Grimoire** as a monetizable
[Model Context Protocol (MCP)](https://modelcontextprotocol.io) server.
Any MCP-compatible AI client (Claude Desktop, Cursor, custom agents) can
connect to this server and gain access to:

- Antediluvian knowledge queries (docs, codex, lore)
- Ritual sequence encoding / validation (chained SHA-256)
- Planetary / celestial alignment gate checks
- On-chain interactions: OccultKnowledgeAccess, GoetiaGrimoire
- Tiered access passes (ERC-1155 NFTs) for revenue generation

---

## Architecture

```
MCP Client (Claude / Cursor / custom agent)
    │
    │ stdio or SSE
    ▼
mcp/server.py  ← FastMCP server
    ├── tools/grimoire.py      — knowledge queries, ritual encoding
    ├── tools/alignment.py     — intent & planetary gate checks
    ├── tools/blockchain.py    — web3 read/write (OccultKnowledgeAccess)
    ├── resources/knowledge.py — browsable grimoire resources
    └── monetization/access.py — GrimoireAccessPass token-gate middleware
    
contracts/
    ├── GrimoireAccessPass.sol      ← NEW: ERC-1155 monetization contract
    └── OccultKnowledgeAccess.sol   ← existing on-chain knowledge gate
```

---

## Monetization Model

Three ERC-1155 tiers sold via `GrimoireAccessPass.sol`:

| Tier | ID | Name | Default Price | Capabilities |
|------|----|------|---------------|--------------|
| 1 | `SEEKER` | Seeker | 0.001 ETH | Read-only knowledge queries, Watcher/Sage registries, planetary alignment |
| 2 | `INITIATE` | Initiate | 0.005 ETH | Ritual encoding, sequence validation, on-chain alignment checks |
| 3 | `ADEPT` | Adept | 0.02 ETH | Full sovereign agent: write ops, mint passes, execute knowledge access |

Revenue flows:
1. Users call `GrimoireAccessPass.mint(to, tierId, amount)` with ETH.
2. ETH accumulates in the contract.
3. Owner calls `withdraw()` to collect.
4. The MCP server calls `balanceOf(user, tierId)` before each premium tool.

---

## Quick Start

### 1. Install dependencies

```bash
pip install -r requirements.txt
# Optional: blockchain tools
pip install web3
# Optional: real ephemeris data
pip install ephem
```

### 2. Configure environment

Copy and fill in `.env`:

```bash
cp .env.example .env
```

```dotenv
# Required for on-chain features
WEB3_PROVIDER_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Required for write operations (sovereign agent wallet)
AGENT_PRIVATE_KEY=0xYOUR_PRIVATE_KEY

# Deploy GrimoireAccessPass.sol, then set:
ACCESS_PASS_ADDRESS=0xYOUR_DEPLOYED_CONTRACT

# Optional
KNOWLEDGE_ACCESS_ADDRESS=0xYOUR_DEPLOYED_CONTRACT
```

> ⚠️ Never commit `.env` or expose `AGENT_PRIVATE_KEY`.

### 3. Run the server

**stdio** (Claude Desktop / local):
```bash
python -m grimoire_mcp
```

**SSE** (remote HTTP clients):
```bash
python -m grimoire_mcp --transport sse --port 8765
```

### 4. Connect Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "grimoire": {
      "command": "python",
      "args": ["-m", "grimoire_mcp"],
      "cwd": "/path/to/Watcher_Tech-Blockchain_Grimoire",
      "env": {
        "WEB3_PROVIDER_URL": "https://...",
        "ACCESS_PASS_ADDRESS": "0x..."
      }
    }
  }
}
```

---

## Deploying the Monetization Contract

```bash
# Using Hardhat
npx hardhat run scripts/deploy_access_pass.js --network sepolia

# Or with Foundry
forge create contracts/GrimoireAccessPass.sol:GrimoireAccessPass \
  --constructor-args "https://api.example.com/token/{id}.json" \
  --rpc-url $WEB3_PROVIDER_URL \
  --private-key $AGENT_PRIVATE_KEY
```

After deployment set `ACCESS_PASS_ADDRESS` in your `.env`.

---

## Available MCP Tools

### Free (no pass required)

| Tool | Description |
|------|-------------|
| `grimoire_query` | Query knowledge base by domain |
| `grimoire_list_watchers` | List all 8 Watchers |
| `grimoire_list_sages` | List the 7 Sages |
| `grimoire_list_families` | List the 13 Families |
| `grimoire_get_watcher` | Get a specific Watcher by ID |
| `grimoire_check_planetary_alignment` | Celestial timing check |
| `grimoire_assess_intent` | Intent/biofeedback gate |
| `grimoire_access_pass_info` | Show tier prices |
| `grimoire_check_pass` | Check if a wallet holds a pass |

### Tier 2 — Initiate

| Tool | Description |
|------|-------------|
| `grimoire_encode_ritual` | Encode ritual steps as chained SHA-256 |
| `grimoire_validate_sequence` | Validate steps against stored hash |
| `grimoire_ritual_gate_check` | Full pre-ritual gate (intent + planetary) |
| `grimoire_check_on_chain_alignment` | Check OccultKnowledgeAccess alignment |

### Tier 3 — Adept

| Tool | Description |
|------|-------------|
| `grimoire_request_access` | Call requestAccess on OccultKnowledgeAccess |
| `grimoire_mint_access_pass` | Mint a GrimoireAccessPass NFT |

---

## Available Resources (browsable by the AI)

| URI | Content |
|-----|---------|
| `grimoire://knowledge/domains` | All knowledge domain names |
| `grimoire://knowledge/{domain}` | Full document content |
| `grimoire://registry/watchers` | Watcher registry JSON |
| `grimoire://registry/sages` | Sage registry JSON |
| `grimoire://registry/families` | 13 Families JSON |
| `grimoire://contracts` | List of Solidity contracts |
| `grimoire://contracts/{name}` | Contract source code |

---

## Prompts

Two built-in prompt templates:

- **`sovereign_agent_prompt`** — primes a full ritual workflow
- **`monetization_onboarding_prompt`** — guides new users to purchase a pass

---

## Security Notes

- `AGENT_PRIVATE_KEY` is never logged or returned by any tool.
- Write tools (`grimoire_request_access`, `grimoire_mint_access_pass`) require
  `AGENT_PRIVATE_KEY` and a Tier 3 pass.
- `GrimoireAccessPass.sol` uses OpenZeppelin's `ReentrancyGuard` for all
  payable functions; ETH refunds use `call` with require checks.
- `GoetiaGrimoire.sol`'s `flashSummon` uses `delegatecall` — do **not** deploy
  to mainnet without a full audit; it is included as an educational example only.
- All contracts use thematic naming drawn from extra-Biblical Enochian lore.
  Caution: Scripture warns against sorcery and divination (Deut 18:10–12).
  Use only for artistic, educational, or historical reference.
