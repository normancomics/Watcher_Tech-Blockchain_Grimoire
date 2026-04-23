import { HeroSection } from "@/components/hero-section"
import { ArchitectureSection } from "@/components/architecture-section"
import { ContractsSection } from "@/components/contracts-section"
import { AgentDiscoverySection } from "@/components/agent-discovery"
import { MCPSection } from "@/components/mcp-section"
import { QuantumSection } from "@/components/quantum-section"
import { PaymentSection } from "@/components/payment-section"
import { ExecutionFlow } from "@/components/execution-flow"
import { RepoStructure } from "@/components/repo-structure"
import { Footer } from "@/components/footer"

export default function Home() {
  return (
    <main className="min-h-screen">
      {/* Hero with agent-focused badges and payment address */}
      <HeroSection />
      
      {/* Agent Discovery - MCP, A2A, ERC-8004 capabilities */}
      <AgentDiscoverySection />
      
      {/* Architecture - 6-layer techno-occult framework */}
      <ArchitectureSection />
      
      {/* MCP Server - 8 monetizable tools */}
      <MCPSection />
      
      {/* Payment Protocol - On-chain monetization */}
      <PaymentSection />
      
      {/* Quantum Security - PQC layer */}
      <QuantumSection />
      
      {/* Smart Contracts - 6 Solidity contracts */}
      <ContractsSection />
      
      {/* Execution Flow - Visual pipeline */}
      <ExecutionFlow />
      
      {/* Repository Structure - File tree */}
      <RepoStructure />
      
      {/* Footer with payment CTA */}
      <Footer />
    </main>
  )
}
