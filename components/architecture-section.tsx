import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Layers, Code, BookOpen, Shield, Zap, Lock } from "lucide-react"

const layers = [
  {
    icon: Layers,
    title: "Foundation",
    ancient: "Watcher transmissions (1 Enoch)",
    modern: "Core thesis & lineage maps",
    files: "docs/core/, docs/lineage/",
  },
  {
    icon: Code,
    title: "Encoding",
    ancient: "Proto-Canaanite symbols, ritual ciphers",
    modern: "Cryptographic hashes, EVM opcodes",
    files: "docs/languages/, docs/codex/",
  },
  {
    icon: BookOpen,
    title: "Transmission",
    ancient: "Priesthoods → Grimoires → Mystery Schools",
    modern: "Reverse knowledge tree",
    files: "docs/knowledge_tree/",
  },
  {
    icon: Shield,
    title: "Guardianship",
    ancient: "7 Watchers → 7 Sages → 13 Families",
    modern: "On-chain registries, alignment checks",
    files: "contracts/, 13_Families/",
  },
  {
    icon: Zap,
    title: "Execution",
    ancient: "Ritual sequences, planetary timing",
    modern: "Smart contracts, Python validation",
    files: "contracts/, scripts/",
  },
  {
    icon: Lock,
    title: "Defense",
    ancient: "Seals & wards against misuse",
    modern: "7 defensive paradigms, reentrancy guards",
    files: "contracts/AtlanteanDefenseVault.sol",
  },
]

export function ArchitectureSection() {
  return (
    <section id="architecture" className="py-24 px-6 bg-card/30">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <span className="text-primary text-2xl">⚗</span>
          <h2 className="font-serif text-3xl sm:text-4xl font-bold mt-4 mb-4 text-balance">
            Layered Techno-Occult Framework
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
            The grimoire implements a comprehensive system mapping ancient knowledge 
            transmission to modern blockchain architecture.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {layers.map((layer, index) => (
            <Card key={layer.title} className="bg-card/50 border-border/50 hover:border-primary/30 transition-colors">
              <CardHeader>
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-primary/10">
                    <layer.icon className="w-5 h-5 text-primary" />
                  </div>
                  <CardTitle className="font-serif text-lg">{layer.title}</CardTitle>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <p className="text-xs uppercase tracking-wider text-muted-foreground mb-1">Ancient Source</p>
                  <p className="text-sm text-foreground/80">{layer.ancient}</p>
                </div>
                <div>
                  <p className="text-xs uppercase tracking-wider text-muted-foreground mb-1">Modern Analogue</p>
                  <p className="text-sm text-foreground/80">{layer.modern}</p>
                </div>
                <div className="pt-2 border-t border-border/50">
                  <code className="text-xs text-primary/70 font-mono">{layer.files}</code>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}
