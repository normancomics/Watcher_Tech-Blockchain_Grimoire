# API Reference — Watcher Tech Blockchain Grimoire

## Overview

The Grimoire API provides access to esoteric knowledge retrieval, lunar calculations, sigil generation, and sovereign agent management. All endpoints requiring payment implement the x402 protocol.

**Base URL**: `https://api.watchertech.io/v1`

**Authentication**: Bearer token (JWT) or ERC-8004 agent card signature

---

## Knowledge API

### GET /knowledge

Retrieve knowledge entries from the Grimoire registry.

**Query Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `domain` | string | Filter by esoteric domain |
| `accessLevel` | string | Maximum access level (public/initiated/adept/master) |
| `verified` | boolean | Only return peer-verified entries |
| `limit` | integer | Max results (default: 10, max: 100) |
| `offset` | integer | Pagination offset |

**Response**:
```json
{
  "entries": [
    {
      "id": "1",
      "title": "Fallen Angel Technology Transfer",
      "domain": "PrimordialTraditions",
      "accessLevel": "PUBLIC",
      "preview": "The Watchers (Grigori) of 1 Enoch 6-8...",
      "ipfsCID": "bafybei...",
      "verified": true,
      "upvotes": 42,
      "contributor": "0x...",
      "timestamp": "2026-01-01T00:00:00Z"
    }
  ],
  "total": 15,
  "hasMore": false
}
```

### GET /knowledge/:id

Retrieve a specific knowledge entry.

**x402 Payment**: Required for `INITIATED` and above content.
- **402 Response Headers**:
  - `X-Payment-Resource-Id`: Resource identifier for SpellPayment contract
  - `X-Payment-Contract`: SpellPayment.sol contract address
  - `X-Payment-Network`: Network (mainnet/base/optimism)

**Response** (after payment):
```json
{
  "id": "2",
  "title": "Kabbalistic Merkle Trees",
  "domain": "MysterySchools",
  "content": "Full markdown content...",
  "crossReferences": [1, 3, 5],
  "receipt": "0x..."
}
```

---

## Lunar Oracle API

### GET /lunar/current

Get current lunar phase and risk assessment.

**Response**:
```json
{
  "phase": "waxing_gibbous",
  "illumination": 0.73,
  "phaseAngle": 210.5,
  "daysUntilFull": 3.2,
  "daysUntilNew": 18.7,
  "julianDate": 2460000.5,
  "riskAssessment": {
    "currentPhase": "waxing_gibbous",
    "riskLevel": "MODERATE",
    "riskScore": 35,
    "historicalCorrelation": 0.12,
    "recommendation": "MONITOR: Standard precautions. Watch for unusual activity.",
    "highRiskPhases": ["full_moon", "new_moon"],
    "nextHighRiskWindow": "2026-02-15T00:00:00Z"
  }
}
```

### GET /lunar/phase-for-date

Get lunar phase for a specific date.

**Query Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `date` | string | ISO 8601 date (e.g., 2026-04-23) |

### POST /lunar/generate-seed

Generate a lunar-phase-seeded entropy value.

**Request Body**:
```json
{
  "contractAddress": "0x...",
  "date": "2026-04-23"
}
```

**Response**:
```json
{
  "seed": "a3f7b2...",
  "lunarPhase": "first_quarter",
  "contractAddress": "0x..."
}
```

---

## Sigil Generation API

### POST /sigil/generate

Generate a deterministic sigil hash from symbolic inputs.

**Request Body**:
```json
{
  "symbolName": "ETHEREUM",
  "planet": "Mercury",
  "element": "Air"
}
```

**Response**:
```json
{
  "sigilHash": "0x7f3a...",
  "gematriaValue": 247,
  "description": "ETHEREUM sealed by ☿ Mercury under 💨 Air principle",
  "planetaryConstant": 260,
  "elementTag": "AIR_ELEMENT"
}
```

### POST /sigil/verify

Verify that a sigil hash matches given symbolic inputs.

