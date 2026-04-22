"use client"

import { useEffect, useRef, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { QUANTUM_CONFIG } from "@/lib/agent-config"
import { Atom, Shield, Key, Lock, Shuffle, Fingerprint } from "lucide-react"

export function QuantumSection() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [entropy, setEntropy] = useState<string[]>([])

  // Generate quantum-style entropy visualization
  useEffect(() => {
    const generateEntropy = () => {
      const bytes = new Uint8Array(32)
      crypto.getRandomValues(bytes)
      const hex = Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('')
      setEntropy(prev => [hex, ...prev.slice(0, 4)])
    }
    
    generateEntropy()
    const interval = setInterval(generateEntropy, 2000)
    return () => clearInterval(interval)
  }, [])

  // Quantum field animation
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const resize = () => {
      canvas.width = canvas.offsetWidth * window.devicePixelRatio
      canvas.height = canvas.offsetHeight * window.devicePixelRatio
      ctx.scale(window.devicePixelRatio, window.devicePixelRatio)
    }
    resize()
    window.addEventListener('resize', resize)

    const particles: { x: number; y: number; vx: number; vy: number; phase: number }[] = []
    for (let i = 0; i < 50; i++) {
      particles.push({
        x: Math.random() * canvas.offsetWidth,
        y: Math.random() * canvas.offsetHeight,
        vx: (Math.random() - 0.5) * 0.5,
        vy: (Math.random() - 0.5) * 0.5,
        phase: Math.random() * Math.PI * 2,
      })
    }

    let animationId: number
    const animate = () => {
      ctx.clearRect(0, 0, canvas.offsetWidth, canvas.offsetHeight)
      
      particles.forEach((p, i) => {
        p.x += p.vx
        p.y += p.vy
        p.phase += 0.02
        
        if (p.x < 0 || p.x > canvas.offsetWidth) p.vx *= -1
        if (p.y < 0 || p.y > canvas.offsetHeight) p.vy *= -1

        const alpha = (Math.sin(p.phase) + 1) / 4 + 0.1
        ctx.fillStyle = `rgba(212, 162, 74, ${alpha})`
        ctx.beginPath()
        ctx.arc(p.x, p.y, 2, 0, Math.PI * 2)
        ctx.fill()

        // Draw connections
        particles.slice(i + 1).forEach((p2) => {
          const dx = p2.x - p.x
          const dy = p2.y - p.y
          const dist = Math.sqrt(dx * dx + dy * dy)
          if (dist < 80) {
            ctx.strokeStyle = `rgba(212, 162, 74, ${(1 - dist / 80) * 0.1})`
            ctx.beginPath()
            ctx.moveTo(p.x, p.y)
            ctx.lineTo(p2.x, p2.y)
            ctx.stroke()
          }
        })
      })

      animationId = requestAnimationFrame(animate)
    }
    animate()

    return () => {
      window.removeEventListener('resize', resize)
      cancelAnimationFrame(animationId)
    }
  }, [])

  const features = [
    {
      icon: Key,
      title: "CRYSTALS-Kyber",
      description: "Lattice-based key encapsulation mechanism resistant to Shor's algorithm",
      spec: "Kyber-1024",
    },
    {
      icon: Fingerprint,
      title: "CRYSTALS-Dilithium",
      description: "Post-quantum digital signatures for agent attestation",
      spec: "Dilithium-5",
    },
    {
      icon: Shield,
      title: "SPHINCS+",
      description: "Hash-based signatures for long-term security guarantees",
      spec: "SPHINCS+-256f",
    },
    {
      icon: Shuffle,
      title: "Quantum RNG",
      description: "Verifiable entropy source for on-chain randomness",
      spec: "1024 bits/s",
    },
    {
      icon: Lock,
      title: "Commit-Reveal",
      description: "Front-running resistant randomness with cryptographic commitment",
      spec: "SHA3-256",
    },
    {
      icon: Atom,
      title: "Merkle Trees",
      description: "Quantum-resistant state verification with deep tree structures",
      spec: "Depth 32",
    },
  ]

  return (
    <section id="quantum" className="py-24 px-6 relative overflow-hidden">
      {/* Animated quantum field background */}
      <canvas
        ref={canvasRef}
        className="absolute inset-0 w-full h-full opacity-30"
      />

      <div className="max-w-6xl mx-auto relative z-10">
        <div className="text-center mb-16">
          <Badge variant="outline" className="mb-4 border-primary/30 text-primary">
            <Atom className="w-3 h-3 mr-1" />
            Post-Quantum Cryptography
          </Badge>
          <h2 className="font-serif text-3xl sm:text-4xl font-bold mt-4 mb-4 text-balance">
            Quantum-Resistant Security Layer
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
            Future-proofed cryptographic primitives implementing NIST PQC standards. 
            Protecting agent communications and on-chain settlements against quantum adversaries.
          </p>
        </div>

        {/* Live Entropy Feed */}
        <Card className="mb-12 bg-card/80 border-primary/20 backdrop-blur-sm overflow-hidden">
          <CardHeader className="border-b border-border/50">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="flex items-center gap-2">
                  <Shuffle className="w-5 h-5 text-primary" />
                  Live Quantum Entropy Stream
                </CardTitle>
                <CardDescription>
                  Cryptographically secure random bytes — {QUANTUM_CONFIG.entropy.bitRate} bits/sec
                </CardDescription>
              </div>
              <Badge className="bg-green-500/10 text-green-500 border-green-500/20 animate-pulse">
                ACTIVE
              </Badge>
            </div>
          </CardHeader>
          <CardContent className="pt-4">
            <div className="space-y-2">
              {entropy.map((hex, i) => (
                <div
                  key={i}
                  className="font-mono text-xs sm:text-sm text-foreground/80 p-2 rounded bg-secondary/30 overflow-x-auto transition-all duration-500"
                  style={{ opacity: 1 - i * 0.2 }}
                >
                  <span className="text-primary mr-2">0x</span>
                  {hex.match(/.{1,8}/g)?.join(' ')}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* PQC Features Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          {features.map((feature) => (
            <Card key={feature.title} className="bg-card/50 border-border/50 hover:border-primary/30 transition-colors group">
              <CardContent className="pt-6">
                <div className="flex items-start gap-4">
                  <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center shrink-0 group-hover:bg-primary/20 transition-colors">
                    <feature.icon className="w-5 h-5 text-primary" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="font-semibold">{feature.title}</h3>
                      <Badge variant="outline" className="text-xs font-mono">
                        {feature.spec}
                      </Badge>
                    </div>
                    <p className="text-sm text-muted-foreground">{feature.description}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Algorithm Specs */}
        <Card className="bg-background/50 border-border/50 overflow-hidden">
          <CardHeader className="border-b border-border/50 py-3">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-destructive/50" />
              <div className="w-3 h-3 rounded-full bg-primary/50" />
              <div className="w-3 h-3 rounded-full bg-green-500/50" />
              <span className="ml-2 text-sm text-muted-foreground">quantum-config.json — PQC Parameters</span>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <pre className="p-6 overflow-x-auto text-sm">
              <code className="text-foreground/80">
{JSON.stringify(QUANTUM_CONFIG, null, 2)}
              </code>
            </pre>
          </CardContent>
        </Card>
      </div>
    </section>
  )
}
