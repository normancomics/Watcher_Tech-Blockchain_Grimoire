/**
 * @title PaymentGates — HTTP 402 Middleware
 * @notice Express/Fastify middleware for x402 payment-gated API endpoints.
 *
 * MU 𒉙⍤ 𐤌𐤏 — All payments route exclusively through Base chain.
 * Supported payment paths:
 *   1. x402 on Base  — ETH/USDC on-chain micropayments (primary)
 *   2. Superfluid    — Continuous ETHx streaming on Base (see superfluid-streams.ts)
 *   3. Monero XMR    — Privacy-first off-chain bridge (see monero-xmr-bridge.ts)
 *   4. Veil.cash     — ZK-shielded ETH on Base (see veil-cash-gateway.ts)
 *
 * Note: Polygon, Solana, mainnet, and Optimism are NOT supported.
 *       MU sovereignty runs exclusively on Base (chainId 8453 / 84532).
 */

export interface X402PaymentRequired {
  error: 'Payment Required';
  statusCode: 402;
  resourceId: number;
  resourceDescription: string;
  payment: {
    amount: string;
    currency: 'ETH' | 'USDC';
    network: 'base';
    contractAddress: string;
    functionSignature: 'castSpell(uint256)';
    accepts: string[];
  };
  access: {
    duration: number;
    type: 'time-based' | 'one-time';
  };
}

export interface PaymentProof {
  receiptHash: string;
  txHash: string;
  payer: string;
  resourceId: number;
  validUntil: number;
}

/**
 * Middleware factory for x402 payment gates
 */
export function createPaymentGate(config: {
  resourceId: number;
  description: string;
  priceEth: string;
  accessDurationSeconds: number;
  contractAddress: string;
  network: 'base';
}) {
  return async (req: Request, _res: Response, next: () => void): Promise<Response | void> => {
    const paymentProof = extractPaymentProof(req);
    
    if (!paymentProof) {
      return createPaymentRequiredResponse(config);
    }
    
    const valid = await verifyPaymentProof(paymentProof, config.resourceId);
    if (!valid) {
      return createPaymentRequiredResponse(config);
    }
    
    // Payment valid — proceed
    next();
  };
}

function extractPaymentProof(req: Request): PaymentProof | null {
  const receiptHash = (req.headers as Record<string, string>)['x-payment-receipt'];
  if (!receiptHash) return null;
  
  // In production: validate and decode the receipt
  return {
    receiptHash,
    txHash: '',
    payer: '',
    resourceId: 0,
    validUntil: 0,
  };
}

async function verifyPaymentProof(proof: PaymentProof, resourceId: number): Promise<boolean> {
  // In production: call SpellPayment.verifyReceipt() on-chain
  return proof.resourceId === resourceId && proof.validUntil > Date.now() / 1000;
}

function createPaymentRequiredResponse(config: {
  resourceId: number;
  description: string;
  priceEth: string;
  accessDurationSeconds: number;
  contractAddress: string;
  network: 'base';
}): Response {
  const body: X402PaymentRequired = {
    error: 'Payment Required',
    statusCode: 402,
    resourceId: config.resourceId,
    resourceDescription: config.description,
    payment: {
      amount: config.priceEth,
      currency: 'ETH',
      network: 'base',
      contractAddress: config.contractAddress,
      functionSignature: 'castSpell(uint256)',
      accepts: ['application/json'],
    },
    access: {
      duration: config.accessDurationSeconds,
      type: 'time-based',
    },
  };
  
  return new Response(JSON.stringify(body), {
    status: 402,
    headers: { 'Content-Type': 'application/json' },
  });
}

export default { createPaymentGate };
