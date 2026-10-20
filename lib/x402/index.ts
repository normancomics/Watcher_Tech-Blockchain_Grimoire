// Minimal x402 v2 "exact" scheme on Base mainnet using the keyless PayAI facilitator.
// Plain USDC, no API keys. Settles only after the handler succeeds.
export const PAY_TO = process.env.PAY_TO ?? "0x3d95D4A6DbaE0Cd0643a82b13A13b08921D6ADf7"
export const FACILITATOR = process.env.FACILITATOR_URL ?? "https://facilitator.payai.network"
export const USDC_BASE = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
export const NETWORK = "eip155:8453"

export interface PaidRoute {
  path: string
  priceUsd: number
  description: string
  queryParams: Record<string, { type: string; description: string; required?: boolean }>
  inputExample: Record<string, string>
  example: unknown
}

const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64")
export const atomic = (usd: number) => String(Math.round(usd * 1_000_000))

export function publicBase(req?: Request): string {
  const env = process.env.RENDER_EXTERNAL_URL ?? process.env.PUBLIC_URL
  if (env) return env.replace(/\/$/, "")
  if (req) {
    const u = new URL(req.url)
    const proto = req.headers.get("x-forwarded-proto") ?? u.protocol.replace(":", "")
    const host = req.headers.get("x-forwarded-host") ?? req.headers.get("host") ?? u.host
    return `${proto}://${host}`
  }
  return "http://localhost:3000"
}

export function requirements(route: PaidRoute) {
  return {
    scheme: "exact", network: NETWORK, amount: atomic(route.priceUsd), asset: USDC_BASE, payTo: PAY_TO,
    maxTimeoutSeconds: 300, extra: { name: "USD Coin", version: "2" },
  }
}

export function paymentRequired(route: PaidRoute, base: string, error: string) {
  return {
    x402Version: 2, error,
    resource: { url: base + route.path, description: route.description, mimeType: "application/json" },
    accepts: [requirements(route)],
    extensions: {
      bazaar: {
        info: { input: { type: "http", method: "GET", queryParams: route.inputExample }, output: { type: "json", example: route.example } },
        schema: { type: "object", properties: { input: { type: "object", properties: { queryParams: {
          type: "object",
          properties: Object.fromEntries(Object.entries(route.queryParams).map(([k, v]) => [k, { type: v.type, description: v.description }])),
          required: Object.entries(route.queryParams).filter(([, v]) => v.required).map(([k]) => k),
        } } } } },
      },
    },
  }
}

async function facilitator(op: "verify" | "settle", payload: unknown, route: PaidRoute) {
  const res = await fetch(`${FACILITATOR}/${op}`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ x402Version: 2, paymentPayload: payload, paymentRequirements: requirements(route) }),
    signal: AbortSignal.timeout(30_000),
  })
  return (await res.json()) as { isValid?: boolean; invalidReason?: string; success?: boolean; errorReason?: string }
}

const json = (body: unknown, status = 200, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "access-control-allow-origin": "*",
    "access-control-expose-headers": "PAYMENT-REQUIRED, PAYMENT-RESPONSE, X-PAYMENT-RESPONSE", ...headers } })

// Per-IP fixed-window rate limit (in-memory; fine for a single free instance).
const hits = new Map<string, { n: number; reset: number }>()
export function rateLimited(req: Request, limit = Number(process.env.RATE_LIMIT_PER_MIN ?? 60)): Response | null {
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "local"
  const now = Date.now(), h = hits.get(ip)
  if (!h || h.reset < now) { hits.set(ip, { n: 1, reset: now + 60_000 }); return null }
  if (++h.n > limit) return json({ error: "Rate limit exceeded" }, 429, { "retry-after": String(Math.ceil((h.reset - now) / 1000)) })
  return null
}

/** Wrap a handler; verify payment first, settle only after the work returns < 400. */
export function paid(route: PaidRoute, work: (req: Request) => Promise<{ status: number; body: unknown }>) {
  return async (req: Request): Promise<Response> => {
    const limited = rateLimited(req); if (limited) return limited
    const deny = (err: string) => { const p = paymentRequired(route, publicBase(req), err); return json(p, 402, { "PAYMENT-REQUIRED": b64(p) }) }
    const sig = req.headers.get("payment-signature") ?? req.headers.get("x-payment")
    if (!sig) return deny("Payment required")
    let payload: unknown
    try { payload = JSON.parse(Buffer.from(sig, "base64").toString("utf8")) } catch { return deny("Malformed payment header") }
    try { const v = await facilitator("verify", payload, route); if (!v.isValid) return deny(v.invalidReason ?? "Invalid payment") }
    catch { return json({ error: "Facilitator verify failed" }, 502) }
    let out: { status: number; body: unknown }
    try { out = await work(req) } catch (e) { return json({ error: (e as Error).message }, 500) }
    if (out.status >= 400) return json(out.body, out.status) // not charged
    try {
      const s = await facilitator("settle", payload, route)
      if (!s.success) return json({ error: "Settlement failed", detail: s }, 402)
      return json(out.body, out.status, { "PAYMENT-RESPONSE": b64(s), "X-PAYMENT-RESPONSE": b64(s) })
    } catch { return json({ error: "Facilitator settle failed" }, 502) }
  }
}
export { json }
