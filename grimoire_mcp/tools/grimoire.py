"""
Grimoire Tools — query the on-chain knowledge registry and lore documents.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Knowledge base loader — reads the docs/ directory at startup
# ---------------------------------------------------------------------------
_DOCS_ROOT = Path(__file__).parent.parent.parent / "docs"
_CONTRACTS_ROOT = Path(__file__).parent.parent.parent / "contracts"

_KNOWLEDGE_BASE: dict[str, str] = {}

# Maximum bytes returned per query_grimoire call
_MAX_CONTENT_BYTES = 8000


def _load_knowledge_base() -> None:
    """Load all text/markdown files from docs/ into an in-memory dict."""
    if _KNOWLEDGE_BASE:
        return
    for path in _DOCS_ROOT.rglob("*"):
        if path.is_file() and path.suffix in {".md", ".txt"}:
            key = path.stem.lower().replace(" ", "_").replace("-", "_")
            try:
                _KNOWLEDGE_BASE[key] = path.read_text(encoding="utf-8")
            except Exception:
                pass


# ---------------------------------------------------------------------------
# Watcher / Sage registry (mirrors GoetiaGrimoire.sol constructor)
# ---------------------------------------------------------------------------
WATCHERS: dict[int, dict] = {
    0: {"name": "Azazel", "domain": "Weaponry & metallurgy"},
    1: {"name": "Semyaza", "domain": "Divination & ritual"},
    2: {"name": "Armaros", "domain": "Enochian cryptography"},
    3: {"name": "Baraqel", "domain": "Alchemy & medicine"},
    4: {"name": "Kokabiel", "domain": "Stellar mechanics"},
    5: {"name": "Tamiel", "domain": "Astronomy & time"},
    6: {"name": "Ramiel", "domain": "Secrets of death & resurrection"},
    7: {"name": "Daniel", "domain": "Forbidden arts"},
}

SAGES: dict[int, dict] = {
    0: {"name": "Quetzalcoatl", "family_id": 0},
    1: {"name": "Hermes", "family_id": 1},
    2: {"name": "Thoth", "family_id": 2},
    3: {"name": "Oannes", "family_id": 3},
    4: {"name": "Enki", "family_id": 4},
    5: {"name": "Hesiod", "family_id": 5},
    6: {"name": "Ziusudra", "family_id": 6},
}

FAMILIES: dict[int, str] = {
    0: "House of Azazel",
    1: "House of Semyaza",
    2: "House of Armaros",
    3: "House of Baraqel",
    4: "House of Kokabiel",
    5: "House of Tamiel",
    6: "House of Ramiel",
    7: "House of Daniel",
    8: "House of Enoch",
    9: "House of Cain",
    10: "House of Seth",
    11: "House of Lamech",
    12: "House of Methuselah",
}


# ---------------------------------------------------------------------------
# Tool functions
# ---------------------------------------------------------------------------

def query_grimoire(domain: str, query: Optional[str] = None) -> str:
    """
    Query the Grimoire knowledge base.

    Parameters
    ----------
    domain : str
        Topic or document name to retrieve.  Fuzzy-matched against the docs/
        directory (e.g. "geomancy", "core_thesis", "watcher_opcode").
    query : str, optional
        Optional keywords to filter/highlight within the returned content.

    Returns
    -------
    str
        Matching document content, or a list of available domains.
    """
    _load_knowledge_base()
    key = domain.lower().replace(" ", "_").replace("-", "_")

    # Exact match
    if key in _KNOWLEDGE_BASE:
        content = _KNOWLEDGE_BASE[key]
    else:
        # Fuzzy: find all docs whose key contains the query term
        matches = {k: v for k, v in _KNOWLEDGE_BASE.items() if key in k}
        if not matches:
            available = sorted(_KNOWLEDGE_BASE.keys())
            return (
                f"Domain '{domain}' not found.\n\nAvailable domains:\n"
                + "\n".join(f"  • {d}" for d in available)
            )
        if len(matches) == 1:
            content = next(iter(matches.values()))
        else:
            return (
                f"Multiple matches for '{domain}':\n"
                + "\n".join(f"  • {k}" for k in matches)
                + "\nPlease be more specific."
            )

    if query:
        # Return only paragraphs/lines that contain the query terms
        lines = content.split("\n")
        relevant = [l for l in lines if query.lower() in l.lower()]
        if relevant:
            return "\n".join(relevant)

    return content[:_MAX_CONTENT_BYTES]  # cap at 8 KB per call


def list_watchers() -> str:
    """Return the full Watcher registry from the GoetiaGrimoire."""
    rows = [f"ID {k}: {v['name']} — {v['domain']}" for k, v in WATCHERS.items()]
    return "⛧ Watcher Registry\n" + "\n".join(rows)


def list_sages() -> str:
    """Return the 7 Sages and their associated family houses."""
    rows = []
    for k, v in SAGES.items():
        family = FAMILIES.get(v["family_id"], "Unknown")
        rows.append(f"ID {k}: {v['name']} — {family}")
    return "⛧ Sage Registry\n" + "\n".join(rows)


def list_families() -> str:
    """Return the 13 bloodline families."""
    rows = [f"ID {k}: {v}" for k, v in FAMILIES.items()]
    return "⛧ 13 Families\n" + "\n".join(rows)


def get_watcher(watcher_id: int) -> str:
    """Return details for a specific Watcher by numeric ID (0–7)."""
    if watcher_id not in WATCHERS:
        return f"Watcher ID {watcher_id} not found. Valid range: 0–7."
    w = WATCHERS[watcher_id]
    return json.dumps({"id": watcher_id, **w}, indent=2)


def encode_ritual(steps: list[str]) -> str:
    """
    Encode a multi-step ritual sequence as a chained SHA-256 hash.

    Each step is hashed incrementally, forming a tamper-evident chain.
    The final hex digest can be stored in OccultKnowledgeAccess.encodedRitual.

    Parameters
    ----------
    steps : list[str]
        Ordered list of ritual step strings.

    Returns
    -------
    str
        JSON with the final hash and intermediate hashes per step.
    """
    if not steps:
        return json.dumps({"error": "steps list must not be empty"})

    chain: list[str] = []
    current = ""
    for step in steps:
        current = hashlib.sha256((current + step).encode()).hexdigest()
        chain.append(current)

    return json.dumps(
        {
            "final_hash": chain[-1],
            "chain": [{"step": s, "hash": h} for s, h in zip(steps, chain)],
        },
        indent=2,
    )


def validate_ritual_sequence(steps: list[str], expected_hash: str) -> str:
    """
    Validate whether a submitted ritual sequence matches a stored hash.

    Parameters
    ----------
    steps : list[str]
        The sequence being validated.
    expected_hash : str
        The SHA-256 hex digest previously produced by encode_ritual.

    Returns
    -------
    str
        JSON result with ``valid`` bool and the computed hash.
    """
    encoded = json.loads(encode_ritual(steps))
    computed = encoded.get("final_hash", "")
    valid = computed.lower() == expected_hash.lower()
    return json.dumps({"valid": valid, "computed": computed, "expected": expected_hash})
