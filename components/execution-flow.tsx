import { ArrowDown, User, Globe, FileCode, Hash, Users, Cpu, Zap } from "lucide-react"

const steps = [
  {
    icon: User,
    label: "User Intent + Biofeedback",
    description: "Initial input with biometric/intention data",
  },
  {
    icon: Globe,
    label: "Planetary Alignment Check",
    sublabel: "(Python)",
    description: "Validate timing against celestial positions",
  },
  {
    icon: FileCode,
    label: "Ritual Sequence Verification",
    sublabel: "(Python)",
    description: "Verify correct procedural ordering",
  },
  {
    icon: Hash,
    label: "Symbolic Encoding",
    sublabel: "→ encodedRitual hash",
    description: "Convert to cryptographic representation",
  },
  {
    icon: Users,
    label: "Guardian/Watcher Layer",
    sublabel: "(multisig alignment)",
    description: "Multi-signature authorization check",
  },
  {
    icon: Cpu,
    label: "Smart Contract Execution",
    sublabel: "(Solidity)",
    description: "On-chain execution of validated ritual",
  },
  {
    icon: Zap,
    label: "Output",
    sublabel: "Financial / Informational / Symbolic",
    description: "Transaction result manifestation",
  },
]

export function ExecutionFlow() {
  return (
    <section id="flow" className="py-24 px-6">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-16">
          <span className="text-primary text-2xl">⚡</span>
          <h2 className="font-serif text-3xl sm:text-4xl font-bold mt-4 mb-4 text-balance">
            Execution Flow
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
            From user intent to on-chain output — the complete ritual-to-transaction pipeline.
          </p>
        </div>

        <div className="relative">
          {/* Connecting line */}
          <div className="absolute left-1/2 top-0 bottom-0 w-px bg-border -translate-x-1/2 hidden md:block" />

          <div className="space-y-6">
            {steps.map((step, index) => (
              <div key={step.label} className="relative">
                {/* Step card */}
                <div className={`flex items-center gap-6 ${index % 2 === 0 ? 'md:flex-row' : 'md:flex-row-reverse'}`}>
                  <div className={`flex-1 ${index % 2 === 0 ? 'md:text-right' : 'md:text-left'}`}>
                    <div className={`inline-block p-6 rounded-lg bg-card/50 border border-border/50 hover:border-primary/30 transition-colors max-w-sm ${index % 2 === 0 ? 'md:ml-auto' : 'md:mr-auto'}`}>
                      <div className={`flex items-center gap-3 mb-2 ${index % 2 === 0 ? 'md:flex-row-reverse' : ''}`}>
                        <div className="p-2 rounded-lg bg-primary/10">
                          <step.icon className="w-4 h-4 text-primary" />
                        </div>
                        <div className={index % 2 === 0 ? 'md:text-right' : ''}>
                          <h3 className="font-medium text-sm">{step.label}</h3>
                          {step.sublabel && (
                            <span className="text-xs text-primary/70 font-mono">{step.sublabel}</span>
                          )}
                        </div>
                      </div>
                      <p className={`text-sm text-muted-foreground ${index % 2 === 0 ? 'md:text-right' : ''}`}>
                        {step.description}
                      </p>
                    </div>
                  </div>

                  {/* Center node */}
                  <div className="hidden md:flex items-center justify-center w-10 h-10 rounded-full bg-card border-2 border-primary/50 z-10">
                    <span className="text-xs font-bold text-primary">{index + 1}</span>
                  </div>

                  <div className="flex-1 hidden md:block" />
                </div>

                {/* Arrow between steps */}
                {index < steps.length - 1 && (
                  <div className="flex justify-center my-2 md:hidden">
                    <ArrowDown className="w-4 h-4 text-primary/30" />
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
