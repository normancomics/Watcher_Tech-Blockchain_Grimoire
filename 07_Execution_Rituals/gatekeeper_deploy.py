"""
Gatekeeper Subagent — WatcherGate Deployment Ritual
=====================================================
Symbolic / Educational Framework — normancomics.eth 2026 A.D.

Deployment skeleton for the WatcherGate.sol contract on Base mainnet
(chain ID 8453), designed to operate within a $1 ETH budget.

This script illustrates the deployment sequence, layer configuration,
and agent registration flow for the Gatekeeper Subagent. It uses the
standard Python ``web3`` library interface (pip install web3) but is
structured as an educational skeleton — supply real credentials before
executing against mainnet.

Contract: technical-grimoire/smart-contracts/WatcherGate.sol
Network:  Base mainnet  (chain ID 8453)
RPC:      https://mainnet.base.org

Layered Encoding Pipeline (encoded keys per layer):
  Latin → Enochian → Proto-Canaanite → Binary → Hex

Budget Guidance (at ~$3 000/ETH, Base gas ~0.0001 gwei):
  Deployment cost  ≈ 0.000 08 ETH  (~$0.24)
  Layer config ×13 ≈ 0.000 13 ETH  (~$0.39)
  Buffer           ≈ 0.000 07 ETH  (~$0.21)
  -------------------------------------------
  Estimated total  ≈ 0.000 28 ETH  (~$0.84)  ← well within $1
"""

from __future__ import annotations

import hashlib
import json
import os
import time
from dataclasses import dataclass, field
from enum import IntEnum
from typing import Optional

# ─── Auth Modes (mirror the Solidity enum) ────────────────────────────────────

class AuthMode(IntEnum):
    PAYMENT_ONLY = 0
    SIGIL_ONLY   = 1
    DUAL_AUTH    = 2


# ─── Layer Encoding: Latin → Enochian → Proto-Canaanite → Binary → Hex ───────

_LATIN_TO_ENOCHIAN: dict[str, str] = {
    "A": "Un",  "B": "Pe",  "C": "Veh", "D": "Ged", "E": "Graph",
    "F": "Or",  "G": "Ged", "H": "Na",  "I": "Gon", "J": "I",
    "K": "Veh", "L": "Ur",  "M": "Tal", "N": "Drux","O": "Med",
    "P": "Mals","Q": "Ger", "R": "Don", "S": "Fam", "T": "Gisg",
    "U": "Van", "V": "Van", "W": "Veh", "X": "Pal", "Y": "Gon",
    "Z": "Ceph",
}

_ENOCHIAN_TO_PROTO_CANAANITE: dict[str, str] = {
    # Representative subset of Enochian words → proto-Canaanite phoneme clusters
    "Un": "𐤀",  "Pe": "𐤁",  "Veh": "𐤂", "Ged": "𐤃", "Graph": "𐤄",
    "Or": "𐤅",  "Na":  "𐤆", "Gon": "𐤇", "Ur":  "𐤈", "Tal":   "𐤉",
    "Drux":"𐤊", "Med": "𐤋", "Mals":"𐤌", "Ger": "𐤍", "Don":   "𐤎",
    "Fam": "𐤏", "Gisg":"𐤐", "Van": "𐤑", "Pal": "𐤒", "Ceph":  "𐤓",
    "I":   "𐤔",
}


def latin_to_enochian(text: str) -> str:
    """Translate Latin characters to symbolic Enochian words."""
    return "-".join(
        _LATIN_TO_ENOCHIAN.get(ch.upper(), ch)
        for ch in text
        if ch.isalpha()
    )


def enochian_to_proto_canaanite(enochian: str) -> str:
    """Translate Enochian word sequence to proto-Canaanite glyphs."""
    return "".join(
        _ENOCHIAN_TO_PROTO_CANAANITE.get(word, "·")
        for word in enochian.split("-")
    )


def encode_layer_key(layer_phrase: str) -> str:
    """
    Full pipeline: Latin → Enochian → Proto-Canaanite → Binary → Hex
    Returns the 32-byte hex key used as the on-chain ``encodedKey``.

    The full original phrase (including digits) is mixed into the final hash
    so that each layer index produces a distinct key even though the binary
    representation of the alphabetic portion is identical across phrases that
    differ only by their numeric suffix.
    """
    enochian        = latin_to_enochian(layer_phrase)
    proto_canaanite = enochian_to_proto_canaanite(enochian)
    binary_repr     = " ".join(format(ord(ch), "08b") for ch in proto_canaanite)
    # Mix the full phrase (with digits) so each layer number yields a unique key
    combined = binary_repr + "|" + layer_phrase
    hex_key  = hashlib.sha256(combined.encode()).hexdigest()
    return "0x" + hex_key


