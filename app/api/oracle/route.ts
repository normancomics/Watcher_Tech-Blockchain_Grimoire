import { paid } from "@/lib/x402"
import { ROUTES } from "@/lib/x402/routes"
import { oracle } from "@/lib/x402/chapters"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export const GET = paid(ROUTES.oracle, async (req) => {
  const q = new URL(req.url).searchParams.get("q")?.trim()
  if (!q) return { status: 400, body: { error: "q query param required" } }
  return { status: 200, body: { q, results: await oracle(q) } }
})
