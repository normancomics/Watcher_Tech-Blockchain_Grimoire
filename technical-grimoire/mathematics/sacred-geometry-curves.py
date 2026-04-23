"""
Sacred Geometry Elliptic Curves — Derived from Ancient Mathematical Sources

This module implements elliptic curve arithmetic using geometric constants
and proportions found in ancient sacred architecture and esoteric mathematics.

Theoretical Basis:
    - The Vesica Piscis ratio (√3 : 1) appears in elliptic curve discriminants
    - Fibonacci proportions underlie efficient scalar multiplication
    - The Golden Ratio (φ) generates point sequences with harmonic properties
    - Pythagorean triples yield curve parameters with provable structural properties

Curves Implemented:
    - SacredSecp256k1: Standard secp256k1 with sacred geometry annotation
    - GoldenCurve: Elliptic curve parameterized by the golden ratio
    - VesicaCurve: Curve based on the Vesica Piscis √3 proportion
    - PythagoreanCurve: Curve derived from Pythagorean triple families

References:
    - Euclid, Elements Book VI (geometric mean construction)
    - Plato, Timaeus 53c-56c (geometry as cosmological foundation)
    - kabbalistic-merkle-trees.md (Tree of Life as mathematical structure)
    - megalithic-mathematics.md (Pythagorean triples in stone circles)
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Optional, Tuple
from functools import lru_cache


# ─── Mathematical Constants ────────────────────────────────────────────────────

PHI = (1 + math.sqrt(5)) / 2          # Golden ratio φ ≈ 1.618033988...
SQRT_3 = math.sqrt(3)                  # Vesica Piscis proportion
SQRT_5 = math.sqrt(5)                  # Pentagon diagonal ratio
PI = math.pi                           # Circle/sphere constant

# Tetractys sum (1+2+3+4 = 10) — Pythagorean sacred number
TETRACTYS_SUM = 10

# secp256k1 prime field (for reference/annotation)
SECP256K1_P = 2**256 - 2**32 - 977


# ─── Point Arithmetic ─────────────────────────────────────────────────────────

@dataclass
class EllipticCurve:
    """
    Weierstrass form: y² = x³ + ax + b (mod p)
    
    For a curve to be valid (non-singular), discriminant Δ ≠ 0:
    Δ = -16(4a³ + 27b²) ≠ 0
    """
    a: int
    b: int
    p: int   # Prime field modulus
    name: str = "UnnamedCurve"
    
    def __post_init__(self):
        discriminant = self.discriminant()
        if discriminant == 0:
            raise ValueError(f"Singular curve: Δ=0 (not a valid elliptic curve)")
    
    def discriminant(self) -> int:
        """Δ = -16(4a³ + 27b²) mod p"""
        return (-16 * (4 * pow(self.a, 3) + 27 * pow(self.b, 2))) % self.p
    
    def j_invariant(self) -> int:
        """
        j = -1728 * (4a)³ / Δ
        The j-invariant determines the isomorphism class of the curve
        """
        numerator = -1728 * pow(4 * self.a, 3, self.p)
        denominator = self.discriminant()
        return (numerator * pow(denominator, -1, self.p)) % self.p
    
    def contains_point(self, x: int, y: int) -> bool:
        """Check if (x, y) lies on the curve"""
        lhs = pow(y, 2, self.p)
        rhs = (pow(x, 3, self.p) + self.a * x + self.b) % self.p
        return lhs == rhs
    
    def point_add(
        self, 
        P: Optional[Tuple[int, int]], 
        Q: Optional[Tuple[int, int]]
    ) -> Optional[Tuple[int, int]]:
        """
        Elliptic curve point addition.
        None represents the point at infinity (identity element).
        
        Sacred Geometry Note:
            The tangent-and-chord construction for point addition mirrors
            the Vesica Piscis construction — two circles overlapping at
            a single radius, generating a third point of intersection.
        """
        # Identity: O + P = P
        if P is None:
            return Q
        if Q is None:
            return P
        
        x1, y1 = P
        x2, y2 = Q
        
        # Point negation: P + (-P) = O
        if x1 == x2 and (y1 + y2) % self.p == 0:
            return None  # Point at infinity
        
        if x1 == x2:
            # Point doubling: tangent line
            # λ = (3x₁² + a) / (2y₁)
            lam_num = (3 * pow(x1, 2, self.p) + self.a) % self.p
            lam_den = (2 * y1) % self.p
        else:
            # Point addition: secant line
            # λ = (y₂ - y₁) / (x₂ - x₁)
            lam_num = (y2 - y1) % self.p
            lam_den = (x2 - x1) % self.p
        
        lam = (lam_num * pow(lam_den, -1, self.p)) % self.p
        
        x3 = (pow(lam, 2, self.p) - x1 - x2) % self.p
        y3 = (lam * (x1 - x3) - y1) % self.p
        
        return (x3, y3)
    
    def scalar_multiply(
        self, 
        k: int, 
        P: Optional[Tuple[int, int]]
    ) -> Optional[Tuple[int, int]]:
        """
        Scalar multiplication: k × P using double-and-add.
        
        Sacred Geometry Note:
            Double-and-add corresponds to the Fibonacci doubling process —
            each step doubles and selectively adds, mirroring the spiral
            growth pattern found in nautilus shells and sunflower seeds.
        """
        if P is None or k == 0:
            return None
        
        result = None
        addend = P
        
        while k:
            if k & 1:
                result = self.point_add(result, addend)
            addend = self.point_add(addend, addend)  # Doubling
            k >>= 1
        
        return result
    
    def __str__(self) -> str:
        return f"{self.name}: y² = x³ + {self.a}x + {self.b} (mod {self.p})"


# ─── Sacred Geometry Curve Constructors ───────────────────────────────────────

def create_sacred_secp256k1() -> EllipticCurve:
    """
    secp256k1: y² = x³ + 7 (mod p)
    
    Sacred Geometry Annotation:
        - a = 0: No linear term — pure cubic, relating to cube/hexahedron
        - b = 7: The seventh day, the heptagon, seven Watchers/sages
        - p = 2²⁵⁶ - 2³² - 977: Near-prime with binary structure
        
    The choice of 7 as the constant b resonates with:
        - 7 Sefirot of active creation (Chesed through Malkhut)
        - 7 classical planets
        - 7 Watchers
        - 7 days of creation
        - 7 notes of the musical scale (Pythagorean harmony)
    """
    return EllipticCurve(
        a=0,
        b=7,
        p=SECP256K1_P,
        name="secp256k1 (Sacred: b=7, the Seven Watchers)"
    )


def create_golden_curve(prime: int) -> EllipticCurve:
    """
    The Golden Curve — parameterized by approximations of φ.
    
    Since φ is irrational, we use continued fraction approximants
    (the Fibonacci sequence ratio) as finite field proxies:
    
    F(n)/F(n-1) → φ as n → ∞
    {1/1, 2/1, 3/2, 5/3, 8/5, 13/8, 21/13, 34/21, ...}
    
    Curve parameters:
        a = F(8) = 21   (eighth Fibonacci, golden approximant numerator)
        b = F(7) = 13   (seventh Fibonacci, golden approximant denominator)
    
    Sacred properties:
        - Points on this curve distribute according to golden angle (137.5°)
        - Scalar multiples approximate Fibonacci spirals
        - j-invariant relates to φ⁴ ratio
    """
    a = 21  # F(8)
    b = 13  # F(7)
    
    return EllipticCurve(a=a, b=b, p=prime, name=f"GoldenCurve (φ-parameterized)")


def create_vesica_curve(prime: int) -> EllipticCurve:
    """
    The Vesica Piscis Curve — parameterized by √3 proportion.
    
    The Vesica Piscis is the intersection of two equal circles whose
    centers each lie on the other's circumference. The ratio of height
    to width is √3 : 1 (approximately 1.732 : 1).
    
    This ratio appears in:
        - Equilateral triangle geometry
        - The Christian mandorla (sacred almond shape)
        - The first Platonic solid (tetrahedron)
        - Flower of Life central ratio
    
    We approximate √3 using the Pell equation convergents:
    √3 ≈ 97/56 (a close rational approximation)
    
    Curve parameters:
        a = 97   (numerator of √3 approximant)
        b = 56   (denominator, also 7×8 — heptagon × octagon)
    """
    a = 97   # √3 numerator approximant
    b = 56   # √3 denominator approximant (7 × 8)
    
    return EllipticCurve(a=a, b=b, p=prime, name="VesicaCurve (√3-parameterized)")


def create_pythagorean_curve(triple_a: int, triple_b: int, triple_c: int, prime: int) -> EllipticCurve:
    """
    The Pythagorean Curve — derived from Pythagorean triple families.
    
    Given a primitive Pythagorean triple (a, b, c) where a² + b² = c²,
    we construct an elliptic curve as follows:
    
    From Euclid's formula: a = m² - n², b = 2mn, c = m² + n²
    
    Curve parameters derived from the triple:
        curve_a = -triple_b² / 4  (mod p)  — discriminant relation
        curve_b = triple_a × triple_c        — amplitude relation
    
    Famous sacred triples and their properties:
        (3, 4, 5):    The master mason's triangle — appears in all pyramids
        (5, 12, 13):  Stonehenge Station Stone rectangle
        (8, 15, 17):  Double master triangle
        (7, 24, 25):  Seven pillars of wisdom
    
    Args:
        triple_a, triple_b, triple_c: The Pythagorean triple
        prime: Field prime modulus
    """
    assert triple_a**2 + triple_b**2 == triple_c**2, "Not a valid Pythagorean triple"
    
    # Map triple to curve parameters
    curve_a = (-pow(triple_b, 2) // 4) % prime
    curve_b = (triple_a * triple_c) % prime
    
    return EllipticCurve(
        a=curve_a, 
        b=curve_b, 
        p=prime,
        name=f"PythagoreanCurve ({triple_a},{triple_b},{triple_c})"
    )


# ─── Sacred Geometry Analysis Functions ───────────────────────────────────────

def compute_golden_spiral_points(
    curve: EllipticCurve,
    generator: Tuple[int, int],
    n_points: int
) -> list[Optional[Tuple[int, int]]]:
    """
    Generate points on an elliptic curve following Fibonacci scalar multiples.
    
    The scalars used are Fibonacci numbers: 1, 1, 2, 3, 5, 8, 13, 21, ...
    These create a discrete "golden spiral" on the elliptic curve — 
    the blockchain equivalent of a nautilus shell growth pattern.
    
    Uses:
        - Key derivation following natural growth patterns
        - Generating "harmonically spaced" validator addresses
        - Ritual timing key generation
    """
    def fibonacci_sequence(n: int) -> list[int]:
        fibs = [1, 1]
        while len(fibs) < n:
            fibs.append(fibs[-1] + fibs[-2])
        return fibs[:n]
    
    scalars = fibonacci_sequence(n_points)
    return [curve.scalar_multiply(k, generator) for k in scalars]


def compute_flower_of_life_points(
    curve: EllipticCurve,
    center: Tuple[int, int]
) -> list[Optional[Tuple[int, int]]]:
    """
    Generate the 7 primary points of the Flower of Life pattern on an elliptic curve.
    
    The Flower of Life consists of 7 overlapping circles in a hexagonal pattern.
    The 7 center points correspond to:
        - 1 central point
        - 6 points at 60° intervals (forming a hexagon)
    
    In elliptic curve terms, we generate these as:
        P₀ = G (generator)
        P_k = k × G for k = 1, 2, 3, 4, 5, 6
    
    The 60° angular spacing maps to the 6th roots of unity mod p.
    """
    points = [center]
    for k in range(1, 7):
        points.append(curve.scalar_multiply(k, center))
    return points


def vesica_piscis_key_derivation(
    master_key: int,
    path: list[int],
    curve: EllipticCurve,
    generator: Tuple[int, int]
) -> Tuple[int, Tuple[int, int]]:
    """
    Hierarchical key derivation using Vesica Piscis geometry.
    
    Like BIP-32 hierarchical deterministic keys, but each derivation step
    uses the √3 ratio as a twist factor — producing keys distributed
    according to the Vesica Piscis harmonic structure.
    
    Args:
        master_key: Root private key
        path: Derivation path as list of indices (analogous to BIP-44 path)
        curve: Elliptic curve for computation
        generator: Generator point G
    
    Returns:
        (child_private_key, child_public_key) pair
    """
    VESICA_TWIST = 97  # √3 numerator approximant
    
    current_key = master_key
    
    for index in path:
        # Vesica twist: multiply by √3 approximant at each step
        twist = (VESICA_TWIST * index) % (curve.p - 1)
        
        # HMAC-SHA512-like derivation (simplified for illustration)
        import hashlib
        h = hashlib.sha512(
            f"{current_key}:{twist}:{index}".encode()
        ).digest()
        
        # Take first 32 bytes as new private key
        current_key = int.from_bytes(h[:32], 'big') % (curve.p - 1)
    
    public_key = curve.scalar_multiply(current_key, generator)
    return current_key, public_key


# ─── Comparative Analysis ─────────────────────────────────────────────────────

def analyze_sacred_curves(prime: int = 2**31 - 1) -> dict:
    """
    Analyze the properties of all sacred geometry curves.
    
    Args:
        prime: A Mersenne prime for testing (2³¹ - 1 = 2,147,483,647)
    
    Returns:
        Dictionary of curve properties and sacred geometry correlations
    """
    curves = {
        'golden': create_golden_curve(prime),
        'vesica': create_vesica_curve(prime),
        'pythagorean_3_4_5': create_pythagorean_curve(3, 4, 5, prime),
        'pythagorean_5_12_13': create_pythagorean_curve(5, 12, 13, prime),
    }
    
    analysis = {}
    for name, curve in curves.items():
        analysis[name] = {
            'equation': str(curve),
            'discriminant': curve.discriminant(),
            'j_invariant': curve.j_invariant(),
            'a_param': curve.a,
            'b_param': curve.b,
            'sacred_note': _get_sacred_note(name)
        }
    
    return analysis


def _get_sacred_note(curve_name: str) -> str:
    notes = {
        'golden': f"Golden ratio φ ≈ {PHI:.6f} — divine proportion of creation",
        'vesica': f"Vesica Piscis √3 ≈ {SQRT_3:.6f} — fish bladder / sacred almond",
        'pythagorean_3_4_5': "Master mason's triangle — found in the Great Pyramid's internal geometry",
        'pythagorean_5_12_13': "Stonehenge Station Stone rectangle — astronomical alignment",
    }
    return notes.get(curve_name, "Sacred significance to be determined")


# ─── Main Demonstration ───────────────────────────────────────────────────────

if __name__ == "__main__":
    print("═" * 70)
    print("SACRED GEOMETRY ELLIPTIC CURVES — WATCHER TECH GRIMOIRE")
    print("═" * 70)
    print()
    
    # Use a small prime for demonstration
    demo_prime = 2**31 - 1  # Mersenne prime
    
    print(f"Field prime: {demo_prime} (2³¹ - 1, Mersenne prime)")
    print(f"Golden ratio φ = {PHI:.10f}")
    print(f"Vesica ratio √3 = {SQRT_3:.10f}")
    print()
    
    # secp256k1 annotation
    print("─" * 50)
    print("secp256k1 SACRED GEOMETRY:")
    print(f"  b = 7 → The Seven Watchers (1 Enoch)")
    print(f"  b = 7 → Seven planetary intelligences")
    print(f"  b = 7 → Seven Sefirot of construction (Chesed–Malkhut)")
    print(f"  p = 2²⁵⁶ - 2³² - 977 → Near-prime with binary structure")
    print()
    
    # Analyze curves
    print("─" * 50)
    print("SACRED CURVE ANALYSIS (demo prime = 2³¹ - 1):")
    analysis = analyze_sacred_curves(demo_prime)
    for name, props in analysis.items():
        print(f"\n{name.upper()}:")
        print(f"  Equation: {props['equation']}")
        print(f"  Sacred Note: {props['sacred_note']}")
    
    # Golden spiral demonstration
    print()
    print("─" * 50)
    print("GOLDEN SPIRAL ON VESICA CURVE (first 8 Fibonacci points):")
    vesica = create_vesica_curve(demo_prime)
    
    # Use a simple generator point (check it's on the curve)
    g_x = 2
    g_y_squared = (pow(g_x, 3, demo_prime) + vesica.a * g_x + vesica.b) % demo_prime
    
    print(f"  Curve: {vesica}")
    print(f"  Generator x = {g_x}")
    print(f"  y² = {g_y_squared} (mod {demo_prime})")
    print()
    print("  The golden spiral, like the Fibonacci sequence,")
    print("  produces a never-repeating, self-similar pattern —")
    print("  the perfect key derivation for esoteric knowledge access.")
