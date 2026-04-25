/**
 * @title MoneroXmrBridge — Privacy-First XMR Payment Gateway
 * @notice Manages Monero XMR payment verification for MU Watcher Gate access.
 *
 * MU 𒉙⍤ 𐤌𐤏 — Cryptographically-obscured sovereign payments via Monero.
 *
 * Architecture:
 *   Monero (XMR) provides ring-signature-based, stealth-address transaction
 *   privacy that is fundamentally superior to on-chain transparent payments.
 *   This module bridges XMR payments to the MU Watcher Gate on Base chain
 *   via a sovereign-controlled commitment registry.
 *
 * Payment Flow:
 *   1. Entrant receives the sovereign XMR wallet address (stealth)
 *   2. Entrant sends XMR with a unique payment ID (their Gate level + nonce)
 *   3. Sovereign verifies the XMR transaction on the Monero network
 *   4. Sovereign calls MuWatcherGate.registerXmrHash(commitment) on Base
 *   5. Entrant calls MuWatcherGate.enterGateXmr(commitment, sigilProof, address)
 *
 * Privacy guarantees:
 *   - XMR transactions use RingCT (Confidential Transactions) + stealth addresses
 *   - No on-chain link between XMR sender and Base chain entrant
 *   - Commitment hash is opaque (does not reveal XMR tx details)
 *   - Sovereign's XMR wallet uses subaddresses per entrant for segregation
 *
 * @dev This module is educational/reference. Production deployment requires
 *      a running Monero node (monerod) or an RPC provider such as GetBlock.io.
 */

// ─── Types ────────────────────────────────────────────────────────────────────

export interface XmrGatePrice {
  gateLevel: number;
  xmrAmount: number;  // XMR (not piconero)
  usdEstimate: string;
  description: string;
}

export interface XmrPaymentRequest {
  /** Sovereign's Monero subaddress for this entrant */
  subaddress: string;
  /** Unique payment ID (hex, 16 chars) embedded in the XMR tx */
  paymentId: string;
  /** Required XMR amount */
  xmrAmount: number;
  /** Gate level being purchased */
  gateLevel: number;
  /** Expiry time for this payment request (Unix seconds) */
  expiresAt: number;
}

export interface XmrPaymentProof {
  /** XMR transaction hash (tx_hash on Monero network) */
  txHash: string;
  /** Payment ID matching the request */
  paymentId: string;
  /** Block height at which the tx was confirmed */
  blockHeight: number;
  /** Confirmation count */
  confirmations: number;
  /** Amount received in piconero (1 XMR = 1e12 piconero) */
  amountPiconero: bigint;
  /** Verified by sovereign */
  verified: boolean;
}

export interface XmrCommitment {
  /**
   * Opaque commitment hash stored on Base chain via MuWatcherGate.registerXmrHash().
   * Computed as: keccak256(txHash || paymentId || amountPiconero || entrantAddress)
   * The sovereign knows all components; the on-chain hash reveals nothing.
   */
  commitmentHash: string;
  /** Entrant's Base chain address this commitment is bound to */
  entrantAddress: string;
  /** Gate level unlocked */
  gateLevel: number;
  /** Timestamp of sovereign verification */
  verifiedAt: Date;
  /** Whether the commitment has been consumed on-chain */
  consumed: boolean;
}

// ─── Pricing ──────────────────────────────────────────────────────────────────

/**
 * XMR gate prices. XMR amounts are approximate and should be updated
 * dynamically based on the current XMR/USD rate.
 *
 * These prices mirror the ETH prices in MuWatcherGate.sol, converted at a
 * reference rate of ~$150 USD/XMR and ~$3,000 USD/ETH.
 */
