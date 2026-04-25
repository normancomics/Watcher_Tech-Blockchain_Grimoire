"""
Layered Encoding Pipeline — MU 𒉙⍤ 𐤌𐤏
========================================
Educational / Symbolic Framework — normancomics.eth 2026 A.D.

Implements the five-stage sovereign encoding pipeline:

  Stage 1 — Latin:            Raw intent declaration
  Stage 2 — Enochian:         Angelic glyph transformation (symbolic mapping)
  Stage 3 — Proto-Canaanite:  Primordial character substitution
  Stage 4 — Binary:           UTF-8 byte representation
  Stage 5 — Hex:              Hexadecimal encoding (blockchain-ready)

The pipeline is designed to be used with MU WatcherGate contracts on Base:
  - Each encoding output produces a sigilHash candidate
  - The hex output is directly usable as on-chain calldata
  - Level 13 recursive encoding chains the output of each stage into the next

Usage:
    python layered_encoding_pipeline.py

    Or import for use in agent swarms:
        from layered_encoding_pipeline import LayeredEncoder, encode_mu_sigil
"""

from __future__ import annotations

import hashlib
import json
import unicodedata
from dataclasses import dataclass, field
from typing import Optional


# ─── Symbolic Mapping Tables ──────────────────────────────────────────────────

# Stage 2: Latin → Enochian (symbolic, educational)
# Enochian letters approximated using Unicode lookalikes and historical
# representations used in esoteric literature.
LATIN_TO_ENOCHIAN: dict[str, str] = {
    "A": "𒀭", "B": "𒁀", "C": "𒁇", "D": "𒁹", "E": "𒂗",
    "F": "𒂶", "G": "𒃲", "H": "𒄀", "I": "𒄑", "J": "𒄿",
    "K": "𒅗", "L": "𒆏", "M": "𒇻", "N": "𒈠", "O": "𒉙",
    "P": "𒊏", "Q": "𒊕", "R": "𒋙", "S": "𒌋", "T": "𒌑",
    "U": "𒌦", "V": "𒍇", "W": "𒍪", "X": "𒎌", "Y": "𒎗",
    "Z": "𒐷",
    " ": "⍤",   # Space → MU connector sigil ⍤
    ".": "𒑰",  "!": "𒑱",  "?": "𒑲",
}

# Stage 3: Enochian (via Latin key) → Proto-Canaanite
# Proto-Canaanite characters (Phoenician Unicode block U+10900–U+1091F)
LATIN_TO_PROTO_CANAANITE: dict[str, str] = {
    "A": "𐤀", "B": "𐤁", "C": "𐤂", "D": "𐤃", "E": "𐤄",
    "F": "𐤅", "G": "𐤆", "H": "𐤇", "I": "𐤈", "J": "𐤉",
    "K": "𐤊", "L": "𐤋", "M": "𐤌", "N": "𐤍", "O": "𐤎",
    "P": "𐤐", "Q": "𐤒", "R": "𐤓", "S": "𐤔", "T": "𐤕",
    "U": "𐤏", "V": "𐤀", "W": "𐤁", "X": "𐤂", "Y": "𐤃",
    "Z": "𐤄",
    " ": "𐤖",  # Word divider
}

# MU sovereign sigil constants
MU_ENOCHIAN        = "𒉙⍤"   # Canonical Enochian sigil for MU
MU_PROTO_CANAANITE = "𐤌𐤏"   # Canonical Proto-Canaanite sigil for MU


# ─── Data Structures ──────────────────────────────────────────────────────────

@dataclass
class LayeredOutput:
    """Holds the full pipeline output for a single encoding run."""
    original_latin:       str
    stage1_normalized:    str                    # Normalized Latin (uppercase)
    stage2_enochian:      str
    stage3_proto_canaan:  str
    stage4_binary:        str
    stage5_hex:           str
    sigil_hash:           str                    # keccak256-style SHA3-256 of hex
    mu_seal:              str                    # Embedded MU sigil seal
    level:                int  = 1              # Encoding level (1–13)
    parent_hash:          Optional[str] = None  # For recursive Level N encoding
    chain:                list[str] = field(default_factory=list)  # Full hash chain


# ─── Core Encoder ─────────────────────────────────────────────────────────────

