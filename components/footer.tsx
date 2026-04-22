"use client"

import { useState } from "react"
import { Github, ExternalLink, Copy, Check, Wallet } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { PAYMENT_CONFIG } from "@/lib/agent-config"

export function Footer() {
  const [copied, setCopied] = useState(false)

  const copyAddress = () => {
    navigator.clipboard.writeText(PAYMENT_CONFIG.address)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const techStack = [
    "TypeScript",
    "Python", 
    "Solidity",
    "MCP",
    "x402",
    "ERC-8004",
    "RAG-AGI",
    "PQC",
    "A2A",
  ]

  return (
    <footer className="py-16 px-6 border-t border-border/50 bg-card/20">
      <div className="max-w-6xl mx-auto">
        {/* CTA Section */}
        <div className="text-center mb-12">
          <span className="text-primary text-4xl mb-4 block">⛧</span>
          <h2 className="font-serif text-2xl sm:text-3xl font-bold mb-4 text-balance">
            The Convergence is Now On-Chain
          </h2>
          <p className="text-muted-foreground max-w-lg mx-auto mb-8">
            Integrate the Grimoire Oracle into your agent workflow. 
            All payments settle directly to the sovereign treasury.
          </p>

          {/* Payment Address */}
          <div className="max-w-md mx-auto mb-8">
            <button
              onClick={copyAddress}
              className="w-full flex items-center justify-between gap-4 px-5 py-4 rounded-lg bg-card border border-primary/20 hover:border-primary/40 transition-colors group"
            >
              <div className="flex items-center gap-3 min-w-0">
                <Wallet className="w-5 h-5 text-primary shrink-0" />
                <div className="text-left min-w-0">
                  <div className="text-sm text-muted-foreground">Treasury Address</div>
                  <div className="font-mono text-sm text-primary truncate">{PAYMENT_CONFIG.ens}</div>
                </div>
              </div>
              <div className="shrink-0">
                {copied ? (
                  <Badge className="bg-green-500/10 text-green-500 border-green-500/20">
                    <Check className="w-3 h-3 mr-1" />
                    Copied
                  </Badge>
                ) : (
                  <Copy className="w-4 h-4 text-muted-foreground group-hover:text-primary transition-colors" />
                )}
              </div>
            </button>
            <div className="mt-2 text-xs text-muted-foreground font-mono truncate px-2">
              {PAYMENT_CONFIG.address}
            </div>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button asChild size="lg" className="gap-2">
              <a
                href="https://github.com/normancomics/Watcher_Tech-Blockchain_Grimoire"
                target="_blank"
                rel="noopener noreferrer"
              >
                <Github className="w-5 h-5" />
                Clone Repository
              </a>
            </Button>
            <Button asChild variant="outline" size="lg" className="gap-2">
              <a
                href="https://github.com/normancomics/Watcher_Tech-Blockchain_Grimoire/issues"
                target="_blank"
                rel="noopener noreferrer"
              >
                <ExternalLink className="w-5 h-5" />
                Open Issues
              </a>
            </Button>
          </div>
        </div>

        {/* Tech stack badges */}
        <div className="flex flex-wrap justify-center gap-2 mb-12">
          {techStack.map((tech) => (
            <Badge
              key={tech}
              variant="outline"
              className="font-mono text-xs border-border/50 hover:border-primary/30 transition-colors"
            >
              {tech}
            </Badge>
          ))}
        </div>

        {/* Agent Discovery Metadata */}
        <div className="text-center mb-8 p-4 rounded-lg bg-secondary/20 border border-border/30">
          <div className="text-xs text-muted-foreground mb-2">Agent Discovery Endpoints</div>
          <div className="flex flex-wrap justify-center gap-4 font-mono text-xs">
            <span className="text-primary">mcp://grimoire-oracle</span>
            <span className="text-muted-foreground">|</span>
            <span className="text-primary">a2a://grimoire.normancomics.eth</span>
            <span className="text-muted-foreground">|</span>
            <span className="text-primary">x402://localhost:8402</span>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-8 border-t border-border/30">
          <div className="flex items-center gap-2">
            <span className="text-primary">⛧</span>
            <span className="font-serif text-sm font-medium">Blockchain Grimoire</span>
          </div>
          <p className="text-sm text-muted-foreground text-center">
            <span className="font-medium">THE ETERNAL SIGIL</span> — {PAYMENT_CONFIG.ens} 2026 A.D.
          </p>
          <div className="text-sm text-muted-foreground">
            MIT License
          </div>
        </div>
      </div>
    </footer>
  )
}
