/**
 * Grimoire Oracle — Sandboxed Execution Engine
 *
 * Every tool/agent call runs inside a sandbox that provides:
 *
 *  1. **Isolated context** — each execution gets its own frozen
 *     knowledge snapshot; no shared mutable state between calls.
 *
 *  2. **Security policy** — per-tool input validation, output size
 *     limits, and knowledge-access restrictions.
 *
 *  3. **Timeout enforcement** — executions that exceed their policy's
 *     time limit are aborted with a safe error.
 *
 *  4. **Error containment** — tool failures are caught and returned as
 *     structured errors; one tool crash never takes down the server.
 *
 *  5. **Audit trail** — every execution is logged with timing, input
 *     summaries, output sizes, violations, and errors.
 */

import type { KnowledgeChunk } from "../knowledge/loader.js";

import {
  getPolicy,
  validateInputs,
  enforceOutputLimit,
  type SecurityPolicy,
} from "./policy.js";

import {
  generateExecutionId,
  summarizeInputs,
  recordAudit,
  type AuditEntry,
} from "./audit-log.js";

// ─── Sandbox Context ─────────────────────────────────────────────────

/**
 * Immutable context passed to a sandboxed tool execution.
 * Tools receive a frozen snapshot of the knowledge base and
 * can only read from it — never mutate global state.
 */
export interface SandboxContext {
  /** Unique ID for this execution (for audit trail) */
  readonly executionId: string;
  /** Frozen knowledge base snapshot (read-only) */
  readonly knowledge: readonly KnowledgeChunk[];
  /** The security policy governing this execution */
  readonly policy: SecurityPolicy;
  /** Transport type for audit logging */
  readonly transport: "stdio" | "http";
}

// ─── Sandbox Result ──────────────────────────────────────────────────

export interface SandboxResult {
  /** Whether the tool executed successfully */
  success: boolean;
  /** The tool's text output (possibly truncated) */
  output: string;
  /** Execution time in milliseconds */
  durationMs: number;
  /** Input validation violations (informational, not blocking) */
  violations: string[];
  /** Whether output was truncated by policy */
  outputTruncated: boolean;
  /** Whether execution was terminated by timeout */
  timedOut: boolean;
  /** Structured error if execution failed */
  error?: string;
}

// ─── Frozen Knowledge Cache ──────────────────────────────────────────

/**
 * Holds a single frozen snapshot of the knowledge base.
 * Created once when first needed; reused for all subsequent requests.
 * Since knowledge chunks are immutable data loaded from files,
 * freezing them prevents any accidental mutation by tool code.
 */
let frozenKnowledgeSnapshot: readonly KnowledgeChunk[] | null = null;

/**
 * Creates or returns the frozen knowledge snapshot.
 * The snapshot is deeply frozen so that no tool execution can
 * accidentally or maliciously mutate the shared data.
 */
export function getFrozenKnowledge(
  loadFn: () => KnowledgeChunk[],
): readonly KnowledgeChunk[] {
  if (frozenKnowledgeSnapshot === null) {
    const chunks = loadFn();
    // Deep-freeze every chunk so no tool can mutate the data
    for (const chunk of chunks) {
      Object.freeze(chunk);
      Object.freeze(chunk.tags);
    }
    Object.freeze(chunks);
    frozenKnowledgeSnapshot = chunks;
  }
  return frozenKnowledgeSnapshot;
}

// ─── Core Sandbox Executor ───────────────────────────────────────────

/**
 * Executes a tool function inside the sandbox.
 *
 * @param toolName - Name of the tool (for policy lookup and audit)
 * @param inputs   - Raw inputs from the client
 * @param toolFn   - The actual tool implementation function
 * @param options  - Additional execution options
 *
 * @returns SandboxResult with output, timing, violations, and errors
 */
export async function sandboxExecute(
  toolName: string,
  inputs: Record<string, unknown>,
  toolFn: (
    sanitizedInputs: Record<string, unknown>,
    ctx: SandboxContext,
  ) => string | Promise<string>,
  options: {
    knowledge?: readonly KnowledgeChunk[];
    transport?: "stdio" | "http";
  } = {},
): Promise<SandboxResult> {
  const executionId = generateExecutionId();
  const policy = getPolicy(toolName);
  const transport = options.transport ?? "stdio";
  const startTime = performance.now();

  // ── Phase 1: Input Validation ────────────────────────────────────
  const validation = validateInputs(inputs, policy);

  // ── Phase 2: Build Sandbox Context ───────────────────────────────
  // Knowledge access is gated by policy
  let knowledge: readonly KnowledgeChunk[] = [];
  if (policy.allowKnowledgeAccess && options.knowledge) {
    // Apply chunk limit from policy
    knowledge =
      options.knowledge.length > policy.maxKnowledgeChunks
        ? options.knowledge.slice(0, policy.maxKnowledgeChunks)
        : options.knowledge;
  }

  const ctx: SandboxContext = Object.freeze({
    executionId,
    knowledge,
    policy,
    transport,
  });

  // ── Phase 3: Execute with Timeout ────────────────────────────────
  let output = "";
  let success = false;
  let timedOut = false;
  let error: string | undefined;

  try {
    const resultPromise = Promise.resolve(
      toolFn(validation.sanitized, ctx),
    );

    const timeoutPromise = new Promise<never>((_resolve, reject) => {
      setTimeout(() => {
        reject(new Error(`Sandbox timeout: ${toolName} exceeded ${policy.timeoutMs}ms`));
      }, policy.timeoutMs);
    });

    output = await Promise.race([resultPromise, timeoutPromise]);
    success = true;
  } catch (err: unknown) {
    const message =
      err instanceof Error ? err.message : String(err);

    if (message.includes("Sandbox timeout")) {
      timedOut = true;
      error = message;
      output = `⚠️ Execution timed out after ${policy.timeoutMs}ms. The ${toolName} tool was terminated by its security policy.`;
    } else {
      error = message;
      output = `❌ Tool execution failed: ${message}`;
    }
  }

  // ── Phase 4: Enforce Output Limits ───────────────────────────────
  const originalLength = output.length;
  output = enforceOutputLimit(output, policy);
  const outputTruncated = output.length !== originalLength;

  // ── Phase 5: Audit ───────────────────────────────────────────────
  const durationMs = Math.round(performance.now() - startTime);

  const auditEntry: AuditEntry = {
    executionId,
    tool: toolName,
    timestamp: new Date().toISOString(),
    durationMs,
    success,
    inputSummary: summarizeInputs(inputs),
    outputLength: output.length,
    violations: validation.violations,
    error,
    outputTruncated,
    timedOut,
    transport,
  };

  recordAudit(auditEntry);

  return {
    success,
    output,
    durationMs,
    violations: validation.violations,
    outputTruncated,
    timedOut,
    error,
  };
}
