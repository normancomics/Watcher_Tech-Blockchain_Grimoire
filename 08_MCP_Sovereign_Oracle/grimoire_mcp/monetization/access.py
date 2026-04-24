"""
Access middleware — enforces GrimoireAccessPass token-gating before any
premium tool call reaches the blockchain or returns sensitive grimoire content.

Usage (inside the MCP server):

    from grimoire_mcp.monetization.access import require_access

    @server.tool()
    def my_premium_tool(wallet: str, ...):
        check = require_access(wallet, tier_id=2)
        if not check["has_access"]:
            return check["message"]
        # ... rest of tool logic
"""

from __future__ import annotations

import json
import os
from functools import wraps
from typing import Callable, Optional

# Import lazily to avoid hard dependency at module load time
_blockchain: Optional[object] = None


def _get_blockchain_module():
    global _blockchain
    if _blockchain is None:
        from grimoire_mcp.tools import blockchain  # noqa: PLC0415
        _blockchain = blockchain
    return _blockchain


# Tier definitions — mirrors GrimoireAccessPass.sol
TIERS = {
    1: "Seeker",
    2: "Initiate",
    3: "Adept",
}

# Tools allowed per tier (cumulative: higher tiers include lower)
TIER_PERMISSIONS: dict[int, set[str]] = {
    1: {
        "query_grimoire",
        "list_watchers",
        "list_sages",
        "list_families",
        "get_watcher",
        "check_planetary_alignment",
        "assess_intent_energy",
    },
    2: {
        "encode_ritual",
        "validate_ritual_sequence",
        "ritual_gate_check",
        "check_global_alignment",
        "request_knowledge_access",
    },
    3: {
        "mint_access_pass",
        "get_tier_price",
        "check_access_pass",
        # Add future sovereign-agent-exclusive tools here
    },
}


def get_min_tier_for_tool(tool_name: str) -> int:
    """Return the minimum tier required to use a given tool (0 = free)."""
    for tier_id in sorted(TIER_PERMISSIONS.keys()):
        if tool_name in TIER_PERMISSIONS[tier_id]:
            return tier_id
    return 0  # no restriction


def require_access(
    wallet_address: str,
    tier_id: int,
    access_pass_address: Optional[str] = None,
) -> dict:
    """
    Check whether *wallet_address* holds a GrimoireAccessPass of at least
    *tier_id*.  Returns a dict with ``has_access`` and a human-readable
    ``message``.

    If ACCESS_PASS_ADDRESS env-var is unset *and* no address is provided,
    access is granted unconditionally (useful for local development).
    """
    contract_addr = access_pass_address or os.getenv("ACCESS_PASS_ADDRESS")
    if not contract_addr:
        return {
            "has_access": True,
            "message": (
                "ACCESS_PASS_ADDRESS not configured — "
                "access granted (development mode)."
            ),
        }

    bc = _get_blockchain_module()
    result = json.loads(
        bc.check_access_pass(contract_addr, wallet_address, tier_id)  # type: ignore[attr-defined]
    )

    if "error" in result:
        return {
            "has_access": False,
            "message": f"Access check failed: {result['error']}",
        }

    tier_name = TIERS.get(tier_id, f"Tier {tier_id}")
    if result["has_access"]:
        return {
            "has_access": True,
            "message": f"Access granted — {tier_name} pass verified.",
            "balance": result["balance"],
        }
    else:
        return {
            "has_access": False,
            "message": (
                f"Access denied — {tier_name} pass required. "
                f"Mint one at the GrimoireAccessPass contract: {contract_addr}"
            ),
        }
