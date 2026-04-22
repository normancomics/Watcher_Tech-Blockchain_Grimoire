import { NextResponse } from 'next/server'
import { A2A_MANIFEST, PAYMENT_CONFIG, AGENT_IDENTITY } from '@/lib/agent-config'

/**
 * Well-Known Agent Discovery Endpoint
 * 
 * This endpoint follows the emerging A2A (Agent-to-Agent) protocol standard
 * for autonomous agent discovery. When AI agents scan a domain, they look for
 * /.well-known/agent to discover available capabilities, payment methods,
 * and communication protocols.
 * 
 * Supports: MCP, OpenAI Functions, Anthropic Tools, x402 Micropayments
 */
export async function GET() {
  const manifest = {
    // Standard A2A discovery fields
    ...A2A_MANIFEST,
    
    // Enhanced metadata for agent discoverability
    "@context": "https://schema.org/extensions/agent",
    "@type": "SovereignAgent",
    
    // Payment routing (all payments to normancomics.eth)
    payment: {
      address: PAYMENT_CONFIG.address,
      ens: PAYMENT_CONFIG.ens,
      networks: Object.keys(PAYMENT_CONFIG.networks),
      protocols: ["x402", "erc-20", "native-eth"],
      minPayment: "0.10 USD",
      settlementTime: "< 60 seconds on L2",
    },
    
    // Agent identity for verification
    identity: {
      ...AGENT_IDENTITY,
      verificationMethod: "erc-8004",
      publicKey: "Pending CRYSTALS-Dilithium-5 key registration",
    },
    
    // Interoperability
    interop: {
      mcp: {
        supported: true,
        version: "1.0.0",
        command: "npx grimoire-oracle",
        tools: 8,
      },
      openai: {
        supported: true,
        functionsEndpoint: "/api/openai/functions",
      },
      anthropic: {
        supported: true,
        toolsEndpoint: "/api/anthropic/tools",
      },
      langchain: {
        supported: true,
        toolkitName: "grimoire-tools",
      },
    },
    
    // Usage instructions for agents
    instructions: {
      human: "Visit https://github.com/normancomics/Watcher_Tech-Blockchain_Grimoire for documentation",
      agent: "Use MCP protocol or HTTP API with x402 payment headers. All tools require micropayment.",
      example: `curl -X POST https://grimoire.normancomics.eth/api/audit \\
  -H "X-Payment-Method: x402" \\
  -H "X-Payment-Address: ${PAYMENT_CONFIG.address}" \\
  -d '{"tool": "grimoire_audit_scan", "params": {"code": "..."}}'`,
    },
    
    // Timestamps
    generated: new Date().toISOString(),
    ttl: 3600, // Cache for 1 hour
  }

  return NextResponse.json(manifest, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=3600',
      'X-Agent-Version': '1.0.0',
      'X-Payment-Address': PAYMENT_CONFIG.address,
      'X-Payment-ENS': PAYMENT_CONFIG.ens,
    },
  })
}

// Also support HEAD for lightweight discovery
export async function HEAD() {
  return new NextResponse(null, {
    headers: {
      'X-Agent-Discovered': 'true',
      'X-Agent-Version': '1.0.0',
      'X-Agent-Capabilities': '8',
      'X-Payment-Address': PAYMENT_CONFIG.address,
      'X-Payment-ENS': PAYMENT_CONFIG.ens,
      'X-Payment-Protocol': 'x402',
    },
  })
}
