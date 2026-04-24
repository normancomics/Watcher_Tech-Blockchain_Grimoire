"""
Alignment Tools — planetary/celestial timing and intent-energy validation.

Planetary alignment is used as a "time-optimized execution window" metaphor:
real ephemeris data gates when the agent may trigger smart-contract actions,
mirroring the system described in docs/codex/expanded_portal_mechanics.md.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Optional

# ephem is an optional dependency; graceful degradation when absent
try:
    import ephem  # type: ignore
    _EPHEM_AVAILABLE = True
except ImportError:
    _EPHEM_AVAILABLE = False


# ---------------------------------------------------------------------------
# Intent / energy alignment
# ---------------------------------------------------------------------------

def assess_intent_energy(
    user_intent: str,
    biofeedback_score: float,
    threshold: float = 70.0,
) -> str:
    """
    Evaluate whether a user's stated intent and biofeedback score meet the
    constructive-energy threshold required to proceed with a ritual.

    Parameters
    ----------
    user_intent : str
        A short description of the user's purpose (e.g. "constructive research").
    biofeedback_score : float
        A 0–100 score representing intent resonance (from EEG / HRV sensor,
        or supplied manually).
    threshold : float
        Minimum biofeedback score required (default 70).

    Returns
    -------
    str
        JSON with ``aligned`` bool and reasoning.
    """
    constructive_keywords = {
        "constructive", "research", "educate", "explore", "study",
        "learn", "protect", "defend", "heal", "document", "archive",
    }
    intent_lower = user_intent.lower()
    has_constructive_keyword = any(kw in intent_lower for kw in constructive_keywords)
    score_ok = biofeedback_score >= threshold

    aligned = has_constructive_keyword and score_ok

    return json.dumps(
        {
            "aligned": aligned,
            "intent": user_intent,
            "biofeedback_score": biofeedback_score,
            "threshold": threshold,
            "keyword_match": has_constructive_keyword,
            "score_sufficient": score_ok,
            "message": (
                "Intent and energy aligned — proceed."
                if aligned
                else "Alignment insufficient — adjust intent or biofeedback."
            ),
        },
        indent=2,
    )


# ---------------------------------------------------------------------------
# Planetary / celestial alignment
# ---------------------------------------------------------------------------

def check_planetary_alignment(
    target_date: Optional[str] = None,
    require_new_moon: bool = False,
) -> str:
    """
    Check whether celestial conditions are favourable for ritual execution.

    Uses real ephemeris data (pyephem) when available; falls back to a
    deterministic time-window heuristic otherwise.

    Parameters
    ----------
    target_date : str, optional
        ISO-8601 date string (e.g. "2026-03-26").  Defaults to today UTC.
    require_new_moon : bool
        If True, also require moon phase < 0.1 (near-new-moon).

    Returns
    -------
    str
        JSON with ``aligned`` bool and ephemeris details.
    """
    if target_date:
        dt = datetime.fromisoformat(target_date).replace(tzinfo=timezone.utc)
    else:
        dt = datetime.now(timezone.utc)

    date_str = dt.strftime("%Y/%m/%d %H:%M:%S")

    if _EPHEM_AVAILABLE:
        sun = ephem.Sun(date_str)
        moon = ephem.Moon(date_str)
        sun_altitude = float(sun.alt)  # radians
        moon_phase = float(moon.phase)  # 0–100

        # Favourable: sun above horizon AND moon waxing/new (phase < 50)
        sun_ok = sun_altitude > 0
        moon_ok = (moon_phase < 25) if require_new_moon else (moon_phase < 50)
        aligned = sun_ok and moon_ok

        return json.dumps(
            {
                "aligned": aligned,
                "date": dt.isoformat(),
                "sun_altitude_rad": round(sun_altitude, 4),
                "moon_phase_pct": round(moon_phase, 2),
                "sun_above_horizon": sun_ok,
                "moon_phase_ok": moon_ok,
                "ephem_available": True,
            },
            indent=2,
        )
    else:
        # Heuristic fallback: use hour-of-day as a simple gate
        # "optimal window" = 06:00–18:00 UTC (sun active period)
        hour = dt.hour
        aligned = 6 <= hour < 18
        moon_phase_approx = _approx_moon_phase(dt)
        moon_ok = (moon_phase_approx < 0.1) if require_new_moon else True

        return json.dumps(
            {
                "aligned": aligned and moon_ok,
                "date": dt.isoformat(),
                "hour_utc": hour,
                "optimal_window": "06:00–18:00 UTC",
                "moon_phase_approx": round(moon_phase_approx, 3),
                "ephem_available": False,
                "note": "Install pyephem for precise ephemeris data.",
            },
            indent=2,
        )


# Synodic month length in days (mean value)
SYNODIC_MONTH_DAYS = 29.530588853


def _approx_moon_phase(dt: datetime) -> float:
    """
    Approximate moon phase (0.0 = new, 0.5 = full) using a 29.53-day cycle
    anchored to a known new-moon date (2000-01-06 UTC).
    """
    new_moon_epoch = datetime(2000, 1, 6, tzinfo=timezone.utc)
    elapsed = (dt - new_moon_epoch).total_seconds() / 86400
    phase = (elapsed % SYNODIC_MONTH_DAYS) / SYNODIC_MONTH_DAYS
    return phase


# ---------------------------------------------------------------------------
# Combined gate check
# ---------------------------------------------------------------------------

def ritual_gate_check(
    user_intent: str,
    biofeedback_score: float,
    target_date: Optional[str] = None,
) -> str:
    """
    Run the full pre-ritual gate: intent alignment + planetary alignment.

    Returns
    -------
    str
        JSON with ``all_clear`` bool plus sub-results for each gate.
    """
    intent_result = json.loads(assess_intent_energy(user_intent, biofeedback_score))
    planet_result = json.loads(check_planetary_alignment(target_date))

    all_clear = intent_result["aligned"] and planet_result["aligned"]

    return json.dumps(
        {
            "all_clear": all_clear,
            "intent_gate": intent_result,
            "planetary_gate": planet_result,
            "recommendation": (
                "All gates clear — safe to invoke smart contract."
                if all_clear
                else "One or more gates failed — ritual not yet sanctioned."
            ),
        },
        indent=2,
    )
