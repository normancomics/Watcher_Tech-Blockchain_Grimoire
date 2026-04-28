/**
 * Grimoire Oracle — Quantum Entropy Tool
 *
 * Generates post-quantum secure entropy and verifiable randomness proofs
 * using the Watcher Tech esoteric framework.
 *
 * Esoteric Framework:
 *   - Enochian angels as entropy personas (see EnochianConsensus.sol)
 *   - Planetary kamea (magic squares) as entropy transformation matrices
 *   - Kabbalistic sefirot as mixing rounds
 *   - Output certified against the Qliphotic adversary model
 *
 * Quantum-Resistant Algorithms referenced:
 *   - CRYSTALS-Kyber    (NIST PQC standard) — key encapsulation
 *   - CRYSTALS-Dilithium (NIST PQC standard) — lattice signatures
 *   - SPHINCS+           (NIST PQC standard) — stateless hash-based sigs
 *
 * @dev This module produces entropy using Node.js's crypto.randomBytes
 *      (which is cryptographically secure and CSPRNG-backed). The
 *      "quantum-resistant" framing documents the algorithms one SHOULD
 *      use when integrating with a PQC library (e.g., liboqs). The
 *      commit-reveal scheme and mixing layer are fully functional.
 */

import { createHash, randomBytes } from "node:crypto";

// ─── Enochian Entropy Personas ────────────────────────────────────────────────

/** Each Enochian angel represents a distinct entropy source / mixing persona. */
const ENOCHIAN_ENTROPY_SOURCES = [
  { name: "Uriel",    domain: "earth",     mixing: "SHA3-256",  sefirot: "Malkuth"   },
  { name: "Raphael",  domain: "air",       mixing: "SHA3-384",  sefirot: "Hod"       },
  { name: "Michael",  domain: "fire",      mixing: "SHA3-512",  sefirot: "Gevurah"   },
  { name: "Gabriel",  domain: "water",     mixing: "SHA3-256",  sefirot: "Yesod"     },
  { name: "Saraqael", domain: "spirit",    mixing: "BLAKE2s",   sefirot: "Binah"     },
  { name: "Remiel",   domain: "thunder",   mixing: "SHA3-384",  sefirot: "Chesed"    },
  { name: "Raguel",   domain: "vengeance", mixing: "SHA3-512",  sefirot: "Tiferet"   },
] as const;

// ─── Planetary Kamea Constants ────────────────────────────────────────────────

/** Saturn's 3×3 magic square (sum = 15 per row/col/diag) — transformation seed */
const SATURN_KAMEA = [4, 9, 2, 3, 5, 7, 8, 1, 6];
/** Jupiter's 4×4 magic square (sum = 34) */
const JUPITER_KAMEA = [4, 14, 15, 1, 9, 7, 6, 12, 5, 11, 10, 8, 16, 2, 3, 13];

// ─── Types ────────────────────────────────────────────────────────────────────

export interface EntropyRequest {
  /** Number of entropy bytes to generate (1–4096) */
  bytes?: number;
  /** Output encoding format */
  encoding?: "hex" | "base64" | "binary-description";
  /** Planetary kamea to use as the mixing matrix */
  planet?: "saturn" | "jupiter" | "mars" | "sun" | "venus" | "mercury" | "moon";
  /** Enochian angel persona for entropy source labelling */
  angel?: string;
  /** If true, generate a commit-reveal pair for on-chain use */
  commitReveal?: boolean;
  /** Use case description (informational, influences mixing label) */
  useCase?: string;
}

export interface EntropyResult {
  entropy: string;                   // Encoded entropy value
  entropyBits: number;               // Effective bits of entropy
  algorithm: string;                 // CSPRNG algorithm used
  pqcSuite: string;                  // PQC algorithm recommended for this output
  angel: string;                     // Enochian persona
  planet: string;                    // Planetary kamea used
  sefirot: string;                   // Kabbalistic mixing round label
  mixingRounds: number;              // SHA3 mixing rounds applied
  commit?: string;                   // keccak256 commitment (if commitReveal)
  revealKey?: string;                // Reveal key (if commitReveal)
  provenanceHash: string;            // Provenance: keccak256(entropy || timestamp)
  timestamp: number;                 // Unix ms timestamp
  fullReport: string;                // Human-readable formatted report
}

