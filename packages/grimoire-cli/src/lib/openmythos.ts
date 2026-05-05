/**
 * OpenMythos adapter — provides a unified interface for the OpenMythos library
 * with offline/mock mode support and seed-based deterministic generation.
 *
 * OpenMythos (@kyegomez/openmythos) is an optional dependency.
 * When not installed, the CLI falls back to mock mode automatically.
 *
 * Mock mode uses a seeded PRNG to produce deterministic placeholder outputs
 * that conform to the corpus schemas, allowing CI pipelines to run without
 * an active OpenMythos API key.
 */

import seedrandom, { type PRNG } from "seedrandom";
import type { OpenMythosConfig } from "./config.js";
import type { EpistemicStatus } from "./config.js";

export type ArtifactType = "entry" | "entity" | "faction" | "ritual" | "timeline";

export interface GenerationRequest {
  type: ArtifactType;
  prompt: string;
  epistemicStatus?: EpistemicStatus;
  seed?: number;
  tags?: string[];
  citations?: string[];
}

export interface GenerationResult {
  id: string;
  type: ArtifactType;
  content: Record<string, unknown>;
  generatedBy: string;
  mock: boolean;
}

/**
 * Attempt to dynamically load the real OpenMythos library.
 * Returns null if not installed (will use mock mode instead).
 */
async function tryLoadOpenMythos(): Promise<unknown | null> {
  try {
    // Dynamic import — this will fail if @kyegomez/openmythos is not installed
    // @ts-expect-error — optional peer dependency, may not be installed
    const mod = await import("@kyegomez/openmythos");
    return mod;
  } catch {
    return null;
  }
}

export class OpenMythosAdapter {
  private config: OpenMythosConfig;
  private rng: PRNG;
  private realClient: unknown | null = null;
  private initialized = false;

  constructor(config: OpenMythosConfig, seed = 42) {
    this.config = config;
    this.rng = seedrandom(String(seed));
  }

  async initialize(): Promise<void> {
    if (this.initialized) return;
    this.initialized = true;

    if (this.config.mode === "online") {
      this.realClient = await tryLoadOpenMythos();
      if (!this.realClient) {
        console.warn(
          "[grimoire] @kyegomez/openmythos not installed — falling back to mock mode.\n" +
            "           To use online mode: npm install @kyegomez/openmythos"
        );
        this.config.mode = "mock";
      }
    }
  }

  get isMock(): boolean {
    return this.config.mode === "mock" || !this.realClient;
  }

  /**
   * Generate a corpus artifact using OpenMythos or mock mode.
   */
  async generate(request: GenerationRequest): Promise<GenerationResult> {
    await this.initialize();

    if (this.isMock) {
      return this.mockGenerate(request);
    }

    return this.onlineGenerate(request);
  }

  /** Online generation via the real OpenMythos library */
  private async onlineGenerate(request: GenerationRequest): Promise<GenerationResult> {
    // The actual OpenMythos API call would go here.
    // This is a placeholder for when the library is available.
    // The interface below follows the expected OpenMythos agent pattern.
    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const client = this.realClient as any;
      if (typeof client?.generate === "function") {
        // eslint-disable-next-line @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-assignment
        const result = await client.generate({
          prompt: request.prompt,
          model: this.config.model,
          type: request.type,
          metadata: {
            epistemic_status: request.epistemicStatus ?? "speculative",
            citations: request.citations ?? [],
            tags: request.tags ?? [],
          },
        });
        return {
          id: slugify(request.prompt.slice(0, 40)),
          type: request.type,
          // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
          content: result as Record<string, unknown>,
          generatedBy: `openmythos/${this.config.model}`,
          mock: false,
        };
      }
    } catch (err) {
      console.warn(`[grimoire] OpenMythos online generation failed: ${(err as Error).message}`);
      console.warn("[grimoire] Falling back to mock mode for this request.");
    }

