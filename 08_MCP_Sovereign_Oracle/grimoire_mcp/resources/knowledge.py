"""
Resources — MCP Resource handlers that expose the Grimoire's knowledge layers,
Watcher registry, and contract ABIs as browsable resources.

Resources are read-only data the LLM client can fetch by URI.
"""

from __future__ import annotations

import json
from pathlib import Path

from grimoire_mcp.tools.grimoire import (
    FAMILIES,
    SAGES,
    WATCHERS,
    _DOCS_ROOT,
    _load_knowledge_base,
    _KNOWLEDGE_BASE,
)

_CONTRACTS_ROOT = Path(__file__).parent.parent.parent / "contracts"


def list_knowledge_domains() -> list[dict]:
    """
    Return a list of all available knowledge domain names that can be
    passed to query_grimoire().
    """
    _load_knowledge_base()
    return [{"domain": k, "uri": f"grimoire://knowledge/{k}"} for k in sorted(_KNOWLEDGE_BASE)]


def get_knowledge_domain(domain: str) -> str:
    """Return full content for a knowledge domain resource."""
    _load_knowledge_base()
    key = domain.lower().replace("-", "_").replace(" ", "_")
    content = _KNOWLEDGE_BASE.get(key)
    if content is None:
        available = sorted(_KNOWLEDGE_BASE.keys())
        return f"Domain not found. Available: {available}"
    return content


def get_watcher_registry() -> str:
    """Return the full Watcher registry as JSON."""
    return json.dumps(WATCHERS, indent=2)


def get_sage_registry() -> str:
    """Return the 7 Sages as JSON."""
    return json.dumps(SAGES, indent=2)


def get_family_registry() -> str:
    """Return the 13 Families as JSON."""
    return json.dumps(FAMILIES, indent=2)


def get_contract_source(contract_name: str) -> str:
    """
    Return the Solidity source for a named contract.

    Parameters
    ----------
    contract_name : str
        Name without extension, e.g. "OccultKnowledgeAccess",
        "GrimoireAccessPass", "GoetiaGrimoire".
    """
    path = _CONTRACTS_ROOT / f"{contract_name}.sol"
    if not path.exists():
        available = [p.stem for p in _CONTRACTS_ROOT.glob("*.sol")]
        return f"Contract '{contract_name}' not found. Available: {available}"
    return path.read_text(encoding="utf-8")


def list_contracts() -> list[str]:
    """Return names of all Solidity contracts in contracts/."""
    return sorted(p.stem for p in _CONTRACTS_ROOT.glob("*.sol"))
