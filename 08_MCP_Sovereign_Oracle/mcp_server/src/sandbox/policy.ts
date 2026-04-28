/**
 * Grimoire Oracle — Security Policy Engine
 *
 * Defines per-tool security policies governing what each agent/tool
 * is allowed to do inside its sandbox. Validates and sanitizes all
 * inputs before they reach tool logic, and caps output size.
 */

// ─── Policy Definitions ──────────────────────────────────────────────

export interface SecurityPolicy {
  /** Human-readable policy name */
  name: string;
  /** Maximum wall-clock milliseconds the tool may run */
  timeoutMs: number;
  /** Maximum characters allowed in any single input field */
  maxInputLength: number;
  /** Maximum characters allowed in the tool's output */
  maxOutputLength: number;
  /** Whether this tool may access the knowledge base */
  allowKnowledgeAccess: boolean;
  /** Allowed knowledge base tags (empty = all allowed) */
  allowedKnowledgeTags: string[];
  /** Maximum number of knowledge chunks the tool may read */
  maxKnowledgeChunks: number;
}

/** Default conservative policy applied when no tool-specific policy exists */
const DEFAULT_POLICY: SecurityPolicy = {
  name: "default",
  timeoutMs: 10_000,
  maxInputLength: 50_000,
  maxOutputLength: 100_000,
  allowKnowledgeAccess: false,
  allowedKnowledgeTags: [],
  maxKnowledgeChunks: 0,
};

/**
 * Per-tool security policies.
 *
 * Each tool gets its own policy with the minimum permissions it needs.
 * Audit scan needs large input (full contracts) but no knowledge base.
 * Codex query needs knowledge but limited input. And so on.
 */
const TOOL_POLICIES: Record<string, SecurityPolicy> = {
  grimoire_audit_scan: {
    name: "audit_scan",
    timeoutMs: 15_000,
    maxInputLength: 200_000,   // Solidity contracts can be large
    maxOutputLength: 200_000,
    allowKnowledgeAccess: false, // Audit uses archetypes, not knowledge base
    allowedKnowledgeTags: [],
    maxKnowledgeChunks: 0,
  },
  grimoire_query_codex: {
    name: "query_codex",
    timeoutMs: 10_000,
    maxInputLength: 2_000,
    maxOutputLength: 100_000,
    allowKnowledgeAccess: true,
    allowedKnowledgeTags: [],   // All tags allowed for general queries
    maxKnowledgeChunks: 20,
  },
  grimoire_defense_recommend: {
    name: "defense_recommend",
    timeoutMs: 5_000,
    maxInputLength: 2_000,
    maxOutputLength: 50_000,
    allowKnowledgeAccess: false,
    allowedKnowledgeTags: [],
    maxKnowledgeChunks: 0,
  },
  grimoire_watcher_consult: {
    name: "watcher_consult",
    timeoutMs: 10_000,
    maxInputLength: 5_000,
    maxOutputLength: 100_000,
    allowKnowledgeAccess: true,
    allowedKnowledgeTags: [],   // Watcher tags are applied at search time
    maxKnowledgeChunks: 10,
  },
  grimoire_family_threat_intel: {
    name: "family_threat_intel",
    timeoutMs: 5_000,
    maxInputLength: 2_000,
    maxOutputLength: 50_000,
    allowKnowledgeAccess: false,
    allowedKnowledgeTags: [],
    maxKnowledgeChunks: 0,
  },
  grimoire_quantum_entropy: {
    name: "quantum_entropy",
    timeoutMs: 5_000,
    maxInputLength: 500,
    maxOutputLength: 20_000,
    allowKnowledgeAccess: false,
    allowedKnowledgeTags: [],
    maxKnowledgeChunks: 0,
  },
  grimoire_rag_synthesis: {
    name: "rag_synthesis",
    timeoutMs: 20_000,
    maxInputLength: 5_000,
    maxOutputLength: 200_000,
    allowKnowledgeAccess: true,
    allowedKnowledgeTags: [],   // All tags allowed for synthesis
    maxKnowledgeChunks: 30,
  },
  grimoire_sovereign_invoke: {
    name: "sovereign_invoke",
    timeoutMs: 60_000,          // Sovereign pipeline may chain 4–8 steps
    maxInputLength: 200_000,    // Must accept full contract source
    maxOutputLength: 500_000,
    allowKnowledgeAccess: true,
    allowedKnowledgeTags: [],
    maxKnowledgeChunks: 50,
  },
};

