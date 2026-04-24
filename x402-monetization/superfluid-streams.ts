/**
 * @title SuperfluidStreams — Continuous Streaming Payments on Base
 * @notice Manages Superfluid CFA (Constant Flow Agreement) streaming payments
 *         for sustained MU Watcher Gate access on Base chain.
 *
 * MU 𒉙⍤ 𐤌𐤏 — Sovereign streaming access via Superfluid on Base.
 *
 * Integration:
 *   Superfluid Protocol: https://www.superfluid.finance/
 *   Base chain Superfluid deployment addresses are used.
 *
 * Flow:
 *   1. Entrant wraps ETH → ETHx (Super Token) on Base
 *   2. Entrant opens a CFA stream: entrant → MU treasury
 *   3. MuWatcherGate.enterGateSuperfluid() verifies the stream is active
 *   4. Access persists as long as stream flows; revoked when stream closes
 *
 * Stream Rates (wei/second, continuous):
 *   Gate 1–4  : 0.000001 ETH/s  (~0.0864 ETH/day)
 *   Gate 5–8  : 0.000005 ETH/s  (~0.432 ETH/day)
 *   Gate 9–12 : 0.000025 ETH/s  (~2.16 ETH/day)
 *   Gate 13   : 0.00013 ETH/s   (~11.23 ETH/day) — Sovereign Core
 *
 * @dev All contract interactions are educational references.
 *      Actual Superfluid integration requires the @superfluid-finance/sdk-core package.
 */

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SuperfluidConfig {
  /** Superfluid CFAv1Forwarder on Base mainnet */
  cfaForwarderAddress: string;
  /** Super ETH token address (ETHx) on Base */
  superTokenAddress: string;
  /** MU treasury address (stream receiver) */
  treasuryAddress: string;
  /** Base chain ID */
  chainId: 8453 | 84532;
}

export interface StreamRequest {
  /** Entrant wallet address */
  sender: string;
  /** Gate level (1–13) */
  gateLevel: number;
  /** Duration in seconds (0 = indefinite) */
  durationSeconds?: number;
}

export interface StreamInfo {
  sender: string;
  receiver: string;
  flowRate: bigint;            // wei per second
  startedAt: Date;
  active: boolean;
  gateLevel: number;
  dailyCostEth: number;
}

export interface StreamQuote {
  gateLevel: number;
  flowRateWeiPerSecond: bigint;
  dailyCostEth: number;
  weeklyCostEth: number;
  monthlyCostEth: number;
  superTokenRequired: string;  // Minimum super token deposit
}

// ─── Constants ────────────────────────────────────────────────────────────────

/**
 * Base mainnet Superfluid contract addresses.
 * Source: https://docs.superfluid.finance/docs/technical-reference/contract-addresses
 */
export const BASE_SUPERFLUID_ADDRESSES = {
  /** CFAv1 Forwarder — the primary entry point for stream management */
  CFAv1Forwarder: "0xcfA132E353cB4E398080B9700609bb008eceB125",
  /** Super ETH (ETHx) on Base */
  ETHx:           "0x46fd5cfB4f359C4347282fcb3ceEe3B3C1a2D2C6",
  /** Host contract */
  Host:           "0x4C073B3baB6d8826b8C5b229f3cfdC1eC6E47E74",
} as const;

export const BASE_SEPOLIA_SUPERFLUID_ADDRESSES = {
  CFAv1Forwarder: "0xcfA132E353cB4E398080B9700609bb008eceB125",
  ETHx:           "0x6464A1CCD42b8571f234f59185aC72776A21591D",
  Host:           "0x109412E3C84f0539b43d39dB691B08c90f58dC7c",
} as const;

// Flow rates in wei per second for each gate tier
export const GATE_FLOW_RATES: Record<string, bigint> = {
  "1-4":  1_000_000_000_000n,     // 0.000001 ETH/s
  "5-8":  5_000_000_000_000n,     // 0.000005 ETH/s
  "9-12": 25_000_000_000_000n,    // 0.000025 ETH/s
  "13":   130_000_000_000_000n,   // 0.000130 ETH/s (Gate 13 — sovereign)
} as const;

// ─── Flow Rate Utilities ──────────────────────────────────────────────────────

/**
 * Get the required Superfluid flow rate (wei/second) for a given gate level.
 */
export function getFlowRateForLevel(level: number): bigint {
  if (level < 1 || level > 13) throw new Error(`Invalid gate level: ${level}`);
  if (level <= 4)  return GATE_FLOW_RATES["1-4"];
  if (level <= 8)  return GATE_FLOW_RATES["5-8"];
  if (level <= 12) return GATE_FLOW_RATES["9-12"];
  return GATE_FLOW_RATES["13"];
}

/**
 * Returns a human-readable quote for streaming at a given gate level.
 */
export function quoteStream(level: number): StreamQuote {
  const flowRate = getFlowRateForLevel(level);
  const weiPerDay = flowRate * 86_400n;
  const weiPerWeek = weiPerDay * 7n;
  const weiPerMonth = weiPerDay * 30n;

  const toEth = (wei: bigint): number => Number(wei) / 1e18;

  return {
    gateLevel:            level,
    flowRateWeiPerSecond: flowRate,
    dailyCostEth:         toEth(weiPerDay),
    weeklyCostEth:        toEth(weiPerWeek),
    monthlyCostEth:       toEth(weiPerMonth),
    // Superfluid requires ~4 hours of flow as a buffer deposit
    superTokenRequired:   `${toEth(flowRate * 14_400n).toFixed(6)} ETHx`,
  };
}

