"""Net Run Rate (NRR) for a tournament's teams.

Computed from the string scores stored on completed fixtures
(e.g. "34/10 (6.3 ov)"), so it updates automatically as results are entered —
the natural tiebreaker for seeding qualifiers/eliminators when teams are level
on points.

Rules applied (standard cricket NRR):
  * NRR = (runs scored / overs faced) - (runs conceded / overs bowled).
  * A side that is ALL OUT is treated as having faced the full over quota,
    regardless of how few overs it actually lasted.
  * "6.3 ov" means 6 overs and 3 balls = 6.5 overs.
"""
import re
from typing import Optional, Dict

_SCORE_RE = re.compile(r"\s*(\d+)\s*(?:/\s*(\d+))?\s*\(\s*(\d+)(?:\.(\d+))?")


def parse_score(s: Optional[str]):
    """'34/10 (6.3 ov)' -> (runs, wickets, overs_as_float). None if unparseable."""
    if not s:
        return None
    m = _SCORE_RE.match(s)
    if not m:
        return None
    runs = int(m.group(1))
    wickets = int(m.group(2)) if m.group(2) is not None else 0
    overs = int(m.group(3))
    balls = int(m.group(4)) if m.group(4) is not None else 0
    return runs, wickets, overs + balls / 6.0


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
        # All out -> full quota of overs used against the run rate.
        a_ov = quota if aw >= all_out_wickets else min(ao, quota)
        b_ov = quota if bw >= all_out_wickets else min(bo, quota)
        if a_ov <= 0 or b_ov <= 0:
            continue
        _add(f.team_a_id, ar, a_ov, br, b_ov)
        _add(f.team_b_id, br, b_ov, ar, a_ov)

    nrr = {}
    for tid, (rf, of, ra, oa) in agg.items():
        if of > 0 and oa > 0:
            nrr[tid] = round(rf / of - ra / oa, 3)
    return nrr