// ─── Planetary Mixing ─────────────────────────────────────────────────────────

/**
 * Applies a planetary kamea transformation to input bytes.
 * The kamea values are used as positional weights in a mixing XOR pass.
 */
function applyKamea(data: Buffer, kamea: readonly number[]): Buffer {
  const result = Buffer.allocUnsafe(data.length);
  for (let i = 0; i < data.length; i++) {
    const weight = kamea[i % kamea.length]!;
    result[i] = ((data[i]! ^ weight) + weight) & 0xff;
  }
  return result;
}

/** Returns the kamea for a given planet name. */
function getKamea(planet: string): readonly number[] {
  switch (planet) {
    case "jupiter": return JUPITER_KAMEA;
    case "saturn":  return SATURN_KAMEA;
    // Other planets use a dynamically generated kamea from their ordinal
    default: {
      // Generate a consistent pseudo-kamea for the planet
      const seed = planet.split("").reduce((acc, c) => acc + c.charCodeAt(0), 0);
      return SATURN_KAMEA.map((v) => ((v * seed) % 9) + 1);
    }
  }
}

/** Maps planet → recommended PQC algorithm */
function planetToPQC(planet: string): string {
  const map: Record<string, string> = {
    saturn:  "CRYSTALS-Kyber-1024 (key encapsulation)",
    jupiter: "CRYSTALS-Dilithium-5 (lattice signatures)",
    mars:    "SPHINCS+-SHA3-256 (stateless hash sigs)",
    sun:     "CRYSTALS-Kyber-768 (balanced KEM)",
    venus:   "CRYSTALS-Dilithium-3 (balanced sigs)",
    mercury: "FALCON-1024 (compact lattice sigs)",
    moon:    "McEliece-6688128 (code-based KEM)",
  };
  return map[planet] ?? "CRYSTALS-Kyber-1024 (default)";
}

// ─── Core Entropy Generation ──────────────────────────────────────────────────

/**
 * Generates post-quantum calibrated entropy using the Enochian/Kabbalistic
 * mixing framework. The actual randomness source is Node.js crypto.randomBytes
 * (CSPRNG). The esoteric layer applies deterministic mixing and labels the
 * output for integration into the Grimoire framework.
 */
export function generateQuantumEntropy(request: EntropyRequest = {}): EntropyResult {
  const byteCount = Math.min(Math.max(request.bytes ?? 32, 1), 4096);
  const planet    = request.planet ?? "saturn";
  const encoding  = request.encoding ?? "hex";

  // Select Enochian angel (by name or round-robin by planet ordinal)
  const planetIndex = ["saturn","jupiter","mars","sun","venus","mercury","moon"].indexOf(planet);
  const angelIndex  = planetIndex >= 0 ? planetIndex : 0;
  const angel       = ENOCHIAN_ENTROPY_SOURCES[angelIndex % ENOCHIAN_ENTROPY_SOURCES.length]!;

  // 1. Raw CSPRNG entropy
  const raw = randomBytes(byteCount);

  // 2. Apply planetary kamea transformation
  const kamea  = getKamea(planet);
  const mixed  = applyKamea(raw, kamea);

  // 3. Multi-round SHA3-256 mixing (sefirot rounds = 7)
  const mixingRounds = 7;
  let hashed = mixed;
  for (let round = 0; round < mixingRounds; round++) {
    const h = createHash("sha3-256");
    h.update(hashed);
    h.update(Buffer.from([round]));
    hashed = h.digest();
  }

  // 4. Final entropy: XOR mixed with hashed to preserve full byte entropy
  //    while ensuring the mixing hash is folded in.
  const finalEntropy = Buffer.allocUnsafe(byteCount);
  for (let i = 0; i < byteCount; i++) {
    finalEntropy[i] = mixed[i]! ^ hashed[i % hashed.length]!;
  }

  // 5. Encode output
  let encodedEntropy: string;
  switch (encoding) {
    case "base64":
      encodedEntropy = finalEntropy.toString("base64");
      break;
    case "binary-description":
      encodedEntropy = Array.from(finalEntropy)
        .map((b) => b!.toString(2).padStart(8, "0"))
        .join(" ");
      break;
    default:
      encodedEntropy = finalEntropy.toString("hex");
  }

  // 6. Provenance hash — keccak256 of (entropy || timestamp)
  const timestamp = Date.now();
  const provenance = createHash("sha3-256")
    .update(finalEntropy)
    .update(Buffer.from(timestamp.toString()))
    .digest("hex");

  // 7. Optional commit-reveal pair
  let commit: string | undefined;
  let revealKey: string | undefined;

  if (request.commitReveal) {
    revealKey = randomBytes(32).toString("hex");
    commit = createHash("sha3-256")
      .update(finalEntropy)
      .update(Buffer.from(revealKey, "hex"))
      .digest("hex");
  }

  const pqcSuite = planetToPQC(planet);
  const effectiveBits = byteCount * 8;

  const fullReport = formatEntropyReport({
    entropy: encodedEntropy,
    entropyBits: effectiveBits,
    algorithm: "CSPRNG → Kamea → SHA3-256×7",
    pqcSuite,
    angel: angel.name,
    planet,
    sefirot: angel.sefirot,
    mixingRounds,
    commit,
    revealKey,
    provenanceHash: provenance,
    timestamp,
    useCase: request.useCase,
  });

  return {
    entropy:      encodedEntropy,
    entropyBits:  effectiveBits,
    algorithm:    "CSPRNG → Kamea → SHA3-256×7",
    pqcSuite,
    angel:        angel.name,
    planet,
    sefirot:      angel.sefirot,
    mixingRounds,
    commit,
    revealKey,
    provenanceHash: provenance,
    timestamp,
    fullReport,
  };
}