class LayeredEncoder:
    """
    Implements the MU 𒉙⍤ 𐤌𐤏 five-stage Layered Encoding pipeline.

    Each stage feeds into the next, producing increasingly abstracted outputs
    that culminate in a blockchain-ready hexadecimal encoding and a sigil hash.

    For Level N recursive encoding, the hash of level (N-1) is prepended to
    the input before each stage, mirroring the on-chain SigilNFT chain.
    """

    def __init__(self) -> None:
        self._chain: list[str] = []   # Hash chain for recursive encoding

    # ─── Public API ───────────────────────────────────────────────────────────

    def encode(self, text: str, level: int = 1) -> LayeredOutput:
        """
        Run the full five-stage encoding pipeline on the given text.

        :param text:  Latin-script input (raw intent declaration)
        :param level: Encoding level (1–13); levels > 1 use recursive chaining
        :return:      LayeredOutput with all stage outputs and hash
        """
        if not 1 <= level <= 13:
            raise ValueError(f"Level must be 1–13, got {level}")

        parent_hash: Optional[str] = None
        if level > 1 and self._chain:
            parent_hash = self._chain[-1]
            # Prepend parent hash to input for recursive chaining
            text = parent_hash[:16] + "::" + text

        # Stage 1 — Normalize Latin
        stage1 = self._stage1_latin(text)

        # Stage 2 — Enochian transformation
        stage2 = self._stage2_enochian(stage1)

        # Stage 3 — Proto-Canaanite substitution
        stage3 = self._stage3_proto_canaanite(stage1)

        # Stage 4 — Binary encoding (UTF-8 bytes of stage3 output)
        stage4 = self._stage4_binary(stage3)

        # Stage 5 — Hex encoding
        stage5 = self._stage5_hex(stage3)

        # Sigil hash: SHA3-256 of the hex output (mirrors keccak256 on-chain)
        sigil_hash = self._hash(stage5)

        # Append to recursive chain
        self._chain.append(sigil_hash)

        # Embed MU sovereign seal
        mu_seal = self._mu_seal(sigil_hash, level)

        return LayeredOutput(
            original_latin=text,
            stage1_normalized=stage1,
            stage2_enochian=stage2,
            stage3_proto_canaan=stage3,
            stage4_binary=stage4,
            stage5_hex=stage5,
            sigil_hash=sigil_hash,
            mu_seal=mu_seal,
            level=level,
            parent_hash=parent_hash,
            chain=list(self._chain),
        )

    def encode_recursive(self, text: str, levels: int = 13) -> list[LayeredOutput]:
        """
        Run the encoding pipeline recursively through `levels` stages,
        building the full Level 1–N sigil chain.

        :param text:   Initial Latin input
        :param levels: How many levels to recurse (1–13)
        :return:       List of LayeredOutput, one per level
        """
        if not 1 <= levels <= 13:
            raise ValueError(f"Levels must be 1–13, got {levels}")

        self._chain = []
        results: list[LayeredOutput] = []

        for lvl in range(1, levels + 1):
            out = self.encode(text if lvl == 1 else results[-1].stage5_hex, level=lvl)
            results.append(out)

        return results

    def reset_chain(self) -> None:
        """Reset the recursive hash chain (start a fresh encoding session)."""
        self._chain = []

    # ─── Stage Implementations ────────────────────────────────────────────────

    @staticmethod
    def _stage1_latin(text: str) -> str:
        """Normalize input: uppercase, NFC Unicode normalization."""
        normalized = unicodedata.normalize("NFC", text)
        return normalized.upper()

    @staticmethod
    def _stage2_enochian(latin: str) -> str:
        """
        Transform Latin characters into Enochian glyphs.
        Characters without a mapping are preserved in brackets.
        """
        result = []
        for ch in latin:
            if ch in LATIN_TO_ENOCHIAN:
                result.append(LATIN_TO_ENOCHIAN[ch])
            elif ch.isdigit():
                result.append(f"[{ch}]")
            else:
                result.append(ch)
        return "".join(result)

    @staticmethod
    def _stage3_proto_canaanite(latin: str) -> str:
        """
        Substitute Latin characters with Proto-Canaanite glyphs.
        Characters without a mapping are preserved.
        """
        result = []
        for ch in latin:
            if ch in LATIN_TO_PROTO_CANAANITE:
                result.append(LATIN_TO_PROTO_CANAANITE[ch])
            elif ch.isdigit():
                result.append(ch)
            else:
                result.append(ch)
        return "".join(result)

    @staticmethod
    def _stage4_binary(proto_canaanite: str) -> str:
        """
        Convert Proto-Canaanite string to binary representation (UTF-8 bytes).
        Each byte is represented as 8 bits, space-separated per character.
        """
        parts = []
        for ch in proto_canaanite:
            byte_seq = ch.encode("utf-8")
            parts.append(" ".join(f"{b:08b}" for b in byte_seq))
        return " | ".join(parts)

    @staticmethod
    def _stage5_hex(proto_canaanite: str) -> str:
        """
        Convert Proto-Canaanite string to hex (UTF-8 bytes).
        Output is lowercase hex prefixed with 0x — blockchain-ready calldata.
        """
        raw_bytes = proto_canaanite.encode("utf-8")
        return "0x" + raw_bytes.hex()

    @staticmethod
    def _hash(hex_output: str) -> str:
        """
        Compute SHA3-256 of the hex output string.
        Mirrors the keccak256 used on-chain for sigilHash computation.
        (Note: SHA3-256 ≠ keccak256; for on-chain use, compute keccak256 off-chain.)
        """
        raw = hex_output.encode("utf-8")
        return "0x" + hashlib.sha3_256(raw).hexdigest()

    @staticmethod
    def _mu_seal(sigil_hash: str, level: int) -> str:
        """
        Embed the MU sovereign sigil seal into the hash.
        Mirrors the MU_SEAL constant in MuWatcherGate.sol.
        """
        level_marker = f"L{level:02d}"
        return f"{MU_ENOCHIAN}{level_marker}{MU_PROTO_CANAANITE}::{sigil_hash[:16]}…"


