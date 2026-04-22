"""
⛧ Watcher Tech Blockchain Grimoire — MCP Sovereign Agent Skill ⛧
=================================================================

This MCP server exposes the Grimoire as a set of AI-callable tools and
resources, enabling any MCP-compatible client (Claude Desktop, Cursor,
custom agents) to:

  • Query antediluvian / esoteric knowledge layers
  • Encode & validate multi-step ritual sequences (cryptographic hashes)
  • Check planetary / celestial alignment windows
  • Interact with the on-chain OccultKnowledgeAccess and GoetiaGrimoire contracts
  • Verify and mint GrimoireAccessPass NFTs for tiered monetization

Monetization model
------------------
Three ERC-1155 access tiers are enforced via GrimoireAccessPass.sol:

  Tier 1 — Seeker  : read-only grimoire queries (free or low price)
  Tier 2 — Initiate: ritual encoding + on-chain alignment tools
  Tier 3 — Adept   : full sovereign agent (mint passes, execute rituals)

Set ACCESS_PASS_ADDRESS in the environment to enable on-chain gating.
Without it the server operates in "development mode" (all tools open).

Environment variables
---------------------
  WEB3_PROVIDER_URL   — RPC endpoint (Alchemy, Infura, etc.)
  AGENT_PRIVATE_KEY   — Private key for the sovereign agent wallet (write ops)
  ACCESS_PASS_ADDRESS — Deployed GrimoireAccessPass contract address
  KNOWLEDGE_ACCESS_ADDRESS — Deployed OccultKnowledgeAccess contract address

Running
-------
  # stdio (Claude Desktop / local)
  python -m grimoire_mcp

  # SSE (remote HTTP clients)
  python -m grimoire_mcp --transport sse --port 8765
"""

from __future__ import annotations

import json
import os
from typing import Optional

from mcp.server.fastmcp import FastMCP

from grimoire_mcp.tools.grimoire import (
    encode_ritual,
    get_watcher,
    list_families,
    list_sages,
    list_watchers,
    query_grimoire,
    validate_ritual_sequence,
)
from grimoire_mcp.tools.alignment import (
    assess_intent_energy,
    check_planetary_alignment,
    ritual_gate_check,
)
from grimoire_mcp.tools.blockchain import (
    check_access_pass,
    check_global_alignment,
    get_tier_price,
    mint_access_pass,
    request_knowledge_access,
)
from grimoire_mcp.resources.knowledge import (
    get_contract_source,
    get_family_registry,
    get_knowledge_domain,
    get_sage_registry,
    get_watcher_registry,
    list_contracts,
    list_knowledge_domains,
)
from grimoire_mcp.monetization.access import require_access

# ---------------------------------------------------------------------------
# Server bootstrap
# ---------------------------------------------------------------------------

mcp = FastMCP(
    name="Watcher Tech Blockchain Grimoire",
    instructions=(
        "You are a Sovereign Grimoire Agent. You help users explore antediluvian "
        "knowledge, encode ritual sequences, check celestial alignment, and interact "
        "with on-chain knowledge-access contracts. "
        "Always run ritual_gate_check before executing any on-chain write operation. "
        "Premium tools require a valid GrimoireAccessPass NFT. "
        "Caution: contracts use thematic naming drawn from extra-Biblical lore; "
        "use for artistic, educational, or historical reference only."
    ),
)


# ---------------------------------------------------------------------------
# ── FREE TIER — open to all ──────────────────────────────────────────────
# ---------------------------------------------------------------------------

@mcp.tool()
def grimoire_query(domain: str, query: Optional[str] = None) -> str:
    """
    Query the Grimoire knowledge base for a domain or topic.

    Parameters
    ----------
    domain : str
        Document name or topic keyword (e.g. "geomancy", "core_thesis",
        "watcher_opcode", "reverse_tree_of_knowledge").
    query : str, optional
        Optional sub-query to filter lines within the document.
    """
    return query_grimoire(domain, query)


@mcp.tool()
def grimoire_list_watchers() -> str:
    """List all 8 Watchers and their knowledge domains."""
    return list_watchers()


