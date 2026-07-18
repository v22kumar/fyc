"""Unit tests for the Net Run Rate service (app/services/nrr.py)."""
from types import SimpleNamespace

from app.services.nrr import parse_score, compute_nrr


def _fx(a_id, b_id, a_score, b_score, status="COMPLETED"):
    return SimpleNamespace(team_a_id=a_id, team_b_id=b_id,
                           team_a_score=a_score, team_b_score=b_score, status=status)


def test_parse_score_variants():
    assert parse_score("34/10 (6.3 ov)") == (34, 10, 6 + 3 / 6.0)
    assert parse_score("90/2 (10.0 ov)") == (90, 2, 10.0)
    assert parse_score("122/7 (10.0 ov)") == (122, 7, 10.0)
    assert parse_score("68 (4)") == (68, 0, 4.0)   # wickets optional
    assert parse_score(None) is None
    assert parse_score("no score") is None


def test_all_out_uses_full_quota():
    """Keelkulam 34 all out in 6.3 ov vs NRS 34/1 in 3.3 ov, 10-over match.
    All-out side counts as the full 10 overs; NRR is symmetric."""
    nrr = compute_nrr(
        [_fx("keel", "nrs", "34/10 (6.3 ov)", "34/1 (3.3 ov)")],
        match_config="10 Overs",
    )
    # NRS: 34/3.5 for, 34/10 against = 9.714 - 3.4 = +6.314
    assert nrr["nrs"] == 6.314
    assert nrr["keel"] == -6.314


def test_completed_only_and_ranking():
    fixtures = [
        _fx("a", "b", "68/10 (10.0 ov)", "68/0 (4.0 ov)"),      # b crushes a
        _fx("c", "d", "121/9 (10.0 ov)", "122/7 (10.0 ov)"),    # d edges c
        _fx("e", "f", "50/2 (10 ov)", "40/10 (9 ov)", status="SCHEDULED"),  # ignored
    ]
    nrr = compute_nrr(fixtures, match_config="10 Overs")
    assert "e" not in nrr and "f" not in nrr        # scheduled fixture skipped
    assert nrr["b"] > nrr["d"] > 0 > nrr["c"] > nrr["a"]  # b best, a worst


def test_unparseable_scores_skipped():
    nrr = compute_nrr([_fx("a", "b", None, "50/3 (10 ov)")], match_config="10 Overs")
    assert nrr == {}