**Request Body**:
```json
{
  "sigilHash": "0x7f3a...",
  "symbolName": "ETHEREUM",
  "planet": "Mercury",
  "element": "Air"
}
```

**Response**:
```json
{
  "valid": true,
  "computedHash": "0x7f3a..."
}
```

---

## Agent API

### GET /agents

List all registered Watcher agents.

**Response**:
```json
{
  "agents": [
    {
      "agentId": 1,
      "name": "Watcher-Archon",
      "status": "Active",
      "tier": "Watcher",
      "bondedETH": "2.0",
      "reputation": 850,
      "capabilities": ["EXPLOIT_DETECT", "SWARM_COORD"],
      "endpointURL": "https://agents.watchertech.io/archon",
      "enochianName": "ZA-BI-CO"
    }
  ]
}
```

### POST /agents/register

Register a new ERC-8004 sovereign agent.

**Request Body**:
```json
{
  "name": "My-Custom-Agent",
  "version": "1.0.0",
  "description": "Custom esoteric analysis agent",
  "agentAddress": "0x...",
  "capabilities": ["ESOTERIC_RAG", "LUNAR_CALC"],
  "endpointURL": "https://my-agent.example.com",
  "agentCardCID": "bafybei...",
  "bondAmountEth": "0.1"
}
```

### GET /agents/:id/status

Get real-time agent status.

**Response**:
```json
{
  "agentId": 1,
  "status": "Active",
  "currentLunarRisk": 45,
  "activeAlerts": 0,
  "tasksCompleted": 247,
  "lastActive": "2026-04-23T04:00:00Z"
}
```

---

## Payment API

### GET /payment/requirements/:resourceId

Get x402 payment requirements for a resource.

**Response** (HTTP 402):
```json
{
  "error": "Payment Required",
  "statusCode": 402,
  "resourceId": 42,
  "resourceDescription": "Adept-level esoteric knowledge entry",
  "payment": {
    "amount": "0.001",
    "currency": "ETH",
    "network": "base",
    "contractAddress": "0x...",
    "functionSignature": "castSpell(uint256)",
    "accepts": ["application/json"]
  },
  "access": {
    "duration": 86400,
    "type": "time-based"
  }
}
```

### POST /payment/verify

Verify a payment receipt.

**Request Body**:
```json
{
  "receiptHash": "0x...",
  "resourceId": 42
}
```

**Response**:
```json
{
  "valid": true,
  "payer": "0x...",
  "resourceId": 42,
  "expiresAt": "2026-04-24T04:00:00Z",
  "tier": "Ritual"
}
```

---

## MCP Endpoints

The Grimoire exposes MCP (Model Context Protocol) tools for AI agent integration.

**MCP Server URL**: `https://mcp.watchertech.io`

### Available Tools

| Tool Name | Description |
|-----------|-------------|
| `grimoire_knowledge` | RAG-based esoteric knowledge retrieval |
| `lunar_calculations` | Moon phase computation and risk assessment |
| `sigil_generation` | Symbolic hash generation |
| `blockchain_divination` | Predictive analysis |
| `ancient_text_parser` | NLP for ancient texts |
| `ritual_validator` | Ceremony verification |

### MCP Tool Schema

```json
{
  "tools": [
    {
      "name": "grimoire_knowledge",
      "description": "Retrieve esoteric knowledge from the Watcher Tech Grimoire corpus",
      "inputSchema": {
        "type": "object",
        "properties": {
          "query": { "type": "string" },
          "domain": { "type": "string" },
          "maxResults": { "type": "number" }
        },
        "required": ["query"]
      }
    }
  ]
}
```

---

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 400 | Bad Request | Invalid parameters |
| 401 | Unauthorized | Missing or invalid authentication |
| 402 | Payment Required | x402 payment required for this resource |
| 403 | Forbidden | Insufficient access tier |
| 404 | Not Found | Resource not found |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Server Error | Internal error |

---

*"The grimoire opens only to those who have prepared themselves."*