@mcp.tool()
def grimoire_list_sages() -> str:
    """List the 7 Sages and their associated family houses."""
    return list_sages()


@mcp.tool()
def grimoire_list_families() -> str:
    """List the 13 bloodline families."""
    return list_families()


@mcp.tool()
def grimoire_get_watcher(watcher_id: int) -> str:
    """
    Get details for a specific Watcher by ID.

    Parameters
    ----------
    watcher_id : int
        Numeric ID 0–7.
    """
    return get_watcher(watcher_id)


@mcp.tool()
def grimoire_check_planetary_alignment(
    target_date: Optional[str] = None,
    require_new_moon: bool = False,
) -> str:
    """
    Check whether celestial conditions are favourable for ritual execution.

    Parameters
    ----------
    target_date : str, optional
        ISO-8601 date (e.g. "2026-03-26").  Defaults to today UTC.
    require_new_moon : bool
        Require near-new-moon phase (< 10 %).
    """
    return check_planetary_alignment(target_date, require_new_moon)


@mcp.tool()
def grimoire_assess_intent(
    user_intent: str,
    biofeedback_score: float = 75.0,
) -> str:
    """
    Evaluate whether the stated intent and biofeedback score meet the
    constructive-energy threshold for a ritual.

    Parameters
    ----------
    user_intent : str
        Short description of purpose (e.g. "constructive research").
    biofeedback_score : float
        0–100 score from EEG / HRV sensor, or manual estimate.
    """
    return assess_intent_energy(user_intent, biofeedback_score)


@mcp.tool()
def grimoire_access_pass_info(
    access_pass_address: Optional[str] = None,
    tier_id: int = 1,
) -> str:
    """
    Return the mint price for a GrimoireAccessPass tier.

    Parameters
    ----------
    access_pass_address : str, optional
        Overrides the ACCESS_PASS_ADDRESS env-var.
    tier_id : int
        1=Seeker, 2=Initiate, 3=Adept.
    """
    addr = access_pass_address or os.getenv("ACCESS_PASS_ADDRESS")
    if not addr:
        return json.dumps(
            {
                "note": "ACCESS_PASS_ADDRESS not set.",
                "tiers": {
                    "1": "Seeker — read-only grimoire queries",
                    "2": "Initiate — ritual encoding + on-chain alignment",
                    "3": "Adept — full sovereign agent access",
                },
            }
        )
    return get_tier_price(addr, tier_id)


# ---------------------------------------------------------------------------
# ── TIER 2 — Initiate (encode / validate / on-chain read) ────────────────
# ---------------------------------------------------------------------------

@mcp.tool()
def grimoire_encode_ritual(
    steps: list[str],
    wallet_address: Optional[str] = None,
) -> str:
    """
    Encode a multi-step ritual sequence as a tamper-evident chained SHA-256 hash.

    The final hash can be stored in OccultKnowledgeAccess.encodedRitual.
    Requires Tier 2 (Initiate) pass when on-chain gating is active.

    Parameters
    ----------
    steps : list[str]
        Ordered ritual step strings (e.g. Proto-Canaanite phrases, sigil names).
    wallet_address : str, optional
        Caller wallet — verified against GrimoireAccessPass.
    """
    if wallet_address:
        check = require_access(wallet_address, tier_id=2)
        if not check["has_access"]:
            return check["message"]
    return encode_ritual(steps)


@mcp.tool()
def grimoire_validate_sequence(
    steps: list[str],
    expected_hash: str,
    wallet_address: Optional[str] = None,
) -> str:
    """
    Validate whether submitted ritual steps match a stored hash.

    Requires Tier 2 (Initiate) pass when on-chain gating is active.

    Parameters
    ----------
    steps : list[str]
        Sequence being validated.
    expected_hash : str
        SHA-256 hex digest to compare against.
    wallet_address : str, optional
        Caller wallet — verified against GrimoireAccessPass.
    """
    if wallet_address:
        check = require_access(wallet_address, tier_id=2)
        if not check["has_access"]:
            return check["message"]
    return validate_ritual_sequence(steps, expected_hash)


