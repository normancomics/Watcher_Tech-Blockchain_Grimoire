import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { PAYMENT_CONFIG, TOOL_PRICING } from "@/lib/agent-config"
import { Search, Database, Shield, Users, Brain, Atom, FileCode, Bot } from "lucide-react"

const tools = [
  {
    icon: Search,
    name: "grimoire_audit_scan",
    price: TOOL_PRICING.grimoire_audit_scan.usd,
    description: "Scan Solidity code for 7 exploit archetypes derived from the Watcher framework",
    category: "security",
  },
  {
    icon: Database,
    name: "grimoire_query_codex",
    price: TOOL_PRICING.grimoire_query_codex.usd,
    description: "RAG query against 11K+ lines of security research and esoteric documentation",
    category: "knowledge",
  },
  {
    icon: Shield,
    name: "grimoire_defense_recommend",
    price: TOOL_PRICING.grimoire_defense_recommend.usd,
    description: "Get defense recommendations based on the 7 paradigms of the Atlantean Vault",
    category: "security",
  },
  {
    icon: Brain,
    name: "grimoire_watcher_consult",
    price: TOOL_PRICING.grimoire_watcher_consult.usd,
    description: "Consult 1 of 8 Watcher specialist agents for domain-specific guidance",
    category: "agent",
  },
  {
    icon: Users,
    name: "grimoire_family_threat_intel",
    price: TOOL_PRICING.grimoire_family_threat_intel.usd,
    description: "Access threat intelligence from the 13 Family framework mapping",
    category: "intel",
  },
  {
    icon: Atom,
    name: "grimoire_quantum_entropy",
    price: TOOL_PRICING.grimoire_quantum_entropy.usd,
    description: "Generate post-quantum secure randomness with verifiable entropy proofs",
    category: "crypto",
  },
  {
    icon: FileCode,
    name: "grimoire_rag_synthesis",
    price: TOOL_PRICING.grimoire_rag_synthesis.usd,
    description: "Synthesize multi-document responses with citation chains and provenance",
    category: "knowledge",
  },
  {
    icon: Bot,
    name: "grimoire_sovereign_invoke",
    price: TOOL_PRICING.grimoire_sovereign_invoke.usd,
    description: "Full autonomous agent execution with multi-step reasoning and tool chains",
    category: "agent",
  },
]

const categoryColors: Record<string, string> = {
  security: "border-red-500/30 text-red-400",
  knowledge: "border-blue-500/30 text-blue-400",
  agent: "border-purple-500/30 text-purple-400",
  intel: "border-orange-500/30 text-orange-400",
  crypto: "border-green-500/30 text-green-400",
}

export function MCPSection() {
  return (
    <section id="oracle" className="py-24 px-6 bg-card/30">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <Badge variant="outline" className="mb-4 border-primary/30 text-primary">
            Model Context Protocol
          </Badge>
          <h2 className="font-serif text-3xl sm:text-4xl font-bold mt-4 mb-4 text-balance">
            Grimoire Oracle — MCP Server
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
            A fully operational MCP server monetizing the Grimoire knowledge base as AI-accessible 
            tools with x402 micropayments. All payments route to <span className="font-mono text-primary">{PAYMENT_CONFIG.ens}</span>.
          </p>
        </div>

        {/* Quick start code block */}
        <Card className="mb-12 bg-background/50 border-border/50 overflow-hidden">
          <CardHeader className="border-b border-border/50 py-3">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-destructive/50" />
              <div className="w-3 h-3 rounded-full bg-primary/50" />
              <div className="w-3 h-3 rounded-full bg-green-500/50" />
              <span className="ml-2 text-sm text-muted-foreground">Quick Start</span>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <pre className="p-6 overflow-x-auto text-sm">
              <code className="text-foreground/80">
{`cd mcp-server && npm install && npm run build

# Run as MCP server (Claude Desktop, Cursor, etc.)
npm start

# Run as paid HTTP API (x402 micropayments)
npm run start:http    # → http://localhost:8402

# Payments settle to: ${PAYMENT_CONFIG.address}
# ENS: ${PAYMENT_CONFIG.ens}`}
              </code>
            </pre>
          </CardContent>
        </Card>

        {/* Tools grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4">
          {tools.map((tool) => (
            <Card key={tool.name} className="bg-card/50 border-border/50 hover:border-primary/30 transition-colors">
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between mb-2">
                  <tool.icon className="w-5 h-5 text-primary" />
                  <Badge variant="outline" className={`text-xs ${categoryColors[tool.category]}`}>
                    {tool.category}
                  </Badge>
                </div>
                <div className="flex items-center justify-between">
                  <CardTitle className="font-mono text-xs truncate flex-1 mr-2">{tool.name}</CardTitle>
                  <Badge variant="secondary" className="text-primary shrink-0">
                    ${tool.price.toFixed(2)}
                  </Badge>
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-xs text-muted-foreground line-clamp-2">{tool.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* MCP Integration snippet */}
        <Card className="mt-12 bg-background/50 border-border/50 overflow-hidden">
          <CardHeader className="border-b border-border/50 py-3">
            <span className="text-sm text-muted-foreground">Claude Desktop / Cursor / Windsurf Integration</span>
          </CardHeader>
          <CardContent className="p-0">
            <pre className="p-6 overflow-x-auto text-sm">
              <code className="text-foreground/80">
{`{
  "mcpServers": {
    "grimoire-oracle": {
      "command": "node",
      "args": ["./mcp-server/dist/index.js"],
      "env": {
        "PAYMENT_ADDRESS": "${PAYMENT_CONFIG.address}",
        "PAYMENT_ENS": "${PAYMENT_CONFIG.ens}",
        "X402_ENABLED": "true"
      }
    }
  }
}`}
              </code>
            </pre>
          </CardContent>
        </Card>
      </div>
    </section>
  )
}
