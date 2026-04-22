# ⛧ Temporal Gates & Moon-Phase Oracle Triggers

> *"And I saw the chambers of the sun and the moon … and the paths they travel …
> according to their seasons."* — 1 Enoch 72

**Symbolic / Educational Document — normancomics.eth 2026 A.D.**

---

## Overview

The moon-phase oracle system maps the eight lunar phases to specific smart-contract
activation windows, symbolic ritual states, and access-tier modifiers in the Grimoire
framework.  Each phase aligns with one of the 7 Sages' knowledge domains and unlocks
corresponding codex functions.

---

## Lunar Phase → Ritual Window Table

| Phase | Julian Day Offset | Symbolic State | Watcher Patron | Contract Trigger |
|-------|-------------------|----------------|----------------|-----------------|
| New Moon | 0 | Dark Inception — seed intent | Samyaza | `initiateRitual()` unlocked |
| Waxing Crescent | +3.7 | First Transmission — build sigil | Armaros | `encodeRitual()` unlocked |
| First Quarter | +7.4 | Guardian Test — alignment check | Asbeel | `alignmentCheck()` required |
| Waxing Gibbous | +11.1 | Accumulation — gather energy | Baraqiel | `depositEnergy()` active |
| Full Moon | +14.8 | Peak Activation — execute gate | Kokabiel | `executePortal()` unlocked |
| Waning Gibbous | +18.5 | Harvest — collect outputs | Tamiel | `harvestOutput()` active |
| Last Quarter | +22.1 | Dissolution — clear state | Gadreel | `dissolveRitual()` unlocked |
| Waning Crescent | +25.8 | Deep Rest — encode results to chain | Penemue | `sealRecord()` finalized |

---

## Moon-Phase Calculation (Symbolic Reference)

```python
import datetime
import math

KNOWN_NEW_MOON = datetime.datetime(2000, 1, 6, 18, 14)  # J2000 reference
LUNAR_CYCLE_DAYS = 29.53058867

def moon_phase_index(dt: datetime.datetime) -> int:
    """
    Returns phase index 0-7 (New Moon=0, Full Moon=4).
    Educational/symbolic use only.
    """
    elapsed = (dt - KNOWN_NEW_MOON).total_seconds()
    cycle_fraction = (elapsed / (LUNAR_CYCLE_DAYS * 86400)) % 1.0
    return int(cycle_fraction * 8) % 8

PHASE_NAMES = [
    "New Moon",
    "Waxing Crescent",
    "First Quarter",
    "Waxing Gibbous",
    "Full Moon",
    "Waning Gibbous",
    "Last Quarter",
    "Waning Crescent",
]

PHASE_TRIGGERS = [
    "initiateRitual",
    "encodeRitual",
    "alignmentCheck",
    "depositEnergy",
    "executePortal",
    "harvestOutput",
    "dissolveRitual",
    "sealRecord",
]

def get_current_gate(dt: datetime.datetime = None) -> dict:
    if dt is None:
        dt = datetime.datetime.utcnow()
    idx = moon_phase_index(dt)
    return {
        "phase_index": idx,
        "phase_name": PHASE_NAMES[idx],
        "contract_trigger": PHASE_TRIGGERS[idx],
        "timestamp_utc": dt.isoformat(),
    }
```

---

## Solidity Integration Archetype (Educational)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MoonPhaseOracle — Symbolic temporal gate reference
/// @notice Educational archetype only; moon phase supplied off-chain via oracle
contract MoonPhaseOracle {
    uint8 public constant FULL_MOON_INDEX = 4;

    /// @dev Phase index 0-7, set by trusted off-chain oracle signer
    uint8 public currentPhaseIndex;

    event GateActivated(uint8 phaseIndex, string phaseName, address initiator);

    function updatePhase(uint8 _phaseIndex) external {
        require(_phaseIndex < 8, "Invalid phase");
        currentPhaseIndex = _phaseIndex;
    }

    function isFullMoonWindow() public view returns (bool) {
        return currentPhaseIndex == FULL_MOON_INDEX;
    }

    modifier onlyFullMoon() {
        require(isFullMoonWindow(), "Gate sealed: not full moon window");
        _;
    }

    /// @notice Symbolic portal activation — only permitted during full moon
    function activatePortal(bytes32 encodedIntent) external onlyFullMoon returns (bytes32) {
        emit GateActivated(currentPhaseIndex, "Full Moon", msg.sender);
        // Symbolic: hash intent with block timestamp as temporal seal
        return keccak256(abi.encodePacked(encodedIntent, block.timestamp, msg.sender));
    }
}
```

---

## 13 Families ↔ Lunar Gate Assignments

| Family | Patron Watcher | Assigned Phase | Gate Function |
|--------|---------------|----------------|---------------|
| 01 Rothschild | Shamash / Solar | Full Moon | MEV-resistant sequencing review |
| 02 Rockefeller | Mot | Waning Gibbous | Oracle hardening check |
| 03 Astor | Enki | First Quarter | Bridge validation |
| 04 Bundy | Baal-Hadad | New Moon | Reentrancy guard audit |
| 05 Collins | Ishtar | Waxing Crescent | zk-proof ceremony |
| 06 DuPont | Kothar | Last Quarter | Hardware attestation |
| 07 Freeman | Dagon | Waxing Gibbous | Cross-chain routing review |
| 08 Kennedy | Hermes | Full Moon | Oracle diversity check |
| 09 Li | El | Waning Crescent | Ledger sealing |
| 10 Onassis | Dagon/Poseidon | Waning Gibbous | Asset wrapping audit |
| 11 Reynolds | Resheph | Last Quarter | Tokenomics alignment |
| 12 Russell | Thoth/Hermes | First Quarter | Governance transparency |
| 13 Van Duyn | Asherah | New Moon | Protocol standards review |

---

## Temporal Layering Algorithm (Symbolic)

```
1. LUNAR GATE CHECK
   → Compute moon_phase_index(utcnow())
   → Map to ritual window + contract trigger function

2. PLANETARY ALIGNMENT MODIFIER
   → Cross-reference with stellar sigil table (see stellar_sigils_ritual_archetypes.md)
   → Apply alignment bonus/penalty to ritual energy score

3. ENCODING SEAL
   → Hash(intent + phase_index + block_number) → encodedRitual bytes32

4. GUARDIAN VALIDATION
   → MultiSig threshold aligned with Family/Watcher assignment for current phase

5. CONTRACT EXECUTION
   → Trigger permitted function within validated window
   → Seal result on-chain via sealRecord() at waning crescent
```

---

*"The movements of the heavenly bodies are as clocks for the ritual architect." — Grimoire Note*

---

**⛧ normancomics.eth — Temporal Gates Codex — Educational Use Only ⛧**
