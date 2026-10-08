import { Info } from "lucide-react"

/**
 * Independent Research & Development Notice
 *
 * Makes it explicit to visitors (human and agent) that this project is
 * standalone R&D exploring blockchain, AI/AGI, RAG-AGI, MCP, and sovereign
 * agentic framework technology — and is NOT BibleFi, nor directly connected
 * to BibleFi in any way, shape, or form.
 */
export function RDDisclaimer() {
  return (
    <section
      aria-label="Research and development disclaimer"
      className="border-y border-primary/20 bg-secondary/10 py-6 px-6"
    >
      <div className="max-w-4xl mx-auto flex gap-3 items-start">
        <Info className="w-5 h-5 text-primary shrink-0 mt-0.5" />
        <p className="text-sm text-muted-foreground leading-relaxed">
          <span className="font-medium text-foreground">Independent R&amp;D notice:</span>{" "}
          This project is an independent, standalone research &amp; development effort. It is
          not BibleFi and is not directly connected to BibleFi in any way, shape, or form.
          It is simply public research and development behind the blockchain, AI/AGI, RAG-AGI,
          MCP, and sovereign agentic framework technologies already used by millions of agents
          and users today. The Watcher/occult narrative is a symbolic, educational device for
          teaching these technical concepts — not a financial product or investment vehicle.
        </p>
      </div>
    </section>
  )
}
