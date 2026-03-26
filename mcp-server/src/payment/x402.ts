/**
 * Grimoire Oracle — x402 Payment Middleware
 *
 * Implements HTTP 402 Payment Required responses for monetized MCP tools.
 * Compatible with the x402 protocol (coinbase/x402) for crypto micropayments.
 *
 * When a client calls a paid endpoint without valid payment headers,
 * the server returns HTTP 402 with payment instructions. The client
 * signs a payment transaction and retries with the payment proof.
 */

import type { Request, Response, NextFunction } from "express";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface PricingConfig {
  receiverAddress: string;
  network: string;
  currency: string;
  tools: Record<
    string,
    {
      price: string;
      description: string;
    }
  >;
}

/**
 * Loads pricing configuration from config/pricing.json.
 */
export function loadPricingConfig(): PricingConfig {
  try {
    const configPath = join(__dirname, "../../config/pricing.json");
    const raw = readFileSync(configPath, "utf-8");
    return JSON.parse(raw) as PricingConfig;
  } catch {
    // Return default pricing if config not found
    return {
      receiverAddress: "0x0000000000000000000000000000000000000000",
      network: "base-sepolia",
      currency: "USDC",
      tools: {
        grimoire_audit_scan: {
          price: "0.50",
          description: "Smart contract audit scan (7 archetypes)",
        },
        grimoire_query_codex: {
          price: "0.10",
          description: "Knowledge base query",
        },
        grimoire_defense_recommend: {
          price: "0.25",
          description: "Defense paradigm recommendation",
        },
        grimoire_watcher_consult: {
          price: "0.75",
          description: "Watcher domain consultation",
        },
        grimoire_family_threat_intel: {
          price: "0.30",
          description: "Family archetype threat intelligence",
        },
      },
    };
  }
}

/**
 * x402 Payment Required response format.
 *
 * When a client calls a paid endpoint without valid payment,
 * this generates the proper 402 response with payment instructions.
 */
export interface X402PaymentRequired {
  x402Version: number;
  error: string;
  accepts: Array<{
    scheme: string;
    network: string;
    maxAmountRequired: string;
    resource: string;
    description: string;
    mimeType: string;
    payTo: string;
    maxTimeoutSeconds: number;
    asset: string;
    extra?: Record<string, unknown>;
  }>;
}

/**
 * Creates a 402 Payment Required response body.
 */
export function createPaymentRequired(
  toolName: string,
  resource: string,
  pricing: PricingConfig,
): X402PaymentRequired {
  const toolPricing = pricing.tools[toolName];
  const price = toolPricing?.price ?? "0.10";
  const description =
    toolPricing?.description ?? "Grimoire Oracle tool access";

  return {
    x402Version: 1,
    error: "X-PAYMENT-REQUIRED",
    accepts: [
      {
        scheme: "exact",
        network: pricing.network,
        maxAmountRequired: price,
        resource,
        description,
        mimeType: "application/json",
        payTo: pricing.receiverAddress,
        maxTimeoutSeconds: 300,
        asset: pricing.currency,
      },
    ],
  };
}

/**
 * Validates an x402 payment header.
 *
 * In production, this verifies the payment signature against
 * the blockchain. For MVP, it checks header presence and format.
 */
export function validatePaymentHeader(
  paymentHeader: string | undefined,
  _toolName: string,
  _pricing: PricingConfig,
): { valid: boolean; error?: string } {
  if (!paymentHeader) {
    return { valid: false, error: "Missing X-PAYMENT header" };
  }

  // ⚠️ PRODUCTION WARNING: This validation is intentionally permissive
  // for MVP/testing. It accepts any non-empty X-PAYMENT header.
  //
  // Before deploying to production:
  // 1. Install @coinbase/x402: `npm install @coinbase/x402`
  // 2. Replace this function body with proper verification:
  //
  //   import { verifyPayment } from "@coinbase/x402";
  //   const result = await verifyPayment(paymentHeader, {
  //     network: pricing.network,
  //     receiverAddress: pricing.receiverAddress,
  //   });
  //   return { valid: result.isValid, error: result.error };

  if (process.env["NODE_ENV"] === "production" && !process.env["GRIMOIRE_ALLOW_MVP_PAYMENTS"]) {
    return {
      valid: false,
      error: "Production mode requires @coinbase/x402 payment verification. Set GRIMOIRE_ALLOW_MVP_PAYMENTS=1 to override.",
    };
  }

  return { valid: true };
}

/**
 * Creates an x402 payment guard for a specific tool.
 *
 * Returns Express middleware that enforces payment for the given tool.
 */
export function x402PaymentGuard(toolName: string, pricing: PricingConfig) {
  return (req: Request, res: Response, next: NextFunction): void => {
    // Check if this tool requires payment
    const toolPricing = pricing.tools[toolName];
    if (!toolPricing) {
      next();
      return;
    }

    // Check for free-tier header (for testing/development)
    const freeAccessKey = process.env["GRIMOIRE_FREE_ACCESS_KEY"];
    if (freeAccessKey && req.headers["x-grimoire-free-access"] === freeAccessKey) {
      next();
      return;
    }

    // Validate x402 payment
    const paymentHeader = req.headers["x-payment"] as string | undefined;
    const validation = validatePaymentHeader(paymentHeader, toolName, pricing);

    if (!validation.valid) {
      const resource = `${req.protocol}://${req.get("host") ?? "localhost"}${req.originalUrl}`;
      const paymentRequired = createPaymentRequired(
        toolName,
        resource,
        pricing,
      );

      res.status(402).json(paymentRequired);
      return;
    }

    next();
  };
}