    return this.mockGenerate(request);
  }

  /** Deterministic mock generation using seeded PRNG */
  private mockGenerate(request: GenerationRequest): GenerationResult {
    const id = slugify(request.prompt.slice(0, 40)) + "_" + Math.floor(this.rng() * 1_000_000);
    const epistemicStatus = request.epistemicStatus ?? "fiction";
    const now = new Date().toISOString().split("T")[0];

    let content: Record<string, unknown>;

    switch (request.type) {
      case "entry":
        content = mockEntry(id, request, epistemicStatus, now);
        break;
      case "entity":
        content = mockEntity(id, request, epistemicStatus, now);
        break;
      case "faction":
        content = mockFaction(id, request, epistemicStatus, now);
        break;
      case "ritual":
        content = mockRitual(id, request, epistemicStatus, now);
        break;
      case "timeline":
        content = mockTimeline(id, request, epistemicStatus, now);
        break;
      default:
        content = { id, epistemic_status: epistemicStatus, citations: [], created: now };
    }

    return {
      id,
      type: request.type,
      content,
      generatedBy: "grimoire-cli/mock v1.0",
      mock: true,
    };
  }
}

// ── Mock content generators ─────────────────────────────────────────────────

function mockEntry(
  id: string,
  req: GenerationRequest,
  status: EpistemicStatus,
  date: string
): Record<string, unknown> {
  return {
    id,
    title: req.prompt.slice(0, 80),
    epistemic_status: status,
    citations: req.citations ?? [],
    tags: req.tags ?? ["generated", "mock"],
    created: date,
    author: "grimoire-cli/mock",
    generated_by: "grimoire-cli/mock v1.0",
    body: `[MOCK] This entry was generated in offline mock mode.\n\nPrompt: "${req.prompt}"\n\nReplace this content by running in online mode with a valid OpenMythos API key.`,
  };
}

function mockEntity(
  id: string,
  req: GenerationRequest,
  status: EpistemicStatus,
  date: string
): Record<string, unknown> {
  return {
    id,
    name: req.prompt.slice(0, 40),
    type: "archetype",
    epistemic_status: status,
    citations: req.citations ?? [],
    description: `[MOCK] Entity generated in offline mode. Prompt: "${req.prompt}"`,
    blockchain_analogue: "[MOCK] Replace with actual blockchain analogue.",
    tags: req.tags ?? ["generated", "mock"],
    created: date,
  };
}

function mockFaction(
  id: string,
  req: GenerationRequest,
  status: EpistemicStatus,
  date: string
): Record<string, unknown> {
  return {
    id,
    name: req.prompt.slice(0, 40),
    epistemic_status: status,
    citations: req.citations ?? [],
    description: `[MOCK] Faction generated in offline mode. Prompt: "${req.prompt}"`,
    blockchain_analogue: "[MOCK] Replace with actual blockchain analogue.",
    members: [],
    doctrines: ["[MOCK] Replace with actual doctrines."],
    tags: req.tags ?? ["generated", "mock"],
    created: date,
  };
}

function mockRitual(
  id: string,
  req: GenerationRequest,
  status: EpistemicStatus,
  date: string
): Record<string, unknown> {
  return {
    id,
    name: req.prompt.slice(0, 40),
    epistemic_status: status,
    citations: req.citations ?? [],
    defensive_focus: true,
    description: `[MOCK] Ritual generated in offline mode. Prompt: "${req.prompt}"\n\nThis is a defensive mnemonic construct — no actionable exploit instructions.`,
    archetype: "mock-archetype",
    moon_phase: "any",
    defense_paradigm: "atlantean-vault",
    tags: req.tags ?? ["generated", "mock", "defensive"],
    created: date,
  };
}

function mockTimeline(
  id: string,
  req: GenerationRequest,
  status: EpistemicStatus,
  date: string
): Record<string, unknown> {
  return {
    id,
    title: req.prompt.slice(0, 80),
    epistemic_status: status,
    citations: req.citations ?? [],
    description: `[MOCK] Timeline generated in offline mode. Prompt: "${req.prompt}"`,
    events: [
      {
        date: date,
        title: "[MOCK] Placeholder Event",
        description: "[MOCK] Replace with actual timeline event.",
        epistemic_status: status,
        citations: [],
        tags: ["generated", "mock"],
      },
    ],
    tags: req.tags ?? ["generated", "mock"],
    created: date,
  };
}

// ── Utilities ───────────────────────────────────────────────────────────────

function slugify(str: string): string {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9\s_-]/g, "")
    .trim()
    .replace(/[\s-]+/g, "_")
    .slice(0, 50);
}
