import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { FileCode, Vault, BookMarked, Sparkles, KeyRound, AlertTriangle } from "lucide-react"

const contracts = [
  {
    icon: FileCode,
    name: "ArcanusMathematica.sol",
    description: "ERC-721 NFT Grimoire for immutable storage of arcane knowledge on-chain",
    tags: ["ERC-721", "NFT", "Storage"],
  },
  {
    icon: Vault,
    name: "AtlanteanDefenseVault.sol",
    description: "Secure vault implementing 7 defensive paradigms against exploitation",
    tags: ["Security", "Vault", "Defense"],
  },
  {
    icon: BookMarked,
    name: "GoetiaGrimoire.sol",
    description: "On-chain registry mapping Watchers, Sages, Families, and Sigils",
    tags: ["Registry", "Mapping", "Lore"],
  },
  {
    icon: Sparkles,
    name: "OccultGrimoire.sol",
    description: "Dualistic energy mapping implementing light/dark archetype patterns",
    tags: ["Duality", "Archetypes", "Energy"],
  },
  {
    icon: KeyRound,
    name: "OccultKnowledgeAccess.sol",
    description: "Hierarchical knowledge layers with alignment verification checks",
    tags: ["Access Control", "Hierarchy", "Auth"],
  },
  {
    icon: AlertTriangle,
    name: "vulnerability_contract.sol",
    description: "Educational reentrancy vulnerability demonstration for learning",
    tags: ["Educational", "Security", "Demo"],
  },
]

export function ContractsSection() {
  return (
    <section id="contracts" className="py-24 px-6">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <span className="text-primary text-2xl">⛓</span>
          <h2 className="font-serif text-3xl sm:text-4xl font-bold mt-4 mb-4 text-balance">
            Smart Contracts
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
            Solidity contracts implementing the blockchain layer of the grimoire, 
            from NFT storage to security paradigms.
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-6">
          {contracts.map((contract) => (
            <Card key={contract.name} className="bg-card/30 border-border/50 hover:border-primary/30 transition-all hover:bg-card/50">
              <CardHeader className="pb-3">
                <div className="flex items-start gap-3">
                  <div className="p-2 rounded-lg bg-primary/10 shrink-0">
                    <contract.icon className="w-5 h-5 text-primary" />
                  </div>
                  <div className="min-w-0">
                    <CardTitle className="font-mono text-sm sm:text-base truncate">{contract.name}</CardTitle>
                    <CardDescription className="mt-1 text-sm">{contract.description}</CardDescription>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="pt-0">
                <div className="flex flex-wrap gap-2">
                  {contract.tags.map((tag) => (
                    <Badge key={tag} variant="secondary" className="text-xs bg-secondary/50">
                      {tag}
                    </Badge>
                  ))}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}
