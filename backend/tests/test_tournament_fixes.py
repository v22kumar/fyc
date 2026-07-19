"""Fixes for the live-tournament bug report:
  1. A knockout tournament must NOT auto-complete just because its current round
     of fixtures is all done — COMPLETED is admin-marked only.
  2. NRR uses the real over quota (an all-out side is charged the full 10 overs).
  4b. A COMPLETED match stays editable (adding/correcting a delivery isn't
      blocked as "not LIVE").
"""
import uuid

from tests.test_cricket_scoring import _make_org, _make_exec, _login, _h, _setup_fixture, _init_payload


def test_tournament_not_auto_completed_when_round_is_done(client, db):
    from app.models.sports import Tournament, Team, Fixture

    org = _make_org(db)
    _make_exec(db, org.id, "9500000401")
    H = _h(org.id, _login(client, org.id, "9500000401"))

    t = Tournament(id=uuid.uuid4(), organization_id=org.id, name_en="KO League",
                   name_ta="KO League", sport="cricket", year=2026, status="ONGOING", format="KNOCKOUT")
    db.add(t)
    db.flush()
    a = Team(id=uuid.uuid4(), organization_id=org.id, tournament_id=t.id, name="A", status="APPROVED")
    b = Team(id=uuid.uuid4(), organization_id=org.id, tournament_id=t.id, name="B", status="APPROVED")
    db.add_all([a, b])
    db.flush()
    # Round 1 is finished, but more rounds are to come.
    db.add(Fixture(id=uuid.uuid4(), organization_id=org.id, tournament_id=t.id,
                   team_a_id=a.id, team_b_id=b.id, match_number=1, status="COMPLETED",
                   winner_id=a.id, team_a_score="50/2 (10.0 ov)", team_b_score="49/8 (10.0 ov)"))
    db.commit()

    r = client.get("/api/v1/sports/tournaments", headers=H)
    assert r.status_code == 200, r.text
    ko = next(x for x in r.json() if x["name_en"] == "KO League")
    assert ko["phase"] == "ONGOING"  # NOT COMPLETED just because the round is done


def test_nrr_charges_full_quota_for_all_out_side():
    from app.services.nrr import compute_nrr

    class _F:
        status = "COMPLETED"
        team_a_id = "A"
        team_b_id = "B"
        team_a_score = "34/10 (6.3 ov)"   # all out — charged the full 10 overs
        team_b_score = "34/1 (3.3 ov)"

    nrr = compute_nrr([_F()], "10 Overs")
    # A: for = 34 over 10 (all out → full quota), against = 34 over 3.5
    assert nrr["A"] == round(34 / 10 - 34 / (3 + 3 / 6), 3)
    # Sanity: a wrong 20-over quota would give a different (more negative) number.
    assert nrr["A"] != round(34 / 20 - 34 / (3 + 3 / 6), 3)


def test_completed_match_still_accepts_a_new_ball(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0], overs=1), headers=H)
    p1 = init.json()["current_players"]
    for _ in range(6):  # 6 singles → 6 all out? no, 6 runs, over ends → innings break
        client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
            "striker_id": p1["striker_id"], "non_striker_id": p1["non_striker_id"],
            "bowler_id": p1["bowler_id"], "runs_batter": 1}, headers=H)
    r2 = client.post(f"/api/v1/fixtures/{fid}/cricket/second-innings", json={
        "toss_winner_id": team_ids[0], "toss_decision": "BAT", "overs": 1,
        "striker_name": "B1", "non_striker_name": "B2", "bowler_name": "A1"}, headers=H)
    p2 = r2.json()["current_players"]
    # target = 7; a 6 then a 1 wins it → COMPLETED.
    client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p2["striker_id"], "non_striker_id": p2["non_striker_id"],
        "bowler_id": p2["bowler_id"], "runs_batter": 6}, headers=H)
    w = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p2["striker_id"], "non_striker_id": p2["non_striker_id"],
        "bowler_id": p2["bowler_id"], "runs_batter": 1}, headers=H)
    assert w.json()["match_state"]["status"] == "COMPLETED"

    # A completed match stays editable — a further ball is NOT rejected as MATCH_NOT_LIVE.
    extra = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p2["striker_id"], "non_striker_id": p2["non_striker_id"],
        "bowler_id": p2["bowler_id"], "runs_batter": 0}, headers=H)
    assert extra.status_code == 200, extra.text
