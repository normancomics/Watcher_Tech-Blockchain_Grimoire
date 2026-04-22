"""
Blockchain Tools — read-only and write interactions with the Grimoire contracts.

Requires a Web3 provider URL via the WEB3_PROVIDER_URL environment variable
(e.g. an Alchemy / Infura endpoint).  All write operations require
AGENT_PRIVATE_KEY to be set.  The module degrades gracefully when web3 is not
installed, returning informative error messages.
"""

from __future__ import annotations

import json
import os
from typing import Any, Optional

try:
    from web3 import Web3  # type: ignore
    from web3.middleware import ExtraDataToPOAMiddleware  # type: ignore
    _WEB3_AVAILABLE = True
except ImportError:
    _WEB3_AVAILABLE = False

# ---------------------------------------------------------------------------
# Minimal ABIs (only the functions used by this skill)
# ---------------------------------------------------------------------------

_KNOWLEDGE_ACCESS_ABI = json.loads("""
[
  {
    "inputs": [
      {"internalType": "uint256", "name": "id", "type": "uint256"},
      {"internalType": "string",  "name": "domain",        "type": "string"},
      {"internalType": "string",  "name": "encodedRitual", "type": "string"},
      {"internalType": "uint256", "name": "activationTime","type": "uint256"},
      {"internalType": "address", "name": "guardian",      "type": "address"}
    ],
    "name": "registerLayer",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "id",   "type": "uint256"},
      {"internalType": "address", "name": "user", "type": "address"}
    ],
    "name": "requestAccess",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "user",    "type": "address"},
      {"internalType": "bool",    "name": "aligned", "type": "bool"}
    ],
    "name": "setGlobalAlignment",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "", "type": "address"}],
    "name": "globalAlignment",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true,  "internalType": "uint256", "name": "id",   "type": "uint256"},
      {"indexed": false, "internalType": "address", "name": "user", "type": "address"}
    ],
    "name": "AccessGranted",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true,  "internalType": "uint256", "name": "id",   "type": "uint256"},
      {"indexed": false, "internalType": "address", "name": "user", "type": "address"}
    ],
    "name": "AccessDenied",
    "type": "event"
  }
]
""")

_ACCESS_PASS_ABI = json.loads("""
[
  {
    "inputs": [
      {"internalType": "address", "name": "account", "type": "address"},
      {"internalType": "uint256", "name": "id",      "type": "uint256"}
    ],
    "name": "balanceOf",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "to",     "type": "address"},
      {"internalType": "uint256", "name": "id",     "type": "uint256"},
      {"internalType": "uint256", "name": "amount", "type": "uint256"}
    ],
    "name": "mint",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "tierId", "type": "uint256"}],
    "name": "tierPrice",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
]
""")


# ---------------------------------------------------------------------------
# Gas limits (configurable via environment variables)
# ---------------------------------------------------------------------------

_GAS_STANDARD = int(os.getenv("GAS_STANDARD", "300000"))
_GAS_MINT = int(os.getenv("GAS_MINT", "200000"))

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _get_web3() -> "Web3":
    if not _WEB3_AVAILABLE:
        raise RuntimeError(
            "web3 not installed. Run: pip install web3"
        )
    provider_url = os.getenv("WEB3_PROVIDER_URL")
    if not provider_url:
        raise RuntimeError(
            "WEB3_PROVIDER_URL environment variable not set. "
            "Example: https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
        )
    w3 = Web3(Web3.HTTPProvider(provider_url))
    # POA middleware for testnets (Polygon, Sepolia, etc.)
    w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)
    if not w3.is_connected():
        raise RuntimeError(f"Cannot connect to Web3 provider: {provider_url}")
    return w3


def _get_account(w3: "Web3"):
    pk = os.getenv("AGENT_PRIVATE_KEY")
    if not pk:
        raise RuntimeError(
            "AGENT_PRIVATE_KEY environment variable not set. "
            "Required for write operations."
        )
    return w3.eth.account.from_key(pk)


def _send_tx(w3: "Web3", fn, account) -> str:
    """Build, sign and broadcast a transaction; return the tx hash."""
    tx = fn.build_transaction(
        {
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
            "gas": _GAS_STANDARD,
            "gasPrice": w3.eth.gas_price,
        }
    )
    signed = w3.eth.account.sign_transaction(tx, account.key)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    return tx_hash.hex()


# ---------------------------------------------------------------------------
# Public tool functions
# ---------------------------------------------------------------------------

def check_global_alignment(
    knowledge_access_address: str,
    user_address: str,
) -> str:
    """
    Check whether a wallet address has global alignment on the
    OccultKnowledgeAccess contract.

    Parameters
    ----------
    knowledge_access_address : str
        Deployed address of OccultKnowledgeAccess.sol.
    user_address : str
        The wallet address to check.

    Returns
    -------
    str
        JSON with ``aligned`` bool.
    """
    try:
        w3 = _get_web3()
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(knowledge_access_address),
            abi=_KNOWLEDGE_ACCESS_ABI,
        )
        aligned: bool = contract.functions.globalAlignment(
            Web3.to_checksum_address(user_address)
        ).call()
        return json.dumps({"user": user_address, "aligned": aligned})
    except Exception as exc:
        return json.dumps({"error": str(exc)})