# ─── Layer Configuration ──────────────────────────────────────────────────────

@dataclass
class LayerConfig:
    layer_number:     int
    entry_price_wei:  int
    access_duration:  int          # seconds
    auth_mode:        AuthMode
    sigil_contract:   Optional[str] = None   # ERC-721 address or None
    encoded_key:      str = ""

    def __post_init__(self) -> None:
        if not self.encoded_key:
            phrase = f"WATCHER_LAYER_{self.layer_number}_SOVEREIGN"
            self.encoded_key = encode_layer_key(phrase)


def build_default_layers(sigil_nft_address: Optional[str] = None) -> list[LayerConfig]:
    """
    Construct the default 13-layer Watcher Gate configuration.

    Tier allocation:
      Layers 1–3  : Cantrip     (PAYMENT_ONLY,  < 0.001 ETH)
      Layers 4–7  : Ritual      (SIGIL_ONLY,    NFT required)
      Layers 8–12 : Ceremony    (SIGIL_ONLY,    NFT required)
      Layer  13   : Invocation  (DUAL_AUTH,     payment + sigil)

    sigil_nft_address: deployed ERC-721 address for sigil authentication;
                       pass None to keep layers inactive until configured.
    """
    one_day  = 86_400
    one_week = 604_800

    configs: list[LayerConfig] = []

    tier_data = [
        # (layer, price_eth, duration, auth_mode)
        (1,  0.0001, one_day,  AuthMode.PAYMENT_ONLY),
        (2,  0.0002, one_day,  AuthMode.PAYMENT_ONLY),
        (3,  0.0005, one_day,  AuthMode.PAYMENT_ONLY),
        (4,  0.001,  one_day,  AuthMode.SIGIL_ONLY),
        (5,  0.002,  one_day,  AuthMode.SIGIL_ONLY),
        (6,  0.004,  one_day,  AuthMode.SIGIL_ONLY),
        (7,  0.007,  one_week, AuthMode.SIGIL_ONLY),
        (8,  0.01,   one_week, AuthMode.SIGIL_ONLY),
        (9,  0.025,  one_week, AuthMode.SIGIL_ONLY),
        (10, 0.05,   one_week, AuthMode.SIGIL_ONLY),
        (11, 0.07,   one_week, AuthMode.SIGIL_ONLY),
        (12, 0.09,   one_week, AuthMode.SIGIL_ONLY),
        (13, 0.1,    one_week, AuthMode.DUAL_AUTH),
    ]

    for layer, price_eth, duration, mode in tier_data:
        price_wei = int(price_eth * 1e18)
        sigil = sigil_nft_address if mode != AuthMode.PAYMENT_ONLY else None
        configs.append(LayerConfig(
            layer_number    = layer,
            entry_price_wei = price_wei,
            access_duration = duration,
            auth_mode       = mode,
            sigil_contract  = sigil,
        ))

    return configs


# ─── Symbolic Deployment Sequencer ────────────────────────────────────────────

