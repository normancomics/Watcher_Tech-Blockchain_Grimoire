/**
 * Tests for safety.ts — content labeling and exploit-instruction filter
 */

import {
  checkContent,
  addEpistemicNotice,
  validateSafetyFields,
} from "../src/lib/safety.js";

describe("checkContent", () => {
  it("passes clean defensive content", () => {
    const result = checkContent(
      "This is a defensive description of reentrancy. Use nonReentrant guard to protect against it."
    );
    expect(result.safe).toBe(true);
  });

  it("blocks numbered exploit steps", () => {
    const result = checkContent(
      "Step 1: exploit the contract by calling drain repeatedly."
    );
    expect(result.safe).toBe(false);
    if (!result.safe) {
      expect(result.flaggedPatterns).toContain("numbered exploit steps");
    }
  });

  it("blocks hardcoded private keys", () => {
    const result = checkContent(
      "private key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    );
    expect(result.safe).toBe(false);
    if (!result.safe) {
      expect(result.flaggedPatterns).toContain("hardcoded private key");
    }
  });

  it("blocks how-to exploit instructions", () => {
    const result = checkContent(
      "Here is how to exploit the DeFi contract using flash loans."
    );
    expect(result.safe).toBe(false);
    if (!result.safe) {
      expect(result.flaggedPatterns).toContain("how-to exploit instruction");
    }
  });

  it("passes security content with defensive framing", () => {
    const result = checkContent(
      "Reentrancy vulnerability: use nonReentrant guard to prevent recursive calls. Defensive pattern: CEI."
    );
    expect(result.safe).toBe(true);
  });

  it("blocks security content without defensive framing in security context", () => {
    const result = checkContent(
      "The reentrancy attack vector allows draining funds.",
      true // isSecurityContext = true
    );
    expect(result.safe).toBe(false);
  });
});

describe("addEpistemicNotice", () => {
  it("adds notice for speculative markdown content", () => {
    const content = "# Some Entry\n\nContent here.";
    const result = addEpistemicNotice(content, "speculative", "markdown");
    expect(result).toContain("Epistemic status: speculative");
  });

  it("adds notice for fiction markdown content", () => {
    const content = "# Lore Entry\n\nFiction content.";
    const result = addEpistemicNotice(content, "fiction", "markdown");
    expect(result).toContain("Epistemic status: fiction");
  });

  it("does not add notice for documented content", () => {
    const content = "# Documented Entry\n\nFactual content with citations.";
    const result = addEpistemicNotice(content, "documented", "markdown");
    expect(result).not.toContain("Epistemic status:");
  });

  it("does not double-add notice if already present", () => {
    const content =
      "> ⚠️ **Epistemic status: speculative** — already labeled\n\n# Title\n\nContent.";
    const result = addEpistemicNotice(content, "speculative", "markdown");
    const matches = (result.match(/Epistemic status:/g) ?? []).length;
    expect(matches).toBe(1);
  });

  it("inserts notice after YAML front-matter", () => {
    const content = "---\nid: test\n---\n\n# Title\n\nContent.";
    const result = addEpistemicNotice(content, "speculative", "markdown");
    // Notice should appear after the front-matter block
    const fmEnd = result.indexOf("---\n\n");
    const noticePos = result.indexOf("Epistemic status:");
    expect(noticePos).toBeGreaterThan(fmEnd);
  });
});

describe("validateSafetyFields", () => {
  it("passes a valid entry object", () => {
    const errors = validateSafetyFields(
      {
        epistemic_status: "speculative",
        citations: [],
      },
      "entry"
    );
    expect(errors).toHaveLength(0);
  });

  it("fails if epistemic_status is missing", () => {
    const errors = validateSafetyFields({ citations: [] }, "entry");
    expect(errors.some((e) => e.includes("epistemic_status"))).toBe(true);
  });

  it("fails if citations is missing", () => {
    const errors = validateSafetyFields({ epistemic_status: "speculative" }, "entry");
    expect(errors.some((e) => e.includes("citations"))).toBe(true);
  });

  it("fails if documented entry has no citations", () => {
    const errors = validateSafetyFields(
      { epistemic_status: "documented", citations: [] },
      "entry"
    );
    expect(errors.some((e) => e.includes("citation"))).toBe(true);
  });

  it("passes documented entry with citations", () => {
    const errors = validateSafetyFields(
      { epistemic_status: "documented", citations: ["1 Enoch 6:1-8"] },
      "entry"
    );
    expect(errors).toHaveLength(0);
  });

  it("fails ritual entry without defensive_focus: true", () => {
    const errors = validateSafetyFields(
      { epistemic_status: "fiction", citations: [], defensive_focus: false },
      "ritual"
    );
    expect(errors.some((e) => e.includes("defensive_focus"))).toBe(true);
  });

  it("passes ritual entry with defensive_focus: true", () => {
    const errors = validateSafetyFields(
      { epistemic_status: "fiction", citations: [], defensive_focus: true },
      "ritual"
    );
    expect(errors).toHaveLength(0);
  });
});
