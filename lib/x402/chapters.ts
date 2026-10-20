// Reads the grimoire's markdown chapters from the repo at runtime (no external services).
import { promises as fs } from "node:fs"
import path from "node:path"

const ROOT = process.cwd()
const DIRS = ["01_Foundation", "02_Encoding", "03_Knowledge_Transmission", "04_Guardianship_Archetypes", "05_Temporal_Gates_Alchemy", "09_Precognition_Modifiers"]

export interface Chapter { slug: string; section: string; title: string; words: number; teaser: string; file: string }
let cache: Chapter[] | null = null

const titleOf = (md: string, file: string) =>
  md.match(/^#\s+(.+)$/m)?.[1].trim() ?? path.basename(file, ".md").replace(/_/g, " ")

function teaserOf(md: string) {
  const para = md.replace(/```[\s\S]*?```/g, "").split(/\n\s*\n/).map((p) => p.replace(/^#+\s.*$/gm, "").trim())
    .find((p) => p.length > 60 && !/^[|>\-*]/.test(p)) ?? ""
  return para.replace(/\s+/g, " ").slice(0, 240) + (para.length > 240 ? "…" : "")
}

export async function listChapters(): Promise<Chapter[]> {
  if (cache) return cache
  const out: Chapter[] = []
  for (const dir of DIRS) {
    let files: string[] = []
    try { files = (await fs.readdir(path.join(ROOT, dir))).filter((f) => f.endsWith(".md")).sort() } catch { continue }
    for (const f of files) {
      const file = path.join(dir, f)
      const md = await fs.readFile(path.join(ROOT, file), "utf8")
      out.push({ slug: `${dir}/${f.replace(/\.md$/, "")}`.toLowerCase(), section: dir.replace(/^\d+_/, "").replace(/_/g, " "),
        title: titleOf(md, f), words: md.split(/\s+/).filter(Boolean).length, teaser: teaserOf(md), file })
    }
  }
  return (cache = out)
}

export async function readChapter(slug: string) {
  const ch = (await listChapters()).find((c) => c.slug === slug.toLowerCase().replace(/\.md$/, ""))
  if (!ch) return undefined
  return { ...ch, markdown: await fs.readFile(path.join(ROOT, ch.file), "utf8") }
}

/** Keyword "oracle": ranks passages across all chapters by term overlap. Deterministic, no AI. */
export async function oracle(q: string, limit = 5) {
  const terms = q.toLowerCase().split(/[^a-z0-9]+/).filter((t) => t.length > 2)
  if (!terms.length) return []
  const results: { slug: string; title: string; score: number; passage: string }[] = []
  for (const ch of await listChapters()) {
    const md = await fs.readFile(path.join(ROOT, ch.file), "utf8")
    for (const para of md.split(/\n\s*\n/)) {
      const p = para.trim(); if (p.length < 80) continue
      const low = p.toLowerCase()
      const score = terms.reduce((s, t) => s + (low.split(t).length - 1), 0)
      if (score) results.push({ slug: ch.slug, title: ch.title, score, passage: p.slice(0, 1200) })
    }
  }
  return results.sort((a, b) => b.score - a.score).slice(0, limit)
}
