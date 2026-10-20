import { publicBase } from "@/lib/x402"
import { ROUTES } from "@/lib/x402/routes"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export async function GET(req: Request) {
  const b = publicBase(req)
  const body = [
    "# Watcher Tech Blockchain Grimoire",
    "",
    "> A techno-occult research grimoire: watcher-tech lineage, encoding, knowledge transmission, guardianship archetypes, temporal gates. Agents can browse chapters free and pay per call via x402 (USDC on Base mainnet, payTo normancomics.eth).",
    "",
    "## Free",
    `- [Site](${b}/)`,
    `- [Chapter index](${b}/api/chapters): titles, teasers, word counts, slugs`,
    `- [Agent manifest](${b}/.well-known/agent)`,
    `- [x402 resources](${b}/.well-known/x402)`,
    "",
    "## Paid (x402 v2, exact scheme, eip155:8453, USDC)",
    ...Object.values(ROUTES).map((r) => `- [GET ${r.path}](${b}${r.path}) $${r.priceUsd.toFixed(2)}: ${r.description}`),
    "",
    "Unpaid requests return HTTP 402 with a PAYMENT-REQUIRED header. Pay with any x402 client (PAYMENT-SIGNATURE or X-PAYMENT header). Errors are not charged.",
    "",
  ].join("\n")
  return new Response(body, { headers: { "content-type": "text/plain; charset=utf-8" } })
}
