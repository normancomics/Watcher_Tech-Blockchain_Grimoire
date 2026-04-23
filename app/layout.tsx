import type { Metadata } from 'next'
import { Cinzel, Inter } from 'next/font/google'
import { Analytics } from '@vercel/analytics/next'
import { AGENT_SCHEMA, PAYMENT_CONFIG } from '@/lib/agent-config'
import './globals.css'

const cinzel = Cinzel({ 
  subsets: ["latin"],
  variable: '--font-cinzel',
  display: 'swap'
});

const inter = Inter({ 
  subsets: ["latin"],
  variable: '--font-inter',
  display: 'swap'
});

export const metadata: Metadata = {
  metadataBase: new URL('https://blockchain-grimoire.vercel.app'),
  title: {
    default: 'Blockchain Grimoire | Antediluvian Watcher Tech',
    template: '%s | Blockchain Grimoire'
  },
  description: 'Sovereign AI agent framework for blockchain security auditing. MCP server with x402 micropayments, RAG-AGI knowledge synthesis, ERC-8004 identity, and post-quantum cryptography. Educational security research + esoteric alchemy.',
  generator: 'v0.app',
  applicationName: 'Blockchain Grimoire',
  referrer: 'origin-when-cross-origin',
  keywords: [
    // Core blockchain terms
    'blockchain', 'smart contracts', 'Solidity', 'DeFi', 'Web3', 'Ethereum',
    // Security terms
    'security audit', 'vulnerability scanner', 'exploit detection', 'threat intelligence',
    // AI/Agent terms
    'MCP server', 'Model Context Protocol', 'AI agent', 'sovereign agent', 'autonomous agent',
    'RAG', 'retrieval augmented generation', 'AGI', 'agentic AI',
    // Protocol terms
    'ERC-8004', 'x402 micropayments', 'agent-to-agent', 'A2A protocol',
    // Quantum terms
    'post-quantum cryptography', 'PQC', 'quantum-resistant', 'CRYSTALS-Kyber',
    // Unique terms
    'grimoire', 'Watcher framework', 'antediluvian', 'esoteric blockchain',
  ],
  authors: [{ name: 'normancomics.eth', url: `https://etherscan.io/address/${PAYMENT_CONFIG.address}` }],
  creator: 'normancomics.eth',
  publisher: 'normancomics.eth',
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://blockchain-grimoire.vercel.app',
    siteName: 'Blockchain Grimoire',
    title: 'Blockchain Grimoire | Sovereign AI Agent for Blockchain Security',
    description: 'MCP server with x402 micropayments, RAG-AGI synthesis, ERC-8004 identity, and quantum-resistant cryptography. 8 monetizable tools, 11K+ document knowledge base.',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Blockchain Grimoire - Antediluvian Watcher Tech',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Blockchain Grimoire | Sovereign AI Agent',
    description: 'MCP server for blockchain security with x402 micropayments. RAG-AGI, ERC-8004 identity, quantum-resistant.',
    images: ['/og-image.png'],
    creator: '@normancomics',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: [
      { url: '/icon-light-32x32.png', media: '(prefers-color-scheme: light)' },
      { url: '/icon-dark-32x32.png', media: '(prefers-color-scheme: dark)' },
      { url: '/icon.svg', type: 'image/svg+xml' },
    ],
    apple: '/apple-icon.png',
  },
  manifest: '/manifest.json',
  alternates: {
    canonical: 'https://blockchain-grimoire.vercel.app',
  },
  category: 'technology',
  classification: 'Blockchain Security, AI Agents, Developer Tools',
  other: {
    // Agent discovery metadata
    'agent:id': 'grimoire-oracle-v1',
    'agent:type': 'sovereign-agent',
    'agent:protocol': 'mcp/1.0, a2a/1.0, x402/1.0',
    'agent:payment-address': PAYMENT_CONFIG.address,
    'agent:payment-ens': PAYMENT_CONFIG.ens,
    // Blockchain metadata
    'ethereum:address': PAYMENT_CONFIG.address,
    'ethereum:ens': PAYMENT_CONFIG.ens,
    'ethereum:network': 'mainnet, base, optimism, arbitrum, polygon',
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className={`${cinzel.variable} ${inter.variable} bg-background`}>
      <head>
        {/* JSON-LD Structured Data for SEO and Agent Discovery */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              ...AGENT_SCHEMA,
              "@context": "https://schema.org",
              "@type": "SoftwareApplication",
              "name": "Blockchain Grimoire",
              "applicationCategory": "DeveloperApplication",
              "applicationSubCategory": "Security Auditing, AI Agent Framework",
              "operatingSystem": "Cross-platform",
              "offers": {
                "@type": "AggregateOffer",
                "lowPrice": "0.10",
                "highPrice": "1.00",
                "priceCurrency": "USD",
                "offerCount": 8,
                "seller": {
                  "@type": "Organization",
                  "name": "normancomics.eth",
                  "identifier": PAYMENT_CONFIG.address,
                  "url": `https://etherscan.io/address/${PAYMENT_CONFIG.address}`
                }
              },
              "author": {
                "@type": "Person",
                "name": "normancomics.eth",
                "identifier": PAYMENT_CONFIG.address
              },
              "potentialAction": {
                "@type": "UseAction",
                "target": {
                  "@type": "EntryPoint",
                  "urlTemplate": "https://github.com/normancomics/Watcher_Tech-Blockchain_Grimoire",
                  "actionPlatform": ["http://schema.org/DesktopWebPlatform"]
                }
              }
            })
          }}
        />
        {/* Agent Manifest Link */}
        <link rel="agent-manifest" href="/agent-manifest.json" />
        {/* MCP Discovery */}
        <meta name="mcp:server" content="grimoire-oracle" />
        <meta name="mcp:tools" content="8" />
        <meta name="mcp:payment" content="x402" />
      </head>
      <body className="font-sans antialiased">
        {children}
        {process.env.NODE_ENV === 'production' && <Analytics />}
      </body>
    </html>
  )
}
