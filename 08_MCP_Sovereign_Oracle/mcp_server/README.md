# 🔮 Grimoire Oracle — Sovereign MCP Server

**Blockchain Security Intelligence as a Service**

A monetizable MCP (Model Context Protocol) server that exposes the [Watcher Tech Blockchain Grimoire](https://github.com/normancomics/Watcher_Tech_Blockchain_Grimoire) knowledge base as paid AI-accessible tools. Built with **x402 micropayments** and **ERC-8004 agent identity**.

---

## ⚡ Quick Start

### 1. Install & Build

```bash
cd mcp-server
npm install
npm run build
```

### 2. Run as MCP Server (for Claude Desktop, Cursor, etc.)

```bash
npm start
```

### 3. Run as HTTP API (with x402 payments)

```bash
npm run start:http
```

The server starts on `http://localhost:8402` with x402 payment enforcement on all tool endpoints.

---

## 🛠️ Tools

| Tool | Price | Description |
|------|-------|-------------|
| `grimoire_audit_scan` | 0.50 USDC | Scan Solidity code for 7 exploit archetypes |
| `grimoire_query_codex` | 0.10 USDC | RAG query against 11K+ lines of security research |
| `grimoire_defense_recommend` | 0.25 USDC | Get defense recommendations from 7 paradigms |
| `grimoire_watcher_consult` | 0.75 USDC | Consult 1 of 8 Watcher specialist agents |
| `grimoire_family_threat_intel` | 0.30 USDC | Threat intel from 13 Family archetype framework |

### The 7 Exploit Archetypes Scanned

| # | Grimoire Name | Modern Name | Family | Severity |
|---|---------------|-------------|--------|----------|
| 1 | Recursive Invocation Rite | Reentrancy | Bundy | Critical |
| 2 | Gatekeeper's Reordering | MEV / Frontrunning | Rothschild | High |
| 3 | Instant Conjuration | Flash Loan Attack | DuPont | Critical |
| 4 | Luring Sacrificial Flow | Vampire Liquidity | Rockefeller | High |
| 5 | Portal Invocation | Bridge Exploit | Astor | Critical |
| 6 | Cloaked Initiation | ZK Proof Misuse | Collins | High |
| 7 | Artificer's Trojan | Supply Chain Attack | Van Duyn | Critical |

### The 8 Watcher Consultants

| Watcher | Domain | Modern Analogue |
|---------|--------|-----------------|
| Azazel | Cybersecurity | Security Auditor |
| Semyaza | Contract Analysis | Formal Verifier |
| Armaros | Cryptography | Protocol Designer |
| Baraqel | MEV & Timing | MEV Researcher |
| Kokabiel | EVM & Gas | Gas Optimizer |
| Tamiel | On-Chain Analytics | Data Scientist |
| Ramiel | Recovery & Forensics | Incident Responder |
| Daniel | Advanced Research | Zero-Day Hunter |

---

## 🔌 Integration

### Claude Desktop / Cursor (MCP stdio)

Add to your MCP client configuration:

```json
{
  "mcpServers": {
    "grimoire-oracle": {
      "command": "node",
      "args": ["/path/to/mcp-server/dist/index.js"],
      "env": {
        "GRIMOIRE_REPO_PATH": "/path/to/Watcher_Tech-Blockchain_Grimoire"
      }
    }
  }
}
```

### HTTP API (with x402 payments)

```bash
# Get pricing
curl http://localhost:8402/api/pricing

# Call a tool (requires X-PAYMENT header)
curl -X POST http://localhost:8402/api/tools/grimoire_audit_scan \
  -H "Content-Type: application/json" \
  -H "X-PAYMENT: <x402-payment-proof>" \
  -d '{"sourceCode": "pragma solidity ^0.8.20; ..."}'

# Without payment → 402 with payment instructions
curl -X POST http://localhost:8402/api/tools/grimoire_audit_scan \
  -H "Content-Type: application/json" \
  -d '{"sourceCode": "..."}'
# Returns: {"x402Version":1,"error":"X-PAYMENT-REQUIRED","accepts":[...]}
```

### Agent Discovery (ERC-8004)

```bash
# Get agent registration (for discovery by other agents)
curl http://localhost:8402/.well-known/agent.json
```

---

## 💰 Monetization with x402

The x402 protocol enables **HTTP-native crypto payments**. When a client calls a paid endpoint without a valid `X-PAYMENT` header, the server returns HTTP 402 with payment instructions:

```json
{
  "x402Version": 1,
  "error": "X-PAYMENT-REQUIRED",
  "accepts": [{
    "scheme": "exact",
    "network": "base-sepolia",
    "maxAmountRequired": "0.50",
    "payTo": "0xYOUR_WALLET_ADDRESS",
    "asset": "USDC"
  }]
}
```

### Setup

1. **Set your wallet address** in `config/pricing.json`:
   ```json
   { "receiverAddress": "0xYOUR_WALLET_ADDRESS" }
   ```

2. **Choose your network** (Base recommended for lowest fees):
   ```json
   { "network": "base" }
   ```

3. **Set prices** per tool as desired.

4. **For production payment verification**, install the x402 SDK:
   ```bash
   npm install @coinbase/x402
   ```
   Then update `src/payment/x402.ts` to use `verifyPayment()` from the SDK.

### Free Access (Development)

Set an access key for testing without payments:

```bash
GRIMOIRE_FREE_ACCESS_KEY=your-secret-key npm run start:http
```

Then include the header:
```bash
curl -H "X-GRIMOIRE-FREE-ACCESS: your-secret-key" ...
```

---

## 🏛️ ERC-8004 Agent Identity

The Grimoire Oracle registers as a sovereign agent on the ERC-8004 Trustless Agents standard.

### Registration

1. Edit `config/registration.json` with your deployed endpoints
2. Register on-chain:
   ```bash
   npx @agentic-trust/8004-sdk register \
     --config config/registration.json \
     --network base
   ```
3. Your agent receives an `agentId` (ERC-721 NFT) representing its identity
4. Users leave reputation feedback on the ERC-8004 Reputation Registry

### Discovery

Other agents discover your Grimoire Oracle via:
- `/.well-known/agent.json` endpoint
- ERC-8004 Identity Registry on-chain lookup
- The `services` array in your registration describes both MCP and HTTP-API interfaces

---

## 🐳 Docker Deployment

```bash
# Build
docker build -t grimoire-oracle ./mcp-server

# Run (mount your repo as the knowledge base)
docker run -p 8402:8402 \
  -v $(pwd):/grimoire \
  -e GRIMOIRE_REPO_PATH=/grimoire \
  grimoire-oracle
```

---

## 📁 Project Structure

```
mcp-server/
├── src/
│   ├── index.ts              # MCP server (stdio transport)
│   ├── server.ts             # HTTP server (x402 payments)
│   ├── tools/
│   │   ├── audit-scan.ts     # Solidity exploit archetype scanner
│   │   ├── query-codex.ts    # Knowledge base RAG query
│   │   ├── defense-recommend.ts  # Defense paradigm recommender
│   │   ├── watcher-consult.ts    # Watcher domain consultant
│   │   └── family-threat-intel.ts # Family threat intelligence
│   ├── knowledge/
│   │   ├── archetypes.ts     # 7 exploits, 13 families, 8 watchers, 7 defenses
│   │   ├── loader.ts         # Documentation corpus loader
│   │   └── search.ts         # TF-IDF search engine
│   ├── payment/
│   │   └── x402.ts           # x402 payment middleware
│   └── identity/
│       └── erc8004.ts        # ERC-8004 agent identity
├── config/
│   ├── pricing.json          # x402 per-tool pricing
│   └── registration.json     # ERC-8004 agent registration
├── Dockerfile
├── package.json
└── tsconfig.json
```

---

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GRIMOIRE_REPO_PATH` | `../` (parent of mcp-server) | Path to the Grimoire repository |
| `PORT` | `8402` | HTTP server port |
| `GRIMOIRE_FREE_ACCESS_KEY` | *(none)* | Secret key for free access during development |

---

## 📈 Revenue Potential

At scale with automated agent traffic:

| Scenario | Monthly Calls | Revenue |
|----------|---------------|---------|
| 100 audits/day | 3,000 | $1,500 |
| 500 codex queries/day | 15,000 | $1,500 |
| 200 defense recommendations/day | 6,000 | $1,500 |
| 50 watcher consultations/day | 1,500 | $1,125 |
| 100 threat intel queries/day | 3,000 | $900 |
| **Combined** | **28,500** | **$6,525/mo** |

---

## 📜 License

MIT — normancomics.eth, 2026