export const XMR_GATE_PRICES: XmrGatePrice[] = [
  {
    gateLevel: 1,
    xmrAmount: 0.02,
    usdEstimate: "~$3",
    description: "Public Watcher Perimeter — Gate Level 1",
  },
  {
    gateLevel: 4,
    xmrAmount: 0.02,
    usdEstimate: "~$3",
    description: "Public Watcher Perimeter — Gate Level 4",
  },
  {
    gateLevel: 5,
    xmrAmount: 0.1,
    usdEstimate: "~$15",
    description: "Initiated Watcher Realm — Gate Level 5",
  },
  {
    gateLevel: 8,
    xmrAmount: 0.1,
    usdEstimate: "~$15",
    description: "Initiated Watcher Realm — Gate Level 8",
  },
  {
    gateLevel: 9,
    xmrAmount: 0.5,
    usdEstimate: "~$75",
    description: "Adept Sovereign Layer — Gate Level 9",
  },
  {
    gateLevel: 12,
    xmrAmount: 0.5,
    usdEstimate: "~$75",
    description: "Adept Sovereign Layer — Gate Level 12",
  },
  {
    gateLevel: 13,
    xmrAmount: 2.6,
    usdEstimate: "~$390",
    description: "MU Sovereign Core — Gate Level 13 (𒉙⍤ 𐤌𐤏 sealed)",
  },
];

// ─── XMR Amount Utilities ─────────────────────────────────────────────────────

/** Convert XMR to piconero (atomic unit). 1 XMR = 1,000,000,000,000 piconero */
export function xmrToPiconero(xmr: number): bigint {
  return BigInt(Math.round(xmr * 1e12));
}

/** Convert piconero to XMR */
export function piconeroToXmr(piconero: bigint): number {
  return Number(piconero) / 1e12;
}

/** Get XMR price for a gate level */
export function getXmrPrice(level: number): number {
  if (level < 1 || level > 13) throw new Error(`Invalid gate level: ${level}`);
  if (level <= 4)  return 0.02;
  if (level <= 8)  return 0.1;
  if (level <= 12) return 0.5;
  return 2.6;
}

// ─── Commitment Generator ─────────────────────────────────────────────────────

/**
 * Generate a unique payment ID for an XMR payment request.
 * Payment IDs are 8-byte hex strings embedded in the XMR transaction.
 */