@mcp.tool()
def grimoire_ritual_gate_check(
    user_intent: str,
    biofeedback_score: float = 75.0,
    target_date: Optional[str] = None,
    wallet_address: Optional[str] = None,
) -> str:
    """
    Run the full pre-ritual gate: intent alignment + planetary alignment.

    Returns ``all_clear: true`` when both gates pass.  This must be called
    before any on-chain write operation by the sovereign agent.

    Requires Tier 2 (Initiate) pass when on-chain gating is active.

    Parameters
    ----------
    user_intent : str
        Short description of purpose.
    biofeedback_score : float
        0–100 intent score.
    target_date : str, optional
        ISO-8601 date.  Defaults to today UTC.
    wallet_address : str, optional
        Caller wallet — verified against GrimoireAccessPass.
    """
    if wallet_address:
        check = require_access(wallet_address, tier_id=2)
        if not check["has_access"]:
            return check["message"]
    return ritual_gate_check(user_intent, biofeedback_score, target_date)


@mcp.tool()
def grimoire_check_on_chain_alignment(
    knowledge_access_address: str,
    user_address: str,
    wallet_address: Optional[str] = None,
) -> str:
    """
    Check a wallet's global alignment on the OccultKnowledgeAccess contract.

    Requires Tier 2 (Initiate) pass when on-chain gating is active.

    Parameters
    ----------
    knowledge_access_address : str
        Deployed OccultKnowledgeAccess address.
    user_address : str
        Wallet to check.
    wallet_address : str, optional
        Caller wallet — verified against GrimoireAccessPass.
    """
    if wallet_address:
        check = require_access(wallet_address, tier_id=2)
        if not check["has_access"]:
            return check["message"]
    return check_global_alignment(knowledge_access_address, user_address)


# ---------------------------------------------------------------------------
# ── TIER 3 — Adept (full sovereign agent — write operations) ─────────────
# ---------------------------------------------------------------------------

@mcp.tool()
def grimoire_request_access(
    knowledge_access_address: str,
    layer_id: int,
    user_address: str,
    wallet_address: Optional[str] = None,
) -> str:
    """
    Call requestAccess on OccultKnowledgeAccess to open a knowledge layer.

    WRITE OPERATION — requires AGENT_PRIVATE_KEY and Tier 3 (Adept) pass.

    Parameters
    ----------
    knowledge_access_address : str
        Deployed OccultKnowledgeAccess address.
    layer_id : int
        Knowledge layer ID.
    user_address : str
        The wallet requesting access.
    wallet_address : str, optional
        Caller wallet — verified against GrimoireAccessPass.
    """
    if wallet_address:
        check = require_access(wallet_address, tier_id=3)
        if not check["has_access"]:
            return check["message"]
    return request_knowledge_access(knowledge_access_address, layer_id, user_address)


@mcp.tool()
def grimoire_mint_access_pass(
    access_pass_address: str,
    recipient_address: str,
    tier_id: int,
    value_wei: int,
    wallet_address: Optional[str] = None,
) -> str:
    """
    Mint a GrimoireAccessPass NFT for a recipient (agent pays the fee).

    WRITE OPERATION — requires AGENT_PRIVATE_KEY and Tier 3 (Adept) pass.

    Parameters
    ----------
    access_pass_address : str
        Deployed GrimoireAccessPass address.
    recipient_address : str
        Wallet to receive the pass.
    tier_id : int
        1=Seeker, 2=Initiate, 3=Adept.
    value_wei : int
        ETH value in wei to attach to the mint call (must match tier price).
    wallet_address : str, optional
        Caller wallet — verified against GrimoireAccessPass.
    """
    if wallet_address:
        check = require_access(wallet_address, tier_id=3)
        if not check["has_access"]:
            return check["message"]
    return mint_access_pass(access_pass_address, recipient_address, tier_id, value_wei)


