"""
Glicko-2 rating system implementation.

Reference: Mark E. Glickman, "Example of the Glicko-2 system" (2012)
https://www.glicko.net/glicko/glicko2.pdf

Typical τ (system constant) = 0.5 — constrains volatility change per period.
For per-game updates (single opponent per period) this is accurate.
"""
import math
from dataclasses import dataclass
from typing import Tuple

TAU = 0.5           # system constant
EPSILON = 1e-6      # convergence tolerance for volatility
SCALE = 173.7178    # converts Glicko-1 → Glicko-2 scale

INITIAL_RATING = 1500.0
INITIAL_RD = 350.0
INITIAL_VOL = 0.06


@dataclass
class PlayerRating:
    rating: float = INITIAL_RATING
    rd: float = INITIAL_RD
    vol: float = INITIAL_VOL


def update(
    player: PlayerRating,
    opponent: PlayerRating,
    score: float,  # 1.0 = win, 0.5 = draw, 0.0 = loss
) -> Tuple[float, float, float]:
    """
    Compute new (rating, rd, vol) for `player` after one game vs `opponent`.
    Returns (new_rating, new_rd, new_vol) in Glicko-1 scale.
    """
    # Convert to Glicko-2 scale
    mu = (player.rating - 1500) / SCALE
    phi = player.rd / SCALE
    sigma = player.vol

    mu_j = (opponent.rating - 1500) / SCALE
    phi_j = opponent.rd / SCALE

    # g(φ) — reduces impact of opponents with high RD
    g_phi_j = _g(phi_j)

    # E — expected score
    e = _E(mu, mu_j, phi_j)

    # Step 3: v (estimated variance)
    v = 1.0 / (g_phi_j ** 2 * e * (1.0 - e))

    # Step 4: Δ (estimated improvement)
    delta = v * g_phi_j * (score - e)

    # Step 5: new volatility σ' (Illinois algorithm)
    new_sigma = _compute_new_vol(phi, sigma, delta, v)

    # Step 6: φ* (pre-rating-period RD)
    phi_star = math.sqrt(phi ** 2 + new_sigma ** 2)

    # Step 7: new φ'
    phi_prime = 1.0 / math.sqrt(1.0 / phi_star ** 2 + 1.0 / v)

    # Step 8: new μ'
    mu_prime = mu + phi_prime ** 2 * g_phi_j * (score - e)

    # Convert back to Glicko-1 scale
    new_rating = SCALE * mu_prime + 1500
    new_rd = SCALE * phi_prime
    # Clamp RD to sensible range
    new_rd = max(30.0, min(350.0, new_rd))

    return new_rating, new_rd, new_sigma


def _g(phi: float) -> float:
    return 1.0 / math.sqrt(1.0 + 3.0 * phi ** 2 / math.pi ** 2)


def _E(mu: float, mu_j: float, phi_j: float) -> float:
    return 1.0 / (1.0 + math.exp(-_g(phi_j) * (mu - mu_j)))


def _compute_new_vol(phi: float, sigma: float, delta: float, v: float) -> float:
    """Illinois algorithm for new volatility."""
    a = math.log(sigma ** 2)
    delta2 = delta ** 2
    phi2 = phi ** 2

    def f(x: float) -> float:
        exp_x = math.exp(x)
        tmp = phi2 + v + exp_x
        return (exp_x * (delta2 - phi2 - v - exp_x) / (2.0 * tmp ** 2)
                - (x - a) / TAU ** 2)

    # Initialise
    A = a
    if delta2 > phi2 + v:
        B = math.log(delta2 - phi2 - v)
    else:
        k = 1
        while f(a - k * TAU) < 0:
            k += 1
        B = a - k * TAU

    fA = f(A)
    fB = f(B)

    for _ in range(100):
        C = A + (A - B) * fA / (fB - fA)
        fC = f(C)
        if fB * fC <= 0:
            A, fA = B, fB
        else:
            fA /= 2.0
        B, fB = C, fC
        if abs(B - A) < EPSILON:
            break

    return math.exp(A / 2.0)


# ── Prestige title based on rating + games ─────────────────────────────────────

def prestige_title(rating: float, games_played: int) -> str:
    if games_played < 5:
        return "Newcomer"
    if rating < 1400:
        return "Rising Talent"
    if rating < 1550:
        return "Club Player"
    if rating < 1700:
        return "Skilled Player"
    if rating < 1850:
        return "Strong Player"
    if rating < 2000:
        return "Expert"
    if rating < 2150:
        return "Master"
    return "Kumari Icon"


def title_emoji(title: str) -> str:
    return {
        "Newcomer": "🌱",
        "Rising Talent": "⭐",
        "Club Player": "♟️",
        "Skilled Player": "🎯",
        "Strong Player": "🔥",
        "Expert": "💎",
        "Master": "👑",
        "Kumari Icon": "🏆",
    }.get(title, "♟️")