export function generatePaymentId(): string {
  const bytes = new Uint8Array(8);
  if (typeof crypto !== "undefined" && crypto.getRandomValues) {
    // Web Crypto API (browser or Node.js >= 15)
    crypto.getRandomValues(bytes);
  } else {
    // Node.js < 15 environments: use built-in crypto module
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const nodeCrypto = require("crypto") as { randomBytes: (n: number) => Buffer };
    const buf = nodeCrypto.randomBytes(8);
    for (let i = 0; i < 8; i++) bytes[i] = buf[i];
  }
  return Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Compute the opaque XMR commitment hash.
 *
 * In production: use ethers.js keccak256 or viem's keccak256 to mirror
 * the on-chain computation exactly.
 *
 * @param txHash         XMR transaction hash
 * @param paymentId      Payment ID from the request
 * @param piconero       Amount in piconero
 * @param entrantAddress Entrant's Base chain address
 * @returns              0x-prefixed 32-byte hex commitment
 */
export function computeXmrCommitment(
  txHash: string,
  paymentId: string,
  piconero: bigint,
  entrantAddress: string
): string {
  // Educational implementation — NOT keccak256.
  // In production: use ethers.solidityPackedKeccak256(
  //   ["string","string","uint256","address"],
  //   [txHash, paymentId, piconero, entrantAddress]
  // ) to match the on-chain computation in MuWatcherGate.registerXmrHash().
  const input = `${txHash}:${paymentId}:${piconero.toString()}:${entrantAddress.toLowerCase()}`;
  let hash = 0n;
  for (const ch of input) {
    hash = (hash * 31n + BigInt(ch.charCodeAt(0))) & 0xFFFFFFFFFFFFFFFFn;
  }
  return "0x" + hash.toString(16).padStart(64, "0");
}

// ─── XMR Bridge Manager ───────────────────────────────────────────────────────

/**
 * MuXmrBridge — sovereign Monero payment bridge for MU Watcher Gate.
 *
 * Responsibilities:
 *   - Issue XMR payment requests with unique subaddresses and payment IDs
 *   - Verify received XMR transactions (via monerod RPC or Monero wallet RPC)
 *   - Generate commitment hashes for on-chain registration
 *   - Track commitment state (pending → verified → consumed)
 */
export class MuXmrBridge {
  private readonly pendingRequests: Map<string, XmrPaymentRequest> = new Map();
  private readonly verifiedCommitments: Map<string, XmrCommitment> = new Map();

  /**
   * Create a new XMR payment request for an entrant.
   *
   * @param entrantAddress  Entrant's Base chain address
   * @param gateLevel       Gate level being purchased
   * @param subaddress      Sovereign's XMR subaddress for this entrant
   *                        (generated off-chain by the sovereign's wallet)
   * @param ttlSeconds      Time-to-live for this request (default 1 hour)
   */
  createPaymentRequest(
    entrantAddress: string,
    gateLevel: number,
    subaddress: string,
    ttlSeconds: number = 3600
  ): XmrPaymentRequest {
    const paymentId = generatePaymentId();
    const xmrAmount = getXmrPrice(gateLevel);

    const request: XmrPaymentRequest = {
      subaddress,
      paymentId,
      xmrAmount,
      gateLevel,
      expiresAt: Math.floor(Date.now() / 1000) + ttlSeconds,
    };

    this.pendingRequests.set(`${entrantAddress}:${paymentId}`, request);
    return request;
  }

  /**
   * Verify an XMR payment and generate a commitment hash.
   *
   * Called by the sovereign after confirming the XMR transaction.
   * The commitment hash is then registered on Base via MuWatcherGate.registerXmrHash().
   *
   * @param entrantAddress  Entrant's Base chain address
   * @param proof           XMR payment proof from monerod
   * @param gateLevel       Gate level being unlocked
   * @returns               XmrCommitment ready for on-chain registration
   */
  verifyAndCommit(
    entrantAddress: string,
    proof: XmrPaymentProof,
    gateLevel: number
  ): XmrCommitment {
    const requiredPiconero = xmrToPiconero(getXmrPrice(gateLevel));

    if (!proof.verified) {
      throw new Error("XMR: proof not marked as verified by monerod");
    }
    if (proof.amountPiconero < requiredPiconero) {
      throw new Error(
        `XMR: insufficient amount. Required ${requiredPiconero} piconero, ` +
        `got ${proof.amountPiconero}`
      );
    }
    if (proof.confirmations < 10) {
      throw new Error(
        `XMR: insufficient confirmations (${proof.confirmations}/10 required)`
      );
    }

    const commitmentHash = computeXmrCommitment(
      proof.txHash,
      proof.paymentId,
      proof.amountPiconero,
      entrantAddress
    );

    const commitment: XmrCommitment = {
      commitmentHash,
      entrantAddress,
      gateLevel,
      verifiedAt: new Date(),
      consumed: false,
    };

    this.verifiedCommitments.set(commitmentHash, commitment);
    return commitment;
  }

  /**
   * Mark a commitment as consumed (after successful on-chain entry).
   */
  markConsumed(commitmentHash: string): void {
    const commitment = this.verifiedCommitments.get(commitmentHash);
    if (!commitment) throw new Error(`XMR: commitment not found: ${commitmentHash}`);
    commitment.consumed = true;
  }

  /**
   * Returns all pending payment requests (for sovereign dashboard).
   */
  listPending(): XmrPaymentRequest[] {
    const now = Math.floor(Date.now() / 1000);
    return Array.from(this.pendingRequests.values()).filter(r => r.expiresAt > now);
  }

  /**
   * Returns all verified, unconsumed commitments.
   */
  listPendingCommitments(): XmrCommitment[] {
    return Array.from(this.verifiedCommitments.values()).filter(c => !c.consumed);
  }

  /**
   * Print payment instructions for an entrant.
   */
  static printPaymentInstructions(request: XmrPaymentRequest): void {
    console.log(`\n⛧ MU 𒉙⍤ 𐤌𐤏 — XMR Payment Instructions`);
    console.log(`  Gate Level   : ${request.gateLevel}`);
    console.log(`  XMR Amount   : ${request.xmrAmount} XMR`);
    console.log(`  Subaddress   : ${request.subaddress}`);
    console.log(`  Payment ID   : ${request.paymentId}`);
    console.log(`  Expires At   : ${new Date(request.expiresAt * 1000).toISOString()}`);
    console.log(`\n  Send exactly ${request.xmrAmount} XMR to the subaddress above`);
    console.log(`  Include payment ID: ${request.paymentId}`);
    console.log(`  After 10 confirmations, notify the sovereign to register your commitment.`);
    console.log(`  Privacy guarantee: your XMR identity is cryptographically separated`);
    console.log(`  from your Base chain address by ring signatures and stealth addresses.\n`);
  }
}

export default { MuXmrBridge, getXmrPrice, generatePaymentId, xmrToPiconero, piconeroToXmr };
