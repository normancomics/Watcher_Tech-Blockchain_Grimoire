import { listChapters } from "@/lib/x402/chapters"
import { json, rateLimited, publicBase } from "@/lib/x402"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

// Free: chapter index with teasers. Full text is paid at /api/chapter.
export async function GET(req: Request) {
  const limited = rateLimited(req); if (limited) return limited
  const chapters = (await listChapters()).map(({ file, ...c }) => ({ ...c, fullText: `${publicBase(req)}/api/chapter?slug=${encodeURIComponent(c.slug)}` }))
  return json({ count: chapters.length, priceUsdPerChapter: 0.02, chapters })
}
