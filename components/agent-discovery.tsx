"use client"

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { AGENT_IDENTITY, WATCHER_TAXONOMY, A2A_MANIFEST } from "@/lib/agent-config"
import { Bot, Brain, Network, Shield, Cpu, Fingerprint, MessageSquare, Zap } from "lucide-react"

export function AgentDiscoverySection() {
  const capabilities = [
    {
      icon: Shield,
      name: "Security Audit",
      description: "7 exploit archetypes derived from Watcher transmissions",
      protocol: "mcp/1.0",
    },
    {
      icon: Brain,
      name: "RAG-AGI Synthesis",
      description: "11K+ line knowledge corpus with retrieval-augmented generation",
      protocol: "rag/1.0",
    },
    {
      icon: Network,
      name: "A2A Protocol",
      description: "Agent-to-agent communication with cryptographic attestation",
      protocol: "a2a/1.0",
    },
    {
      icon: Cpu,
      name: "Quantum Entropy",
      description: "Post-quantum cryptographic primitives and verifiable randomness",
      protocol: "pqc/1.0",
    },
    {
      icon: Fingerprint,
      name: "ERC-8004 Identity",
      description: "On-chain agent registry with sybil-resistant authentication",
      protocol: "erc-8004",
    },
    {
      icon: MessageSquare,
      name: "Multi-Protocol",
      description: "MCP, OpenAI Functions, Anthropic Tools, and custom endpoints",
      protocol: "multi/1.0",
    },
  ]

  return (
    <section id="agents" className="py-24 px-6 bg-card/20">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-16">
          <Badge variant="outline" className="mb-4 border-primary/30 text-primary">
            <Bot className="w-3 h-3 mr-1" />
            Sovereign Agent Framework
          </Badge>
          <h2 className="font-serif text-3xl sm:text-4xl font-bold mt-4 mb-4 text-balance">
            Agent-Native Architecture
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
            Designed for autonomous AI agents, agentic users, and multi-agent systems. 
            Native support for MCP, A2A protocols, and on-chain identity verification.
          </p>
        </div>

        {/* Agent Identity Card */}
        <Card className="mb-12 bg-card/80 border-primary/20 backdrop-blur-sm overflow-hidden">
          <CardHeader className="border-b border-border/50 bg-secondary/20">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-xl bg-primary/10 flex items-center justify-center border border-primary/20">
                <Bot className="w-8 h-8 text-primary" />
              </div>
              <div>
                <CardTitle className="text-2xl font-serif">{AGENT_IDENTITY.agentId}</CardTitle>
                <CardDescription className="flex items-center gap-2 mt-1">
                  <Badge variant="secondary" className="text-xs">{AGENT_IDENTITY.type}</Badge>
                  <Badge variant="outline" className="text-xs">v{AGENT_IDENTITY.version}</Badge>
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="pt-6">
            <div className="grid md:grid-cols-2 gap-8">
              {/* Protocols */}
              <div>
                <h4 className="text-sm font-semibold text-muted-foreground mb-3 flex items-center gap-2">
                  <Network className="w-4 h-4" />
                  Supported Protocols
                </h4>
                <div className="flex flex-wrap gap-2">
                  {Object.entries(AGENT_IDENTITY.protocols).map(([protocol, version]) => (
                    <Badge key={protocol} variant="secondary" className="font-mono text-xs">
                      {protocol}/{version}
                    </Badge>
                  ))}
                </div>
              </div>

              {/* Capabilities */}
              <div>
                <h4 className="text-sm font-semibold text-muted-foreground mb-3 flex items-center gap-2">
                  <Zap className="w-4 h-4" />
                  Agent Capabilities
                </h4>
                <div className="flex flex-wrap gap-2">
                  {AGENT_IDENTITY.erc8004.capabilities.map((cap) => (
                    <Badge key={cap} variant="outline" className="text-xs border-primary/30 text-primary">
                      {cap}
                    </Badge>
                  ))}
                </div>
              </div>
            </div>

            {/* RAG Config */}
            <div className="mt-6 pt-6 border-t border-border/50">
              <h4 className="text-sm font-semibold text-muted-foreground mb-3 flex items-center gap-2">
                <Brain className="w-4 h-4" />
                RAG-AGI Configuration
              </h4>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                <div className="text-center p-3 rounded-lg bg-secondary/30">
                  <div className="text-2xl font-bold text-primary">
                    {(AGENT_IDENTITY.ragConfig.totalDocuments / 1000).toFixed(0)}K+
                  </div>
                  <div className="text-xs text-muted-foreground">Lines</div>
                </div>
                <div className="text-center p-3 rounded-lg bg-secondary/30">
                  <div className="text-2xl font-bold text-primary">{AGENT_IDENTITY.ragConfig.chunkSize}</div>
                  <div className="text-xs text-muted-foreground">Chunk Size</div>
                </div>
                <div className="text-center p-3 rounded-lg bg-secondary/30">
                  <div className="text-2xl font-bold text-primary">{AGENT_IDENTITY.ragConfig.retrievalTopK}</div>
                  <div className="text-xs text-muted-foreground">Top-K</div>
                </div>
                <div className="text-center p-3 rounded-lg bg-secondary/30">
                  <div className="text-2xl font-bold text-primary">{AGENT_IDENTITY.ragConfig.overlap}</div>
                  <div className="text-xs text-muted-foreground">Overlap</div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Capabilities Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          {capabilities.map((cap) => (
            <Card key={cap.name} className="bg-card/50 border-border/50 hover:border-primary/30 transition-colors group">
              <CardContent className="pt-6">
                <div className="flex items-start gap-4">
                  <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center shrink-0 group-hover:bg-primary/20 transition-colors">
                    <cap.icon className="w-5 h-5 text-primary" />
                  </div>
                  <div>
                    <h3 className="font-semibold mb-1">{cap.name}</h3>
                    <p className="text-sm text-muted-foreground mb-2">{cap.description}</p>
                    <Badge variant="outline" className="text-xs font-mono">
                      {cap.protocol}
                    </Badge>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Watcher Taxonomy */}
        <Card className="bg-card/50 border-border/50 mb-12">
          <CardHeader>
            <CardTitle className="font-serif flex items-center gap-2">
              <span className="text-primary">⛧</span>
              Watcher Framework Taxonomy
            </CardTitle>
            <CardDescription>
              13 Families, 7 Exploit Archetypes, 7 Defense Paradigms
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid md:grid-cols-3 gap-6">
              <div>
                <h4 className="text-sm font-semibold text-muted-foreground mb-3">13 Watcher Families</h4>
                <div className="flex flex-wrap gap-1">
                  {WATCHER_TAXONOMY.families.map((family) => (
                    <Badge key={family} variant="secondary" className="text-xs">
                      {family}
                    </Badge>
                  ))}
                </div>
              </div>
              <div>
                <h4 className="text-sm font-semibold text-muted-foreground mb-3">7 Exploit Archetypes</h4>
                <div className="flex flex-wrap gap-1">
                  {WATCHER_TAXONOMY.exploitArchetypes.map((archetype) => (
                    <Badge key={archetype} variant="outline" className="text-xs font-mono text-destructive border-destructive/30">
                      {archetype}
                    </Badge>
                  ))}
                </div>
              </div>
              <div>
                <h4 className="text-sm font-semibold text-muted-foreground mb-3">7 Defense Paradigms</h4>
                <div className="flex flex-wrap gap-1">
                  {WATCHER_TAXONOMY.defenseParadigms.map((paradigm) => (
                    <Badge key={paradigm} variant="outline" className="text-xs font-mono text-green-500 border-green-500/30">
                      {paradigm}
                    </Badge>
                  ))}
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* A2A Manifest Code */}
        <Card className="bg-background/50 border-border/50 overflow-hidden">
          <CardHeader className="border-b border-border/50 py-3">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-destructive/50" />
              <div className="w-3 h-3 rounded-full bg-primary/50" />
              <div className="w-3 h-3 rounded-full bg-green-500/50" />
              <span className="ml-2 text-sm text-muted-foreground">agent-manifest.json — A2A Discovery Protocol</span>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <pre className="p-6 overflow-x-auto text-sm max-h-96">
              <code className="text-foreground/80">
{JSON.stringify(A2A_MANIFEST, null, 2)}
              </code>
            </pre>
          </CardContent>
        </Card>
      </div>
    </section>
  )
}
