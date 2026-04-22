/**
 * Grimoire Oracle — Audit Log
 *
 * Immutable audit trail for every tool/agent execution.
 * Logs inputs, outputs, timing, policy violations, and errors
 * for security monitoring and forensic analysis.
 */

// ─── Audit Entry Types ───────────────────────────────────────────────

export interface AuditEntry {
  /** Unique execution ID */
  executionId: string;
  /** Tool/agent name */
  tool: string;
  /** ISO-8601 timestamp */
  timestamp: string;
  /** Wall-clock execution time in ms */
  durationMs: number;
  /** Whether execution completed successfully */
  success: boolean;
  /** Input fields (values redacted for privacy) */
  inputSummary: Record<string, string>;
  /** Output length in characters */
  outputLength: number;
  /** Security policy violations detected */
  violations: string[];
  /** Error message if execution failed */
  error?: string;
  /** Whether output was truncated by policy */
  outputTruncated: boolean;
  /** Whether execution was terminated by timeout */
  timedOut: boolean;
  /** Client transport type */
  transport: "stdio" | "http";
}

// ─── Audit Log Storage ───────────────────────────────────────────────

/**
 * In-memory circular buffer for audit entries.
 * In production, this would write to a persistent store.
 */
const MAX_ENTRIES = 1000;
const auditBuffer: AuditEntry[] = [];

/**
 * Generates a unique execution ID.
 */
export function generateExecutionId(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 8);
  return `exec_${timestamp}_${random}`;
}

/**
 * Summarizes input values for the audit log.
 * Includes field types and lengths, but redacts actual values
 * to prevent sensitive data from appearing in logs.
 */
export function summarizeInputs(
  inputs: Record<string, unknown>,
): Record<string, string> {
  const summary: Record<string, string> = {};

  for (const [key, value] of Object.entries(inputs)) {
    if (value === undefined || value === null) {
      summary[key] = "null";
    } else if (typeof value === "string") {
      summary[key] = `string(${value.length} chars)`;
    } else if (typeof value === "number") {
      summary[key] = `number`;
    } else if (Array.isArray(value)) {
      summary[key] = `array(${value.length} items)`;
    } else {
      summary[key] = typeof value;
    }
  }

  return summary;
}

/**
 * Records an audit entry for a completed execution.
 */
export function recordAudit(entry: AuditEntry): void {
  // Circular buffer: drop oldest when full
  if (auditBuffer.length >= MAX_ENTRIES) {
    auditBuffer.shift();
  }
  auditBuffer.push(Object.freeze({ ...entry }));

  // Log to stderr for operational visibility
  const status = entry.success ? "✅" : "❌";
  const violations =
    entry.violations.length > 0
      ? ` [${entry.violations.length} violation(s)]`
      : "";
  const timeout = entry.timedOut ? " [TIMEOUT]" : "";
  const truncated = entry.outputTruncated ? " [TRUNCATED]" : "";

  console.error(
    `[AUDIT] ${status} ${entry.executionId} | ${entry.tool} | ${entry.durationMs}ms | ${entry.outputLength} chars${violations}${timeout}${truncated}`,
  );
}

// ─── Audit Query Interface ───────────────────────────────────────────

/**
 * Returns recent audit entries, optionally filtered by tool name.
 */
export function getRecentAudits(options?: {
  tool?: string;
  limit?: number;
  failedOnly?: boolean;
}): AuditEntry[] {
  const { tool, limit = 50, failedOnly = false } = options ?? {};

  let entries = [...auditBuffer];

  if (tool) {
    entries = entries.filter((e) => e.tool === tool);
  }

  if (failedOnly) {
    entries = entries.filter((e) => !e.success);
  }

  // Most recent first
  entries.reverse();

  return entries.slice(0, limit);
}

/**
 * Returns aggregate stats from the audit log.
 */
export function getAuditStats(): {
  totalExecutions: number;
  successRate: number;
  avgDurationMs: number;
  totalViolations: number;
  totalTimeouts: number;
  byTool: Record<string, { count: number; failures: number; avgMs: number }>;
} {
  const total = auditBuffer.length;
  if (total === 0) {
    return {
      totalExecutions: 0,
      successRate: 1,
      avgDurationMs: 0,
      totalViolations: 0,
      totalTimeouts: 0,
      byTool: {},
    };
  }

  const successes = auditBuffer.filter((e) => e.success).length;
  const totalDuration = auditBuffer.reduce((sum, e) => sum + e.durationMs, 0);
  const totalViolations = auditBuffer.reduce(
    (sum, e) => sum + e.violations.length,
    0,
  );
  const totalTimeouts = auditBuffer.filter((e) => e.timedOut).length;

  const byTool: Record<
    string,
    { count: number; failures: number; avgMs: number; totalMs: number }
  > = {};

  for (const entry of auditBuffer) {
    const stats = byTool[entry.tool] ?? {
      count: 0,
      failures: 0,
      avgMs: 0,
      totalMs: 0,
    };
    stats.count++;
    if (!entry.success) stats.failures++;
    stats.totalMs += entry.durationMs;
    stats.avgMs = Math.round(stats.totalMs / stats.count);
    byTool[entry.tool] = stats;
  }

  // Remove totalMs from output
  const cleanByTool: Record<
    string,
    { count: number; failures: number; avgMs: number }
  > = {};
  for (const [tool, stats] of Object.entries(byTool)) {
    cleanByTool[tool] = {
      count: stats.count,
      failures: stats.failures,
      avgMs: stats.avgMs,
    };
  }

  return {
    totalExecutions: total,
    successRate: successes / total,
    avgDurationMs: Math.round(totalDuration / total),
    totalViolations,
    totalTimeouts,
    byTool: cleanByTool,
  };
}
