import type { PaidRoute } from "./index"

export const ROUTES: Record<"chapter" | "oracle", PaidRoute> = {
  chapter: {
    path: "/api/chapter", priceUsd: 0.02,
    description: "Full text of one Watcher Tech Blockchain Grimoire chapter (Markdown). List slugs free at /api/chapters.",
    queryParams: { slug: { type: "string", description: "Chapter slug from /api/chapters, e.g. 01_foundation/core_thesis", required: true } },
    inputExample: { slug: "01_foundation/core_thesis" },
    example: { slug: "01_foundation/core_thesis", title: "Core Thesis", markdown: "# Core Thesis ..." },
  },
  oracle: {
    path: "/api/oracle", priceUsd: 0.01,
    description: "Grimoire oracle: keyword search across all chapters, returns the top matching passages with sources.",
    queryParams: { q: { type: "string", description: "Question or keywords, e.g. 'moon phase gates'", required: true } },
    inputExample: { q: "watcher opcodes" },
    example: { q: "watcher opcodes", results: [{ slug: "02_encoding/watcher_opcode_mappings", score: 7, passage: "..." }] },
  },
}