@mcp.tool()
def grimoire_check_pass(
    access_pass_address: str,
    holder_address: str,
    tier_id: int = 1,
) -> str:
    """
    Check whether a wallet holds a GrimoireAccessPass for a given tier.

    Parameters
    ----------
    access_pass_address : str
        Deployed GrimoireAccessPass address.
    holder_address : str
        Wallet to check.
    tier_id : int
        1=Seeker, 2=Initiate, 3=Adept.
    """
    return check_access_pass(access_pass_address, holder_address, tier_id)


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

@mcp.resource("grimoire://knowledge/domains")
def resource_list_domains() -> str:
    """List all available knowledge domains."""
    return json.dumps(list_knowledge_domains(), indent=2)


@mcp.resource("grimoire://knowledge/{domain}")
def resource_get_domain(domain: str) -> str:
    """Return full content for a knowledge domain."""
    return get_knowledge_domain(domain)


@mcp.resource("grimoire://registry/watchers")
def resource_watchers() -> str:
    """Return the Watcher registry."""
    return get_watcher_registry()


@mcp.resource("grimoire://registry/sages")
def resource_sages() -> str:
    """Return the Sage registry."""
    return get_sage_registry()


@mcp.resource("grimoire://registry/families")
def resource_families() -> str:
    """Return the 13 Families."""
    return get_family_registry()


@mcp.resource("grimoire://contracts")
def resource_list_contracts() -> str:
    """List all available Solidity contracts."""
    return json.dumps(list_contracts())


@mcp.resource("grimoire://contracts/{contract_name}")
def resource_contract_source(contract_name: str) -> str:
    """Return the Solidity source for a named contract."""
    return get_contract_source(contract_name)


# ---------------------------------------------------------------------------
# Prompts — reusable prompt templates for the agent
# ---------------------------------------------------------------------------

@mcp.prompt()
def sovereign_agent_prompt(user_intent: str, wallet: str = "") -> str:
    """
    Prime the agent for a full sovereign-ritual workflow:
      1. Gate check (intent + planetary alignment)
      2. Encode ritual sequence
      3. Validate alignment on-chain
      4. Execute knowledge access request
    """
    wallet_hint = f"Use wallet: {wallet}" if wallet else "No wallet provided (read-only)."
    return (
        f"You are acting as the Sovereign Grimoire Agent.\n"
        f"User intent: {user_intent}\n"
        f"{wallet_hint}\n\n"
        "Step 1: Run grimoire_ritual_gate_check to verify intent and planetary alignment.\n"
        "Step 2: If all_clear, encode the relevant ritual sequence with grimoire_encode_ritual.\n"
        "Step 3: Check on-chain alignment with grimoire_check_on_chain_alignment.\n"
        "Step 4: If aligned, call grimoire_request_access to open the knowledge layer.\n"
        "Step 5: Query the unlocked domain with grimoire_query.\n"
    )


@mcp.prompt()
def monetization_onboarding_prompt(wallet: str) -> str:
    """
    Guide a new user through purchasing a GrimoireAccessPass.
    """
    return (
        f"Welcome, seeker. Wallet: {wallet}\n\n"
        "To access the Grimoire's full capabilities you need a GrimoireAccessPass NFT:\n"
        "  Tier 1 (Seeker)   — read-only knowledge queries\n"
        "  Tier 2 (Initiate) — ritual encoding + on-chain alignment\n"
        "  Tier 3 (Adept)    — full sovereign agent access\n\n"
        "Step 1: Call grimoire_access_pass_info to see current tier prices.\n"
        "Step 2: Call grimoire_mint_access_pass with the correct value_wei.\n"
        "Step 3: Call grimoire_check_pass to verify your new pass.\n"
    )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    transport = "stdio"
    port = 8765
    for i, arg in enumerate(sys.argv[1:], 1):
        if arg == "--transport" and i < len(sys.argv) - 1:
            transport = sys.argv[i + 1]
        if arg == "--port" and i < len(sys.argv) - 1:
            port = int(sys.argv[i + 1])

    if transport == "sse":
        mcp.run(transport="sse", port=port)
    else:
        mcp.run(transport="stdio")