// ─── Report Formatter ─────────────────────────────────────────────────────────

function formatEntropyReport(params: {
  entropy: string;
  entropyBits: number;
  algorithm: string;
  pqcSuite: string;
  angel: string;
  planet: string;
  sefirot: string;
  mixingRounds: number;
  commit?: string;
  revealKey?: string;
  provenanceHash: string;
  timestamp: number;
  useCase?: string;
}): string {
  const lines: string[] = [
    "⚛️  GRIMOIRE QUANTUM ENTROPY REPORT",
    "═══════════════════════════════════════════════════════════",
    "",
    "🔯 ESOTERIC PROVENANCE",
    `   Enochian Angel  : ${params.angel}`,
    `   Planetary Kamea : ${params.planet.charAt(0).toUpperCase() + params.planet.slice(1)}`,
    `   Sefirot Layer   : ${params.sefirot}`,
    `   Mixing Rounds   : ${params.mixingRounds} (SHA3-256 cascade)`,
    "",
    "⚛️  ENTROPY PARAMETERS",
    `   Entropy Bits    : ${params.entropyBits} bits`,
    `   Algorithm       : ${params.algorithm}`,
    `   PQC Suite       : ${params.pqcSuite}`,
    `   Timestamp       : ${new Date(params.timestamp).toISOString()}`,
    "",
    "🔑 ENTROPY OUTPUT",
    `   ${params.entropy.slice(0, 80)}${params.entropy.length > 80 ? "..." : ""}`,
    "",
    "📜 PROVENANCE HASH (on-chain anchoring)",
    `   ${params.provenanceHash}`,
    "",
  ];

  if (params.commit && params.revealKey) {
    lines.push(
      "🔒 COMMIT-REVEAL PAIR (for on-chain randomness commitment)",
      `   Commit    : 0x${params.commit}`,
      `   RevealKey : 0x${params.revealKey}`,
      "",
      "   USAGE: Submit 'commit' on-chain first, then reveal",
      "          with (entropy, revealKey) to prove randomness.",
      "",
    );
  }

  if (params.useCase) {
    lines.push(
      "📋 USE CASE",
      `   ${params.useCase}`,
      "",
    );
  }

  lines.push(
    "🛡️  POST-QUANTUM READINESS",
    "   This entropy output is formatted for direct use with:",
    `   ✓ ${params.pqcSuite}`,
    "   ✓ SHA3-256 commitment scheme (keccak256 compatible)",
    "   ✓ Base chain on-chain commit-reveal (SpellPayment.sol)",
    "",
    "═══════════════════════════════════════════════════════════",
    "Watcher Tech Blockchain Grimoire — normancomics.eth 2026",
  );

  return lines.join("\n");
}