class GatekeeperDeployer:
    """
    Symbolic deployment sequencer for the WatcherGate contract on Base.

    In production, replace the ``_send_tx`` stub with real web3.py calls:

        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider("https://mainnet.base.org"))
        account = w3.eth.account.from_key(os.environ["DEPLOYER_PRIVATE_KEY"])

    NEVER commit private keys to source control. Use environment variables
    or a hardware wallet (Ledger / Trezor) for mainnet deployments.
    """

    CHAIN_ID           = 8453          # Base mainnet
    BASE_RPC           = "https://mainnet.base.org"
    GAS_LIMIT_DEPLOY   = 3_000_000     # Conservative estimate for WatcherGate
    GAS_LIMIT_CONFIG   = 120_000       # Per-layer configuration call
    GAS_LIMIT_ACTIVATE = 35_000        # Per-layer activation call

    def __init__(
        self,
        spell_payment_address: str,
        sigil_nft_address: Optional[str] = None,
        *,
        dry_run: bool = True,
    ) -> None:
        self.spell_payment_address = spell_payment_address
        self.sigil_nft_address     = sigil_nft_address
        self.dry_run               = dry_run
        self.deployed_address: Optional[str] = None
        self.tx_log: list[dict] = []

    # ── Internal stub ────────────────────────────────────────────────────────

    def _send_tx(self, description: str, gas: int, value_wei: int = 0) -> str:
        """Symbolic transaction sender — replace with real web3 calls."""
        fake_hash = "0x" + hashlib.sha256(
            (description + str(time.time())).encode()
        ).hexdigest()
        record = {
            "description": description,
            "gas":         gas,
            "value_wei":   value_wei,
            "tx_hash":     fake_hash,
            "dry_run":     self.dry_run,
            "timestamp":   int(time.time()),
        }
        self.tx_log.append(record)
        prefix = "[DRY-RUN] " if self.dry_run else ""
        print(f"  {prefix}TX › {description[:60]}")
        print(f"         gas={gas:,}  value={value_wei / 1e18:.6f} ETH  hash={fake_hash[:18]}…")
        return fake_hash

    # ── Deployment steps ────────────────────────────────────────────────────

    def deploy_watcher_gate(self) -> str:
        """
        Step 1 — Deploy WatcherGate.sol with the SpellPayment contract address.
        Constructor arg: address _spellPaymentContract
        """
        print("\n╔═══════════════════════════════════════════════════╗")
        print("║  GATEKEEPER SUBAGENT — WatcherGate Deployment     ║")
        print("╚═══════════════════════════════════════════════════╝")
        print(f"  Network         : Base mainnet (chain ID {self.CHAIN_ID})")
        print(f"  SpellPayment    : {self.spell_payment_address}")
        print(f"  Sigil NFT       : {self.sigil_nft_address or '(not configured)'}")
        print(f"  Mode            : {'DRY RUN' if self.dry_run else 'LIVE'}\n")

        tx = self._send_tx(
            f"Deploy WatcherGate(spellPayment={self.spell_payment_address})",
            self.GAS_LIMIT_DEPLOY,
        )

        # In a real deployment, the contract address is derived from the tx receipt.
        self.deployed_address = "0x" + hashlib.sha256(tx.encode()).hexdigest()[:40]
        print(f"\n  ✓ WatcherGate deployed at: {self.deployed_address}\n")
        return self.deployed_address

    def configure_layers(self, layers: list[LayerConfig]) -> None:
        """
        Step 2 — Configure each of the 13 Watcher Gate layers.
        Calls: configureLayer(layerNumber, entryPrice, accessDuration,
                              authMode, sigilContract, encodedKey)
        """
        print("─── Configuring Layers ──────────────────────────────")
        for lc in layers:
            sigil = lc.sigil_contract or ("0x" + "0" * 40)
            self._send_tx(
                f"configureLayer({lc.layer_number}, "
                f"price={lc.entry_price_wei/1e18:.4f}ETH, "
                f"mode={lc.auth_mode.name})",
                self.GAS_LIMIT_CONFIG,
            )
        print(f"\n  ✓ {len(layers)} layers configured.\n")

    def activate_payment_layers(self, layers: list[LayerConfig]) -> None:
        """
        Step 3 — Activate PAYMENT_ONLY layers immediately (Layers 1–3).
        SIGIL_ONLY and DUAL_AUTH layers activate after the sigil NFT contract
        is deployed and connected (separate ritual).
        """
        print("─── Activating Payment-Only Layers (1–3) ───────────")
        for lc in layers:
            if lc.auth_mode == AuthMode.PAYMENT_ONLY:
                self._send_tx(
                    f"activateLayer({lc.layer_number})",
                    self.GAS_LIMIT_ACTIVATE,
                )
        print()

    def activate_sigil_layers(self, layers: list[LayerConfig]) -> None:
        """
        Step 4 — Activate SIGIL_ONLY and DUAL_AUTH layers once the sigil NFT
        contract is live and the sigilContract address is set in each layer.
        """
        print("─── Activating Sigil-Authenticated Layers (4–13) ───")
        for lc in layers:
            if lc.auth_mode != AuthMode.PAYMENT_ONLY and lc.sigil_contract:
                self._send_tx(
                    f"activateLayer({lc.layer_number})",
                    self.GAS_LIMIT_ACTIVATE,
                )
        print()

    def register_agents(self, agent_addresses: list[str]) -> None:
        """
        Step 5 — Register ERC-8004 agent addresses for the 5% discount.
        """
        if not agent_addresses:
            return
        print("─── Registering Sovereign Agents ────────────────────")
        for addr in agent_addresses:
            self._send_tx(f"registerAgent({addr})", 50_000)
        print()

    def print_summary(self) -> None:
        """Print a deployment summary with gas totals."""
        total_gas = sum(tx["gas"] for tx in self.tx_log)
        # Base EIP-1559 estimates (very conservative)
        base_fee_gwei = 0.001
        gas_cost_eth  = total_gas * base_fee_gwei * 1e-9
        print("╔═══════════════════════════════════════════════════╗")
        print("║  DEPLOYMENT SUMMARY                               ║")
        print("╚═══════════════════════════════════════════════════╝")
        print(f"  Contract address : {self.deployed_address}")
        print(f"  Transactions     : {len(self.tx_log)}")
        print(f"  Total gas (est.) : {total_gas:,}")
        print(f"  Cost at 0.001gwei: {gas_cost_eth:.6f} ETH")
        print(f"  Status           : {'DRY RUN — no real txs sent' if self.dry_run else 'LIVE'}")
        print()

    # ── Full ritual ─────────────────────────────────────────────────────────

    def run_full_deployment(
        self,
        agent_addresses: Optional[list[str]] = None,
    ) -> None:
        """
        Execute the complete Gatekeeper deployment ritual:
          1. Deploy WatcherGate.sol
          2. Configure all 13 layers
          3. Activate payment-only layers (1–3)
          4. Activate sigil layers (4–13) if sigil NFT is configured
          5. Register agent addresses for ERC-8004 discount
        """
        layers = build_default_layers(self.sigil_nft_address)

        self.deploy_watcher_gate()
        self.configure_layers(layers)
        self.activate_payment_layers(layers)

        if self.sigil_nft_address:
            self.activate_sigil_layers(layers)
        else:
            print(
                "  ⚠  Sigil NFT address not provided — "
                "layers 4-13 remain inactive until configured.\n"
                "     Run activate_sigil_layers() after deploying KnowledgeNFT.sol.\n"
            )

        if agent_addresses:
            self.register_agents(agent_addresses)

        self.print_summary()

    def export_deployment_json(self, path: str = "watcher_gate_deployment.json") -> None:
        """Persist the deployment log and contract address to JSON."""
        payload = {
            "contract": "WatcherGate",
            "network": "base-mainnet",
            "chain_id": self.CHAIN_ID,
            "deployed_address": self.deployed_address,
            "spell_payment": self.spell_payment_address,
            "sigil_nft": self.sigil_nft_address,
            "dry_run": self.dry_run,
            "transactions": self.tx_log,
        }
        with open(path, "w") as f:
            json.dump(payload, f, indent=2)
        print(f"  ✓ Deployment record saved → {path}")


