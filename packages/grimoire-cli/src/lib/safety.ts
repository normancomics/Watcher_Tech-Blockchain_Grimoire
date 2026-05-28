/**
 * Safety module — content labeling and exploit-instruction filter
 *
 * Policy: No actionable exploit step-by-step instructions.
 * Security content must be defensively framed.
 * All generated content must include epistemic_status.
 *
 * See SAFETY.md for the full content policy.
 */

export type SafetyResult =
  | { safe: true }
  | { safe: false; reason: string; flaggedPatterns: string[] };

/**
 * Patterns that indicate actionable exploit instructions.
 * These are checked at a surface level — they indicate step-by-step attack guides,
 * not defensive descriptions.
 *
 * NOTE: This is a heuristic filter, not a comprehensive security scanner.
 * Human review is always required for security-sensitive content.
 */
const EXPLOIT_INSTRUCTION_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
  {
    pattern: /step\s*\d+\s*[:.)]\s.{0,60}(exploit|attack|drain|steal|hack|malicious)/i,
    label: "numbered exploit steps",
  },
  {
    // Match 0x-prefixed OR bare 64-char hex private keys
    pattern: /private.{0,10}key\s*[:=]\s*(0x)?[0-9a-fA-F]{64}\b/i,
    label: "hardcoded private key",
  },
  {
    pattern: /mnemonic\s*[:=]\s*["']?[a-z]+ [a-z]+ [a-z]+ [a-z]+ [a-z]+/i,
    label: "mnemonic phrase",
  },
  {
    pattern: /how to\s+(exploit|attack|hack|drain|steal)\s+.{0,80}(contract|protocol|wallet|defi)/i,
    label: "how-to exploit instruction",
  },
  {
    pattern: /\bexploit\.py\b|\bpwn\s*\(/i,
    label: "exploit script reference",
  },
  {
    pattern: /selfdestruct\s*\(\s*(?:payable\s*\()?\s*0x[0-9a-fA-F]{40}/i,
    label: "selfdestruct targeting a real address",
  },
];

/**
 * Patterns that signal security-related content requiring defensive_focus validation.
 */
const SECURITY_CONTENT_PATTERNS: RegExp[] = [
  /\b(exploit|vulnerability|reentrancy|flash.?loan|oracle.?manipulation|front.?run|sandwich.?attack)\b/i,
  /\b(attack vector|exploit archetype|adversarial|malicious contract)\b/i,
];

/**
 * Check content string for safety policy violations.
 */
export function checkContent(content: string, isSecurityContext = false): SafetyResult {
  const flagged: string[] = [];

  // Check for exploit instruction patterns
  for (const { pattern, label } of EXPLOIT_INSTRUCTION_PATTERNS) {
    if (pattern.test(content)) {
      flagged.push(label);
    }
  }

  if (flagged.length > 0) {
    return {
      safe: false,
      reason:
        "Content matches exploit instruction patterns. Security content must be defensively framed. See SAFETY.md.",
      flaggedPatterns: flagged,
    };
  }

  // Check if this is security content without required defensive framing
  const isSecurityContent = SECURITY_CONTENT_PATTERNS.some((p) => p.test(content));
  if ((isSecurityContext || isSecurityContent) && !hasDefensiveFraming(content)) {
    return {
      safe: false,
      reason:
        "Security-related content detected without defensive framing. Add a defensive focus section or set defensive_focus: true.",
      flaggedPatterns: ["missing defensive framing"],
    };
  }

  return { safe: true };
}

/**
 * Check that content has defensive framing indicators.
 */
function hasDefensiveFraming(content: string): boolean {
  const defensiveIndicators = [
    /defensive\s+(focus|context|pattern|description)/i,
    /defense\s+paradigm/i,
    /\bdefensive_focus\s*:\s*true\b/i,
    /\b(guard|protect|prevent|mitigate|defend|countermeasure|ward|checklist)\b/i,
    /\b(audit checklist|defensive pattern|mitigation|reentrancy guard|openzeppelin)\b/i,
    /\b(how to prevent|how to defend|protect against|resistant to)\b/i,
  ];
  return defensiveIndicators.some((p) => p.test(content));
}

/**
 * Sanitize content by adding required safety headers for speculative/fiction content.
 */
export function addEpistemicNotice(
  content: string,
  epistemicStatus: string,
  format: "markdown" | "yaml" | "json"
): string {
  if (epistemicStatus === "documented") return content;

  const notice = buildNotice(epistemicStatus, format);
  if (!notice) return content;

  // Don't double-add if already present
  if (content.includes("Epistemic status:")) return content;

  if (format === "markdown") {
    // Insert after YAML front-matter if present
    const fmMatch = content.match(/^---\n[\s\S]*?\n---\n/);
    if (fmMatch) {
      const after = content.slice(fmMatch[0].length);
      return `${fmMatch[0]}\n${notice}\n\n${after.trimStart()}`;
    }
    return `${notice}\n\n${content}`;
  }

  return content; // YAML/JSON labels are in the file structure itself
}

function buildNotice(status: string, format: "markdown" | "yaml" | "json"): string | null {
  if (format !== "markdown") return null;

  const messages: Record<string, string> = {
    speculative:
      "⚠️ **Epistemic status: speculative** — This entry reflects reasoned extrapolation and has not been independently verified.",
    contested:
      "⚠️ **Epistemic status: contested** — Evidence exists for this claim, but experts disagree on its interpretation.",
    fiction:
      "🔮 **Epistemic status: fiction** — This is a narrative/lore construct, not a factual claim.",
  };

  const msg = messages[status];
  return msg ? `> ${msg}` : null;
}

/**
 * Validate that a corpus object has required safety fields.
 */
export function validateSafetyFields(
  obj: Record<string, unknown>,
  type: "entry" | "entity" | "faction" | "ritual" | "timeline"
): string[] {
  const errors: string[] = [];

  if (!obj["epistemic_status"]) {
    errors.push(`Missing required field: epistemic_status`);
  }

  if (!Array.isArray(obj["citations"])) {
    errors.push(`Missing required field: citations (must be an array)`);
  }

  if (obj["epistemic_status"] === "documented") {
    const citations = obj["citations"] as unknown[];
    if (!citations || citations.length === 0) {
      errors.push(`'documented' epistemic_status requires at least one citation`);
    }
  }

  if (type === "ritual") {
    if (obj["defensive_focus"] !== true) {
      errors.push(`Ritual entries require 'defensive_focus: true' — safety policy enforcement`);
    }
  }

  return errors;
}
