"""Net Run Rate (NRR) for a tournament's teams.

Computed from the string scores stored on completed fixtures
(e.g. "34/10 (6.3 ov)"), so it updates automatically as results are entered —
the natural tiebreaker for seeding qualifiers/eliminators when teams are level
on points.

Rules applied (standard cricket NRR):
  * NRR = (runs scored / overs faced) - (runs conceded / overs bowled).
  * A side that is ALL OUT is treated as having faced the full over quota,
    regardless of how few overs it actually lasted.
  * A side whose innings has runs recorded but NO overs (e.g. a result typed
    into the admin form as just "112/6") is likewise charged the full quota —
    so a played match still gets an NRR instead of showing a blank "—". As
    soon as the real overs land (seed/live scoring) the value sharpens.
  * "6.3 ov" means 6 overs and 3 balls = 6.5 overs.
"""
import re
from typing import Optional, Dict

# Runs are required; wickets ("/10") and the overs in parens ("(6.3 ov)") are
# both optional so a runs-only score still parses (overs then default to quota).
_SCORE_RE = re.compile(r"\s*(\d+)\s*(?:/\s*(\d+))?(?:\s*\(\s*(\d+)(?:\.(\d+))?)?")


def parse_score(s: Optional[str]):
    """'34/10 (6.3 ov)' -> (runs, wickets, overs_or_None).

    overs is None when the string carries no parseable overs component (e.g.
    "112/6"); the caller then charges the full quota. Returns None only when
    there aren't even any runs to read.
    """
    if not s:
        return None
    m = _SCORE_RE.match(s)
    if not m:
        return None
    runs = int(m.group(1))
    wickets = int(m.group(2)) if m.group(2) is not None else 0
    if m.group(3) is None:
        return runs, wickets, None
    overs = int(m.group(3))
    balls = int(m.group(4)) if m.group(4) is not None else 0
    return runs, wickets, overs + balls / 6.0


# Strict form used to VALIDATE user-entered scores: the whole string must be
# runs, an optional "/wickets", and an optional "(overs[.balls] ov)" — nothing
# else. Trailing junk (a stray letter from a typo) fails fullmatch, so it can't
# be silently truncated into a wrong number that then skews NRR.
_STRICT_SCORE_RE = re.compile(
    r"\s*(\d+)\s*(?:/\s*(\d+))?\s*(?:\(\s*(\d+)(?:\.(\d+))?\s*(?:ov(?:er)?s?)?\s*\)?)?\s*",
    re.IGNORECASE,
)


def normalize_score(s: Optional[str]) -> Optional[str]:
    """Validate and canonicalise a user-entered innings score for storage.

    An empty value is allowed (a result may carry only a winner) and returns
    None. A non-empty value MUST be a well-formed cricket score; it is rewritten
    to the canonical, NRR-parseable form so a typo can never reach the standings:

        "120/5 (20)"   -> "120/5 (20.0 ov)"
        "34 (6.3 ov)"  -> "34/0 (6.3 ov)"
        "112/6"        -> "112/6"            (no overs given — allowed)

    Raises ValueError with a friendly message on anything malformed (letters, a
    ball count above 5, more than 10 wickets, trailing junk).
    """
    if s is None:
        return None
    s = s.strip()
    if not s:
        return None
    m = _STRICT_SCORE_RE.fullmatch(s)
    if not m:
        raise ValueError(
            f'"{s}" isn\'t a valid score. Enter runs, optional wickets and overs '
            f'— e.g. "120/5 (20.0 ov)".'
        )
    runs = int(m.group(1))
    wkts = int(m.group(2)) if m.group(2) is not None else 0
    if wkts > 10:
        raise ValueError(f"A side can lose at most 10 wickets (got {wkts}).")
    if m.group(3) is None:
        return f"{runs}/{wkts}"
    overs = int(m.group(3))
    balls = int(m.group(4)) if m.group(4) is not None else 0
    if balls > 5:
        raise ValueError(
            f"An over has 6 balls, so the balls part runs 0–5 (got .{balls})."
        )
    return f"{runs}/{wkts} ({overs}.{balls} ov)"


def _quota_overs(match_config: Optional[str], default: float = 20.0) -> float:
    """Full over quota for the match, parsed from e.g. '10 Overs'."""
    if match_config:
        m = re.search(r"(\d+)", match_config)
        if m:
            return float(int(m.group(1)))
    return default


def compute_nrr(fixtures, match_config: Optional[str], all_out_wickets: int = 10) -> Dict:
    """Return {team_id: nrr_float} over COMPLETED fixtures with parseable scores.

    `fixtures` is any iterable of objects with team_a_id/team_b_id/status/
    team_a_score/team_b_score. Teams with no usable innings are omitted.
    """
    quota = _quota_overs(match_config)
    agg: Dict = {}  # team_id -> [runs_for, overs_for, runs_against, overs_against]

    def _add(tid, rf, of, ra, oa):
        a = agg.setdefault(tid, [0.0, 0.0, 0.0, 0.0])
        a[0] += rf
        a[1] += of
        a[2] += ra
        a[3] += oa

    for f in fixtures:
        if f.status != "COMPLETED":
            continue
        a = parse_score(f.team_a_score)
        b = parse_score(f.team_b_score)
        if not a or not b:
            continue
        ar, aw, ao = a
        br, bw, bo = b
        # Overs faced: the full quota when a side is all out OR when the innings
        # has no recorded overs (ao/bo is None); otherwise the overs actually
        # faced, capped at the quota.
        a_ov = quota if (aw >= all_out_wickets or ao is None) else min(ao, quota)
        b_ov = quota if (bw >= all_out_wickets or bo is None) else min(bo, quota)
        if a_ov <= 0 or b_ov <= 0:
            continue
        _add(f.team_a_id, ar, a_ov, br, b_ov)
        _add(f.team_b_id, br, b_ov, ar, a_ov)

    nrr = {}
    for tid, (rf, of, ra, oa) in agg.items():
        if of > 0 and oa > 0:
            nrr[tid] = round(rf / of - ra / oa, 3)
    return nrr
