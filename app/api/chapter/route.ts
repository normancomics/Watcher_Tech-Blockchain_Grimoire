import { paid } from "@/lib/x402"
import { ROUTES } from "@/lib/x402/routes"
import { readChapter } from "@/lib/x402/chapters"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export const GET = paid(ROUTES.chapter, async (req) => {
  const slug = new URL(req.url).searchParams.get("slug")?.trim()
  if (!slug) return { status: 400, body: { error: "slug query param required (see /api/chapters)" } }
  const ch = await readChapter(slug)
  if (!ch) return { status: 404, body: { error: "Unknown chapter slug" } }
  const { file, ...rest } = ch
  return { status: 200, body: rest }
})
