"""Offline-safe scoring: a ball carrying a client_ball_id is recorded exactly
once, even if the POST is retried (offline queue re-sync). Guards against the
duplicate-ball data corruption that a naive retry would cause.
"""
from tests.test_cricket_scoring import _setup_fixture, _init_payload


def _ball(client, fid, H, players, **extra):
    body = {
        "striker_id": players["striker_id"],
        "non_striker_id": players["non_striker_id"],
        "bowler_id": players["bowler_id"],
        "runs_batter": 1,
    }
    body.update(extra)
    return client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json=body, headers=H)


def test_same_client_ball_id_is_not_double_counted(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0], overs=5), headers=H)
    p = init.json()["current_players"]

    r1 = _ball(client, fid, H, p, runs_batter=1, client_ball_id="ball-abc")
    assert r1.status_code == 200, r1.text
    score1 = r1.json()["match_state"]["score"]

    # Re-send the identical ball (a retry / offline re-sync) — must be a no-op.
    r2 = _ball(client, fid, H, p, runs_batter=1, client_ball_id="ball-abc")
    assert r2.status_code == 200, r2.text
    score2 = r2.json()["match_state"]["score"]

    assert score1 == 1
    assert score2 == 1, "a retried ball with the same client_ball_id was double-counted"

    # A different client_ball_id is a genuinely new ball and does count.
    r3 = _ball(client, fid, H, p, runs_batter=1, client_ball_id="ball-def")
    assert r3.json()["match_state"]["score"] == 2


def test_ball_without_client_id_still_works(client, db):
    """Legacy clients that don't send client_ball_id keep working (no dedup)."""
    H, fid, team_ids = _setup_fixture(client, db)
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0], overs=5), headers=H)
    p = init.json()["current_players"]
    r = _ball(client, fid, H, p, runs_batter=2)
    assert r.status_code == 200, r.text
    assert r.json()["match_state"]["score"] == 2