def request_knowledge_access(
    knowledge_access_address: str,
    layer_id: int,
    user_address: str,
) -> str:
    """
    Invoke requestAccess on OccultKnowledgeAccess to gate knowledge retrieval.

    Parameters
    ----------
    knowledge_access_address : str
        Deployed address of OccultKnowledgeAccess.sol.
    layer_id : int
        Knowledge layer ID.
    user_address : str
        The wallet requesting access (must be globally/layer aligned).

    Returns
    -------
    str
        JSON with transaction hash or error.
    """
    try:
        w3 = _get_web3()
        account = _get_account(w3)
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(knowledge_access_address),
            abi=_KNOWLEDGE_ACCESS_ABI,
        )
        fn = contract.functions.requestAccess(
            layer_id,
            Web3.to_checksum_address(user_address),
        )
        tx_hash = _send_tx(w3, fn, account)
        return json.dumps({"tx_hash": tx_hash, "layer_id": layer_id, "user": user_address})
    except Exception as exc:
        return json.dumps({"error": str(exc)})


def check_access_pass(
    access_pass_address: str,
    holder_address: str,
    tier_id: int = 1,
) -> str:
    """
    Check whether a wallet holds a GrimoireAccessPass for a given tier.

    Tier IDs (defined in GrimoireAccessPass.sol):
      1 = Seeker  (read-only)
      2 = Initiate (read + ritual tools)
      3 = Adept   (full sovereign agent access)

    Parameters
    ----------
    access_pass_address : str
        Deployed address of GrimoireAccessPass.sol.
    holder_address : str
        The wallet to check.
    tier_id : int
        Access tier to verify (1, 2, or 3).

    Returns
    -------
    str
        JSON with ``has_access`` bool and balance.
    """
    try:
        w3 = _get_web3()
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(access_pass_address),
            abi=_ACCESS_PASS_ABI,
        )
        balance: int = contract.functions.balanceOf(
            Web3.to_checksum_address(holder_address), tier_id
        ).call()
        return json.dumps(
            {
                "holder": holder_address,
                "tier_id": tier_id,
                "balance": balance,
                "has_access": balance > 0,
            }
        )
    except Exception as exc:
        return json.dumps({"error": str(exc)})


def get_tier_price(
    access_pass_address: str,
    tier_id: int,
) -> str:
    """
    Return the mint price (in wei) for a GrimoireAccessPass tier.

    Parameters
    ----------
    access_pass_address : str
        Deployed address of GrimoireAccessPass.sol.
    tier_id : int
        Tier to query (1=Seeker, 2=Initiate, 3=Adept).

    Returns
    -------
    str
        JSON with ``price_wei`` and ``price_eth``.
    """
    try:
        w3 = _get_web3()
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(access_pass_address),
            abi=_ACCESS_PASS_ABI,
        )
        price_wei: int = contract.functions.tierPrice(tier_id).call()
        price_eth = price_wei / 10**18
        return json.dumps(
            {"tier_id": tier_id, "price_wei": price_wei, "price_eth": price_eth}
        )
    except Exception as exc:
        return json.dumps({"error": str(exc)})


def mint_access_pass(
    access_pass_address: str,
    recipient_address: str,
    tier_id: int,
    value_wei: int,
) -> str:
    """
    Mint a GrimoireAccessPass NFT to a recipient (agent pays the mint fee).

    Parameters
    ----------
    access_pass_address : str
        Deployed address of GrimoireAccessPass.sol.
    recipient_address : str
        Wallet to receive the pass.
    tier_id : int
        Tier to mint (1, 2, or 3).
    value_wei : int
        ETH value in wei to send with the mint call.

    Returns
    -------
    str
        JSON with transaction hash or error.
    """
    try:
        w3 = _get_web3()
        account = _get_account(w3)
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(access_pass_address),
            abi=_ACCESS_PASS_ABI,
        )
        fn = contract.functions.mint(
            Web3.to_checksum_address(recipient_address),
            tier_id,
            1,
        )
        tx = fn.build_transaction(
            {
                "from": account.address,
                "nonce": w3.eth.get_transaction_count(account.address),
                "gas": _GAS_MINT,
                "gasPrice": w3.eth.gas_price,
                "value": value_wei,
            }
        )
        signed = w3.eth.account.sign_transaction(tx, account.key)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction).hex()
        return json.dumps(
            {
                "tx_hash": tx_hash,
                "recipient": recipient_address,
                "tier_id": tier_id,
                "value_wei": value_wei,
            }
        )
    except Exception as exc:
        return json.dumps({"error": str(exc)})
