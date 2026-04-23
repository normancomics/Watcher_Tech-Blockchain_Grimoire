"use client"

import { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { PAYMENT_CONFIG } from "@/lib/agent-config"
import { Github, ExternalLink, Bot, Zap, Shield, Copy, Check } from "lucide-react"

export function HeroSection() {
  const [mounted, setMounted] = useState(false)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  const copyAddress = () => {
    navigator.clipboard.writeText(PAYMENT_CONFIG.address)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
      {/* Animated background */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-primary/10 via-background to-background" />
      
      {/* Sigil pattern overlay */}
      <div className="absolute inset-0 opacity-5">
        <svg className="w-full h-full" viewBox="0 0 100 100" preserveAspectRatio="none">
          <defs>
            <pattern id="sigil-pattern" x="0" y="0" width="20" height="20" patternUnits="userSpaceOnUse">
              <circle cx="10" cy="10" r="0.5" fill="currentColor" className="text-primary" />
              <path d="M10 0 L10 20 M0 10 L20 10" stroke="currentColor" strokeWidth="0.1" className="text-primary/30" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#sigil-pattern)" />
        </svg>
      </div>

      {/* Floating sigils */}
      {mounted && (
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          {[...Array(8)].map((_, i) => (
            <div
              key={i}
              className="absolute text-primary/10 text-6xl animate-pulse"
              style={{
                left: `${10 + i * 12}%`,
                top: `${15 + (i % 4) * 20}%`,
                animationDelay: `${i * 0.5}s`,
                animationDuration: `${3 + i}s`,
              }}
            >
              {["⛧", "⛤", "☽", "⚗", "⚕", "☿", "⌘", "◈"][i]}
            </div>
          ))}
        </div>
      )}

      <div className="relative z-10 max-w-5xl mx-auto px-6 text-center">
        {/* Agent-focused badges */}
        <div className="flex flex-wrap justify-center gap-2 mb-8">
          <Badge variant="outline" className="border-primary/30 text-primary">
            <Bot className="w-3 h-3 mr-1" />
            MCP Native
          </Badge>
          <Badge variant="outline" className="border-primary/30 text-primary">
            <Zap className="w-3 h-3 mr-1" />
            x402 Payments
          </Badge>
          <Badge variant="outline" className="border-primary/30 text-primary">
            <Shield className="w-3 h-3 mr-1" />
            ERC-8004 Identity
          </Badge>
        </div>

        {/* Main title */}
        <h1 className="font-serif text-4xl sm:text-5xl md:text-7xl font-bold tracking-tight mb-6">
          <span className="block text-foreground">Antediluvian</span>
          <span className="block text-primary">Blockchain Grimoire</span>
        </h1>

        {/* Quote */}
        <blockquote className="max-w-2xl mx-auto text-muted-foreground italic text-base sm:text-lg mb-8 border-l-2 border-primary/30 pl-4 text-left">
          &ldquo;They taught men to make swords... and the art of making bracelets and ornaments... 
          and all kinds of costly stones and all colouring tinctures. And there arose much godlessness.&rdquo;
          <cite className="block text-sm text-primary/80 mt-2 not-italic">— 1 Enoch 8</cite>
        </blockquote>

        {/* Description */}
        <p className="max-w-2xl mx-auto text-muted-foreground text-lg mb-6">
          An on-chain grimoire reverse-engineering antediluvian Watcher transmissions 
          into modern blockchain, DeFi, AI, and quantum frameworks.
        </p>

        {/* Payment address banner */}
        <div className="max-w-xl mx-auto mb-10">
          <button
            onClick={copyAddress}
            className="w-full flex items-center justify-between gap-2 px-4 py-3 rounded-lg bg-card/50 border border-border/50 hover:border-primary/30 transition-colors group"
          >
            <div className="flex items-center gap-2 min-w-0">
              <span className="text-sm text-muted-foreground shrink-0">Treasury:</span>
              <span className="font-mono text-sm text-primary truncate">{PAYMENT_CONFIG.ens}</span>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              {copied ? (
                <Check className="w-4 h-4 text-green-500" />
              ) : (
                <Copy className="w-4 h-4 text-muted-foreground group-hover:text-primary transition-colors" />
              )}
            </div>
          </button>
        </div>

        {/* CTA Buttons */}
        <div className="flex flex-col sm:flex-row gap-4 justify-center items-center mb-12">
          <Button asChild size="lg" className="gap-2 font-medium px-8">
            <a
              href="https://github.com/normancomics/Watcher_Tech-Blockchain_Grimoire"
              target="_blank"
              rel="noopener noreferrer"
            >
              <Github className="w-5 h-5" />
              View on GitHub
            </a>
          </Button>
          <Button asChild variant="outline" size="lg" className="gap-2 font-medium px-8">
            <a href="#oracle">
              <Bot className="w-5 h-5" />
              Explore MCP Server
            </a>
          </Button>
          <Button asChild variant="outline" size="lg" className="gap-2 font-medium px-8">
            <a href="#payments">
              <Zap className="w-5 h-5" />
              Payment Protocol
            </a>
          </Button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-6 max-w-3xl mx-auto">
          {[
            { label: "MCP Tools", value: "8" },
            { label: "Smart Contracts", value: "6" },
            { label: "RAG Documents", value: "11K+" },
            { label: "Watcher Families", value: "13" },
          ].map((stat) => (
            <div key={stat.label} className="text-center">
              <div className="text-2xl sm:text-3xl font-bold text-primary">{stat.value}</div>
              <div className="text-sm text-muted-foreground">{stat.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Scroll indicator */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 animate-bounce">
        <div className="w-6 h-10 rounded-full border-2 border-primary/30 flex items-start justify-center p-2">
          <div className="w-1 h-2 bg-primary rounded-full animate-pulse" />
        </div>
      </div>
    </section>
  )
}
