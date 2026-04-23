"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { PAYMENT_CONFIG, TOOL_PRICING } from "@/lib/agent-config"
import { Copy, Check, Wallet, Zap, Shield, Globe } from "lucide-react"

export function PaymentSection() {
  const [copied, setCopied] = useState<string | null>(null)

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text)
    setCopied(id)
    setTimeout(() => setCopied(null), 2000)
  }

  const networks = [
    { name: "Ethereum", chainId: 1, icon: "ETH", color: "text-blue-400" },
    { name: "Base", chainId: 8453, icon: "BASE", color: "text-blue-500" },
    { name: "Optimism", chainId: 10, icon: "OP", color: "text-red-400" },
    { name: "Arbitrum", chainId: 42161, icon: "ARB", color: "text-cyan-400" },
    { name: "Polygon", chainId: 137, icon: "MATIC", color: "text-purple-400" },
  ]

  return (
    <section id="payments" className="py-24 px-6 relative overflow-hidden">
      {/* Quantum grid background */}
      <div className="absolute inset-0 opacity-5">
        <svg className="w-full h-full" viewBox="0 0 100 100" preserveAspectRatio="none">
          <defs>
            <pattern id="quantum-grid" x="0" y="0" width="10" height="10" patternUnits="userSpaceOnUse">
              <path d="M10 0 L0 0 L0 10" fill="none" stroke="currentColor" strokeWidth="0.1" className="text-primary" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#quantum-grid)" />
        </svg>
      </div>

      <div className="max-w-6xl mx-auto relative z-10">
        <div className="text-center mb-16">
          <Badge variant="outline" className="mb-4 border-primary/30 text-primary">
            <Zap className="w-3 h-3 mr-1" />
            x402 Micropayments
          </Badge>
          <h2 className="font-serif text-3xl sm:text-4xl font-bold mt-4 mb-4 text-balance">
            On-Chain Monetization Protocol
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
            All payments flow directly to the sovereign treasury via ERC-8004 compliant 
            agent-to-agent transactions. Zero intermediaries, pure cryptographic settlement.
          </p>
        </div>

        {/* Payment Address Card */}
        <Card className="mb-8 bg-card/80 border-primary/20 backdrop-blur-sm">
          <CardHeader>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <Wallet className="w-6 h-6 text-primary" />
                </div>
                <div>
                  <CardTitle className="text-xl">Treasury Address</CardTitle>
                  <CardDescription>Sovereign Payment Endpoint</CardDescription>
                </div>
              </div>
              <Badge className="bg-primary/10 text-primary border-primary/20">
                ERC-8004 Verified
              </Badge>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* ENS Name */}
            <div className="flex items-center justify-between p-4 rounded-lg bg-secondary/30 border border-border/50">
              <div>
                <div className="text-sm text-muted-foreground mb-1">ENS Domain</div>
                <div className="font-mono text-lg text-primary font-semibold">{PAYMENT_CONFIG.ens}</div>
              </div>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => copyToClipboard(PAYMENT_CONFIG.ens, "ens")}
                className="shrink-0"
              >
                {copied === "ens" ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}
              </Button>
            </div>

            {/* Hex Address */}
            <div className="flex items-center justify-between p-4 rounded-lg bg-secondary/30 border border-border/50">
              <div className="min-w-0 flex-1">
                <div className="text-sm text-muted-foreground mb-1">Ethereum Address</div>
                <div className="font-mono text-sm sm:text-base text-foreground truncate">
                  {PAYMENT_CONFIG.address}
                </div>
              </div>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => copyToClipboard(PAYMENT_CONFIG.address, "address")}
                className="shrink-0 ml-2"
              >
                {copied === "address" ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}
              </Button>
            </div>

            {/* Network Support */}
            <div className="pt-4">
              <div className="text-sm text-muted-foreground mb-3 flex items-center gap-2">
                <Globe className="w-4 h-4" />
                Supported Networks
              </div>
              <div className="flex flex-wrap gap-2">
                {networks.map((network) => (
                  <Badge
                    key={network.chainId}
                    variant="outline"
                    className="font-mono text-xs border-border/50 hover:border-primary/30 transition-colors"
                  >
                    <span className={`mr-1 ${network.color}`}>●</span>
                    {network.name}
                  </Badge>
                ))}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Tool Pricing Grid */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          {Object.entries(TOOL_PRICING).map(([tool, pricing]) => (
            <Card key={tool} className="bg-card/50 border-border/50 hover:border-primary/30 transition-colors">
              <CardContent className="pt-6">
                <div className="flex items-center justify-between mb-3">
                  <Badge variant="secondary" className="font-mono text-xs">
                    {pricing.credits} credits
                  </Badge>
                  <span className="text-primary font-bold">${pricing.usd.toFixed(2)}</span>
                </div>
                <div className="font-mono text-xs text-muted-foreground truncate">
                  {tool}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Payment Protocol Info */}
        <div className="grid md:grid-cols-3 gap-6">
          <Card className="bg-card/50 border-border/50">
            <CardHeader>
              <div className="flex items-center gap-2">
                <Zap className="w-5 h-5 text-primary" />
                <CardTitle className="text-lg">x402 Protocol</CardTitle>
              </div>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              HTTP 402 Payment Required responses with Lightning, ETH, and L2 settlement. 
              Sub-second micropayment finality for real-time agent transactions.
            </CardContent>
          </Card>

          <Card className="bg-card/50 border-border/50">
            <CardHeader>
              <div className="flex items-center gap-2">
                <Shield className="w-5 h-5 text-primary" />
                <CardTitle className="text-lg">ERC-8004 Identity</CardTitle>
              </div>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              On-chain agent registry with verifiable capabilities, payment routing, 
              and cryptographic attestation. Sybil-resistant agent authentication.
            </CardContent>
          </Card>

          <Card className="bg-card/50 border-border/50">
            <CardHeader>
              <div className="flex items-center gap-2">
                <Wallet className="w-5 h-5 text-primary" />
                <CardTitle className="text-lg">Sovereign Treasury</CardTitle>
              </div>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              All payments settle directly to the ENS-linked treasury. No custodians, 
              no intermediaries, no rent-seeking platforms. Pure peer-to-peer value transfer.
            </CardContent>
          </Card>
        </div>

        {/* Payment Integration Code */}
        <Card className="mt-8 bg-background/50 border-border/50 overflow-hidden">
          <CardHeader className="border-b border-border/50 py-3">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-destructive/50" />
              <div className="w-3 h-3 rounded-full bg-primary/50" />
              <div className="w-3 h-3 rounded-full bg-green-500/50" />
              <span className="ml-2 text-sm text-muted-foreground">Agent Payment Integration</span>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <pre className="p-6 overflow-x-auto text-sm">
              <code className="text-foreground/80">
{`// Agent-to-Agent Payment via x402
const response = await fetch("https://grimoire.normancomics.eth/api/audit", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-Payment-Address": "${PAYMENT_CONFIG.address}",
    "X-Payment-Network": "base", // ETH L2 for low fees
  },
  body: JSON.stringify({
    tool: "grimoire_audit_scan",
    params: { code: soliditySource },
    payment: {
      method: "x402",
      maxAmount: "0.50 USD",
      recipient: "${PAYMENT_CONFIG.ens}",
    }
  })
});

// Returns HTTP 402 with payment instructions, then result on settlement`}
              </code>
            </pre>
          </CardContent>
        </Card>
      </div>
    </section>
  )
}
