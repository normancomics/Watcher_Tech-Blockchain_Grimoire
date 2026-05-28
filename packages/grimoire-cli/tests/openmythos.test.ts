/**
 * Tests for openmythos.ts — adapter and mock generation
 */

import { OpenMythosAdapter } from "../src/lib/openmythos.js";
import type { OpenMythosConfig } from "../src/lib/config.js";

const mockConfig: OpenMythosConfig = {
  mode: "mock",
  model: "mythos-v1",
  apiKey: "",
  baseUrl: "https://api.openmythos.dev/v1",
  timeout: 30000,
};

describe("OpenMythosAdapter (mock mode)", () => {
  it("initializes in mock mode", async () => {
    const adapter = new OpenMythosAdapter(mockConfig, 42);
    await adapter.initialize();
    expect(adapter.isMock).toBe(true);
  });

  it("generates an entry in mock mode", async () => {
    const adapter = new OpenMythosAdapter(mockConfig, 42);
    const result = await adapter.generate({
      type: "entry",
      prompt: "The Watcher descent at Mount Hermon",
      epistemicStatus: "speculative",
    });

    expect(result.type).toBe("entry");
    expect(result.mock).toBe(true);
    expect(result.content["epistemic_status"]).toBe("speculative");
    expect(Array.isArray(result.content["citations"])).toBe(true);
    expect(result.content["id"]).toBeTruthy();
    expect(result.generatedBy).toContain("mock");
  });

  it("generates an entity in mock mode", async () => {
    const adapter = new OpenMythosAdapter(mockConfig, 99);
    const result = await adapter.generate({
      type: "entity",
      prompt: "Gadreel, watcher of weapons",
      epistemicStatus: "fiction",
    });

    expect(result.type).toBe("entity");
    expect(result.content["type"]).toBe("archetype");
    expect(result.content["epistemic_status"]).toBe("fiction");
  });

  it("generates a ritual in mock mode with defensive_focus", async () => {
    const adapter = new OpenMythosAdapter(mockConfig, 7);
    const result = await adapter.generate({
      type: "ritual",
      prompt: "Flash loan cascade defense ritual",
      epistemicStatus: "fiction",
    });

    expect(result.type).toBe("ritual");
    expect(result.content["defensive_focus"]).toBe(true);
  });

  it("generates a timeline in mock mode", async () => {
    const adapter = new OpenMythosAdapter(mockConfig, 13);
    const result = await adapter.generate({
      type: "timeline",
      prompt: "History of cryptographic knowledge transmission",
      epistemicStatus: "speculative",
    });

    expect(result.type).toBe("timeline");
    expect(Array.isArray(result.content["events"])).toBe(true);
    expect((result.content["events"] as unknown[]).length).toBeGreaterThan(0);
  });

  it("produces deterministic output for same seed and prompt", async () => {
    const adapter1 = new OpenMythosAdapter(mockConfig, 42);
    const adapter2 = new OpenMythosAdapter(mockConfig, 42);

    const result1 = await adapter1.generate({
      type: "entry",
      prompt: "identical prompt for determinism test",
    });
    const result2 = await adapter2.generate({
      type: "entry",
      prompt: "identical prompt for determinism test",
    });

    expect(result1.id).toBe(result2.id);
  });

  it("produces different IDs for different seeds", async () => {
    const adapter1 = new OpenMythosAdapter(mockConfig, 1);
    const adapter2 = new OpenMythosAdapter(mockConfig, 2);

    const result1 = await adapter1.generate({ type: "entry", prompt: "same prompt" });
    const result2 = await adapter2.generate({ type: "entry", prompt: "same prompt" });

    expect(result1.id).not.toBe(result2.id);
  });
});
