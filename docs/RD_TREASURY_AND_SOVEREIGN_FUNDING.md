# R&D Treasury & Sovereign Funding

**Independent R&D arm — see also the [Independent Research & Development Notice](../README.md#independent-research--development-notice).**

## What this is

The Watcher Tech Blockchain Grimoire is positioned as a **living, breathing R&D arm**:
an ongoing, independent research effort into blockchain, AI/AGI, RAG-AGI, MCP, and
sovereign agentic framework technology. To operate sustainably, it has its **own
dedicated treasury wallet** — separate from the author's personal payment address
(`PAYMENT_CONFIG.address` / `normancomics.eth` in [`lib/agent-config.ts`](../lib/agent-config.ts)).

This separation exists so that:

- Funding that supports the R&D arm's ongoing costs (compute, gas, infrastructure,
  tooling) is transparently distinct from any personal wallet.
- The treasury can be governed, audited, or rotated independently of personal funds.
- The project's funding flows are legible to anyone — human or agent — inspecting
  the repository, consistent with the project's existing agent-discovery metadata
  (`/.well-known/agent`, `AGENT_SCHEMA`, `A2A_MANIFEST`).

This is **not** a fundraising solicitation, investment product, or security offering.
Nothing here constitutes financial advice. See the
[Independent R&D Notice](../README.md#independent-research--development-notice) for
the full disclaimer.

## Why Superfluid

The project already uses **x402** (one-shot HTTP 402 micropayments, see
[`x402-monetization/payment-gates.ts`](../x402-monetization/payment-gates.ts)) as its
primary payment rail. **Superfluid** complements this with **continuous streaming
payments** (CFA — Constant Flow Agreement): instead of a single payment per request,
an entrant opens a stream of ETHx (Super ETH) that flows second-by-second into the
treasury for as long as access is needed. See
[`x402-monetization/superfluid-streams.ts`](../x402-monetization/superfluid-streams.ts)
and `MuWatcherGate.enterGateSuperfluid()` in
[`06_Contracts/MuWatcherGate.sol`](../06_Contracts/MuWatcherGate.sol).

Routing those streams to a dedicated R&D Treasury (rather than a personal address)
is what makes the funding model match the "independent R&D arm" framing: ongoing,
metered, and separable from any individual.

## Setting up the R&D Treasury wallet

The agent/repository tooling **never generates, stores, or transmits private keys**.
Generate your own wallet locally, and only ever share the public address:

```bash
# Option A — Foundry (already used by this repo's deploy scripts)
cast wallet new

# Option B — ethers.js
node -e "console.log(require('ethers').Wallet.createRandom().address)"
```

Then:

1. Set the resulting **address** (never the private key) as `RD_TREASURY_ADDRESS`
   in your `.env` (see [`.env.example`](../.env.example)).
2. Optionally mirror the address into `RD_TREASURY.address` in
   [`lib/agent-config.ts`](../lib/agent-config.ts) if the website/agent-discovery
   layer should display or publish it.
3. Fund the wallet with a small amount of ETH on Base for gas, and wrap ETH → ETHx
   if the treasury itself needs to open outbound streams.
4. Use `createRDTreasuryConfig()` from
   [`x402-monetization/superfluid-streams.ts`](../x402-monetization/superfluid-streams.ts)
   wherever a `SuperfluidConfig` is needed — it reads `RD_TREASURY_ADDRESS` from the
   environment automatically (or accepts an explicit address) and throws a clear
   `RDTreasuryNotConfiguredError` if unset, instead of silently defaulting to a
   personal address.
5. Store the private key in a hardware wallet, secrets manager, or encrypted vault —
   **never** in this repository, `.env` committed to git, CI logs, or chat history.

## Governance

For now, the R&D Treasury is a single-signer wallet controlled by the project's
maintainer(s). As the R&D arm matures, this doc is the place to record any move to
a multisig (e.g. Safe on Base) or on-chain governance module, and to log treasury
rotations (old address → new address, reason, date) for auditability.

| Date | Change | Notes |
|------|--------|-------|
| —    | Initial R&D Treasury scaffolding added | Wallet generation is a manual, local, non-custodial step — no address has been generated or committed yet. |
