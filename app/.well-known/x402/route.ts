import { json, publicBase, requirements, FACILITATOR, NETWORK, USDC_BASE, PAY_TO } from "@/lib/x402"
import { ROUTES } from "@/lib/x402/routes"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export async function GET(req: Request) {
  const base = publicBase(req)
  return json({
    x402Version: 2, facilitator: FACILITATOR, network: NETWORK, asset: USDC_BASE, payTo: PAY_TO,
    resources: Object.values(ROUTES).map((r) => ({ resource: base + r.path, method: "GET", description: r.description, priceUsd: r.priceUsd, accepts: [requirements(r)] })),
  })
}
