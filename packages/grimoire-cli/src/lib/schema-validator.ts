/**
 * Schema validator — validates corpus files against JSON schemas
 * using AJV (Another JSON Schema Validator).
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

// Use createRequire to load CommonJS modules in ESM context
const require = createRequire(fileURLToPath(import.meta.url));
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const AjvModule = require("ajv") as any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const addFormatsModule = require("ajv-formats") as any;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const AjvClass = (AjvModule.default ?? AjvModule) as new (opts: any) => any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const ajv: any = new AjvClass({ allErrors: true, strict: false });
(addFormatsModule.default ?? addFormatsModule)(ajv);

// Cache of compiled validators
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const validators = new Map<string, any>();

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function loadSchema(schemaPath: string): any {
  if (validators.has(schemaPath)) {
    return validators.get(schemaPath)!;
  }

  if (!existsSync(schemaPath)) {
    throw new Error(`Schema file not found: ${schemaPath}`);
  }

  const schema = JSON.parse(readFileSync(schemaPath, "utf-8")) as object;
  const validate = ajv.compile(schema);
  validators.set(schemaPath, validate);
  return validate;
}

export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

export function validateAgainstSchema(
  data: Record<string, unknown>,
  schemaPath: string
): ValidationResult {
  // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
  const validate = loadSchema(resolve(schemaPath));
  // eslint-disable-next-line @typescript-eslint/no-unsafe-call
  const valid = validate(data) as boolean;

  if (valid) return { valid: true, errors: [] };

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const errors = ((validate.errors ?? []) as any[]).map((err: any) => {
    const path = (err.instancePath as string) || "(root)";
    return `${path}: ${(err.message as string) ?? "validation error"}`;
  });

  return { valid: false, errors };
}

/**
 * Determine which schema to use for a given corpus file path.
 */
export function schemaForCorpusPath(filePath: string, schemasDir: string): string {
  const lower = filePath.toLowerCase();
  let schemaName: string;

  if (lower.includes("/entries/") || lower.endsWith(".md")) {
    schemaName = "entry.schema.json";
  } else if (lower.includes("/entities/")) {
    schemaName = "entity.schema.json";
  } else if (lower.includes("/factions/")) {
    schemaName = "faction.schema.json";
  } else if (lower.includes("/rituals/")) {
    schemaName = "ritual.schema.json";
  } else if (lower.includes("/timelines/")) {
    schemaName = "timeline.schema.json";
  } else {
    throw new Error(`Cannot determine schema for file: ${filePath}`);
  }

  return resolve(schemasDir, schemaName);
}