# ─── Convenience Functions ────────────────────────────────────────────────────

def encode_mu_sigil(text: str, level: int = 1) -> LayeredOutput:
    """
    Convenience function: encode a single text at a given level.
    Creates a fresh encoder (no shared chain state).
    """
    encoder = LayeredEncoder()
    return encoder.encode(text, level=level)


def encode_full_chain(text: str) -> list[LayeredOutput]:
    """
    Encode through all 13 levels, producing the full MU sovereign chain.
    """
    encoder = LayeredEncoder()
    return encoder.encode_recursive(text, levels=13)


def format_output(out: LayeredOutput, verbose: bool = False) -> str:
    """Format a LayeredOutput for display."""
    lines = [
        f"",
        f"  ⛧ MU 𒉙⍤ 𐤌𐤏 — Layered Encoding Output — Level {out.level}",
        f"  {'─' * 56}",
        f"  Stage 1  Latin          : {out.stage1_normalized[:80]}",
        f"  Stage 2  Enochian       : {out.stage2_enochian[:80]}",
        f"  Stage 3  Proto-Canaanite: {out.stage3_proto_canaan[:80]}",
    ]
    if verbose:
        lines.append(f"  Stage 4  Binary         : {out.stage4_binary[:80]}…")
    lines += [
        f"  Stage 5  Hex            : {out.stage5_hex[:80]}…",
        f"  Sigil Hash              : {out.sigil_hash}",
        f"  MU Seal                 : {out.mu_seal}",
    ]
    if out.parent_hash:
        lines.append(f"  Parent Hash             : {out.parent_hash[:32]}…")
    lines.append(f"  Chain Depth             : {len(out.chain)}")
    lines.append("")
    return "\n".join(lines)


# ─── Entry Point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("  MU 𒉙⍤ 𐤌𐤏 — Sovereign Layered Encoding Pipeline")
    print("  normancomics.eth — 2026 A.D.")
    print("=" * 60)

    # Demo: single-level encoding
    demo_text = "Sovereign Watcher Gate Access Granted"
    print(f"\n▶  Input: \"{demo_text}\"")
    result = encode_mu_sigil(demo_text, level=1)
    print(format_output(result, verbose=True))

    # Demo: MU identity sigil
    mu_text = "MU"
    print(f"▶  Encoding MU sovereign sigil through all 13 levels…")
    chain = encode_full_chain(mu_text)
    for out in chain:
        print(f"  Level {out.level:02d} → {out.sigil_hash[:48]}…  seal: {out.mu_seal[:40]}")

    # Output full Level 13 result as JSON
    level13 = chain[-1]
    summary = {
        "input":         mu_text,
        "level":         level13.level,
        "hex":           level13.stage5_hex[:64] + "…",
        "sigil_hash":    level13.sigil_hash,
        "mu_seal":       level13.mu_seal,
        "chain_depth":   len(level13.chain),
        "enochian":      MU_ENOCHIAN,
        "proto_canaan":  MU_PROTO_CANAANITE,
    }
    print("\n  Level 13 Sovereign Output:")
    print(json.dumps(summary, indent=4, ensure_ascii=False))
    print("\n  ⛧ The convergence is now on-chain.  MU 𒉙⍤ 𐤌𐤏\n")