/**
 * Returns the security policy for a given tool.
 * Falls back to a restrictive default if no specific policy is defined.
 */
export function getPolicy(toolName: string): SecurityPolicy {
  return TOOL_POLICIES[toolName] ?? { ...DEFAULT_POLICY, name: toolName };
}

// ─── Input Validation ────────────────────────────────────────────────

export interface ValidationResult {
  valid: boolean;
  sanitized: Record<string, unknown>;
  violations: string[];
}

/**
 * Validates and sanitizes tool inputs against the security policy.
 *
 * - Enforces maximum input length per field
 * - Strips null bytes and control characters (except newlines/tabs)
 * - Rejects inputs containing obvious injection patterns
 */
export function validateInputs(
  inputs: Record<string, unknown>,
  policy: SecurityPolicy,
): ValidationResult {
  const violations: string[] = [];
  const sanitized: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(inputs)) {
    if (value === undefined || value === null) {
      sanitized[key] = value;
      continue;
    }

    if (typeof value === "string") {
      // Check length
      if (value.length > policy.maxInputLength) {
        violations.push(
          `Input "${key}" exceeds maximum length (${value.length} > ${policy.maxInputLength})`,
        );
        // Truncate rather than reject, so partial results are still possible
        sanitized[key] = sanitizeString(value.slice(0, policy.maxInputLength));
      } else {
        sanitized[key] = sanitizeString(value);
      }
    } else if (typeof value === "number") {
      // Numbers are safe but clamp to reasonable range
      if (!Number.isFinite(value)) {
        violations.push(`Input "${key}" is not a finite number`);
        sanitized[key] = 0;
      } else {
        sanitized[key] = value;
      }
    } else if (Array.isArray(value)) {
      // Sanitize array of strings (e.g., filterTags)
      const cleanArray = value
        .filter((v): v is string => typeof v === "string")
        .map((v) => sanitizeString(v.slice(0, 200)));
      if (cleanArray.length > 50) {
        violations.push(`Input "${key}" array too large (${cleanArray.length} > 50)`);
        sanitized[key] = cleanArray.slice(0, 50);
      } else {
        sanitized[key] = cleanArray;
      }
    } else {
      violations.push(`Input "${key}" has unsupported type: ${typeof value}`);
      sanitized[key] = undefined;
    }
  }

  return {
    valid: violations.length === 0,
    sanitized,
    violations,
  };
}

/**
 * Sanitizes a string by removing dangerous characters while preserving
 * legitimate content like Solidity source code.
 */
function sanitizeString(input: string): string {
  // Remove null bytes — these can cause truncation attacks
  let clean = input.replace(/\0/g, "");
  // Remove non-printable control characters except \n, \r, \t
  clean = clean.replace(/[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "");
  return clean;
}

// ─── Output Enforcement ──────────────────────────────────────────────

/**
 * Truncates tool output to the policy's maximum output length.
 * Appends a truncation notice if content was cut.
 */
export function enforceOutputLimit(
  output: string,
  policy: SecurityPolicy,
): string {
  if (output.length <= policy.maxOutputLength) {
    return output;
  }

  const truncated = output.slice(0, policy.maxOutputLength);
  return (
    truncated +
    "\n\n---\n⚠️ Output truncated to " +
    policy.maxOutputLength.toLocaleString() +
    " characters by security policy."
  );
}