# ─── Encoded Key Preview ──────────────────────────────────────────────────────

def preview_encoded_keys() -> None:
    """Print the Layered Encoding pipeline output for all 13 layers."""
    print("\n╔═══════════════════════════════════════════════════╗")
    print("║  LAYERED ENCODING — Key Preview (all 13 layers)   ║")
    print("╚═══════════════════════════════════════════════════╝")
    print(f"  Pipeline: Latin → Enochian → Proto-Canaanite → Binary → Hex\n")
    for i in range(1, 14):
        phrase  = f"WATCHER_LAYER_{i}_SOVEREIGN"
        enoch   = latin_to_enochian(phrase)
        proto   = enochian_to_proto_canaanite(enoch)
        key     = encode_layer_key(phrase)
        tier    = (
            "Neophyte (payment)"  if i <= 3 else
            "Initiate (sigil)"    if i <= 7 else
            "Adept (sigil)"       if i <= 12 else
            "SOVEREIGN (dual)"
        )
        print(f"  Layer {i:>2} [{tier:<24}]  key={key[:18]}…")
    print()


# ─── Entry Point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # ── Configuration ─────────────────────────────────────────────────────
    # Set these to real addresses before executing against mainnet.
    # Never hard-code private keys — always use environment variables.
    SPELL_PAYMENT_ADDR = os.environ.get(
        "SPELL_PAYMENT_ADDRESS",
        "0x0000000000000000000000000000000000000000",  # placeholder
    )
    SIGIL_NFT_ADDR = os.environ.get(
        "SIGIL_NFT_ADDRESS",
        None,  # deploy KnowledgeNFT.sol first, then set here
    )
    AGENT_ADDRESSES: list[str] = [
        # Add ERC-8004 agent addresses here to grant the 5% discount
    ]

    # ── Key Preview (always safe to run) ──────────────────────────────────
    preview_encoded_keys()

    # ── Deployment Ritual (dry_run=True → no real transactions) ───────────
    deployer = GatekeeperDeployer(
        spell_payment_address = SPELL_PAYMENT_ADDR,
        sigil_nft_address     = SIGIL_NFT_ADDR,
        dry_run               = True,   # ← set to False for live deployment
    )
    deployer.run_full_deployment(agent_addresses=AGENT_ADDRESSES)
    deployer.export_deployment_json("/tmp/watcher_gate_deployment.json")