// ─── Stream Manager ───────────────────────────────────────────────────────────

/**
 * MuSuperfluidManager — manages Superfluid CFA streams for MU Watcher Gate access.
 *
 * @remarks
 * In production, this class wraps the @superfluid-finance/sdk-core Framework.
 * The method bodies below illustrate the integration pattern; actual execution
 * requires a connected ethers.js/viem provider and signer.
 */
export class MuSuperfluidManager {
  private readonly config: SuperfluidConfig;
  private readonly streams: Map<string, StreamInfo> = new Map();

  constructor(config: SuperfluidConfig) {
    this.config = config;
  }

  /**
   * Build the calldata for opening a CFA stream via CFAv1Forwarder.
   *
   * The caller must submit this transaction from their wallet.
   * After the transaction confirms, they may call MuWatcherGate.enterGateSuperfluid().
   *
   * @param request  Stream parameters
   * @returns        Encoded calldata for CFAv1Forwarder.createFlow()
   */
  buildOpenStreamCalldata(request: StreamRequest): {
    to: string;
    data: string;
    description: string;
  } {
    const { gateLevel, sender } = request;
    const flowRate = getFlowRateForLevel(gateLevel);

    // CFAv1Forwarder.createFlow(token, sender, receiver, flowRate, userData)
    // NOTE: The 'data' field below is illustrative. Production callers must use
    // ABI encoding (e.g., ethers.Interface.encodeFunctionData or viem encodeAbiParameters)
    // to produce valid Ethereum calldata from these parameters.
    const abiEncodedArgs = [
      this.config.superTokenAddress,
      sender,
      this.config.treasuryAddress,
      flowRate.toString(),
      "0x",  // userData (empty)
    ];

    return {
      to:   this.config.cfaForwarderAddress,
      // NOTE: 'data' below is NOT valid Ethereum calldata.
      // In production, use: ethers.Interface.encodeFunctionData("createFlow",
      //   [superToken, sender, receiver, flowRate, "0x"])
      // or viem's encodeFunctionData with the CFAv1Forwarder ABI.
      data: `[ABI-encode: createFlow(${abiEncodedArgs.join(",")})]`,
      description: [
        `Open Superfluid stream for MU Gate Level ${gateLevel}`,
        `Flow rate: ${flowRate} wei/s`,
        `Quote: ${quoteStream(gateLevel).dailyCostEth.toFixed(6)} ETHx/day`,
        `Receiver: ${this.config.treasuryAddress}`,
      ].join(" | "),
    };
  }

  /**
   * Build calldata for closing (deleting) an active stream.
   */
  buildCloseStreamCalldata(sender: string): {
    to: string;
    data: string;
    description: string;
  } {
    // CFAv1Forwarder.deleteFlow(token, sender, receiver, userData)
    return {
      to:          this.config.cfaForwarderAddress,
      data:        `0x5c4b0e99:${sender}:${this.config.treasuryAddress}`,
      description: `Close Superfluid stream from ${sender} to MU treasury`,
    };
  }

  /**
   * Simulate (educational) stream status check.
   * In production: query the Superfluid subgraph or call CFA.getFlow().
   */
  checkStream(sender: string): StreamInfo | undefined {
    return this.streams.get(sender);
  }

  /**
   * Register a stream as active (called after on-chain confirmation).
   */
  registerStream(sender: string, gateLevel: number): StreamInfo {
    const info: StreamInfo = {
      sender,
      receiver: this.config.treasuryAddress,
      flowRate: getFlowRateForLevel(gateLevel),
      startedAt: new Date(),
      active: true,
      gateLevel,
      dailyCostEth: quoteStream(gateLevel).dailyCostEth,
    };
    this.streams.set(sender, info);
    return info;
  }

  /**
   * Returns all active streams.
   */
  listActiveStreams(): StreamInfo[] {
    return Array.from(this.streams.values()).filter(s => s.active);
  }

  /**
   * Print stream quote to console (diagnostic helper).
   */
  static printQuote(level: number): void {
    const q = quoteStream(level);
    console.log(`\n⛧ MU 𒉙⍤ 𐤌𐤏 — Superfluid Stream Quote — Gate Level ${level}`);
    console.log(`  Flow rate : ${q.flowRateWeiPerSecond} wei/second`);
    console.log(`  Daily     : ${q.dailyCostEth.toFixed(6)} ETHx`);
    console.log(`  Weekly    : ${q.weeklyCostEth.toFixed(6)} ETHx`);
    console.log(`  Monthly   : ${q.monthlyCostEth.toFixed(6)} ETHx`);
    console.log(`  Buffer    : ${q.superTokenRequired}`);
  }
}

// ─── Default Config (Base mainnet) ────────────────────────────────────────────

export function createDefaultConfig(treasuryAddress: string): SuperfluidConfig {
  return {
    cfaForwarderAddress: BASE_SUPERFLUID_ADDRESSES.CFAv1Forwarder,
    superTokenAddress:   BASE_SUPERFLUID_ADDRESSES.ETHx,
    treasuryAddress,
    chainId:             8453,
  };
}

export default { MuSuperfluidManager, getFlowRateForLevel, quoteStream, createDefaultConfig };
