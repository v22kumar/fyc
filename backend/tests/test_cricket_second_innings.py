from tests.test_cricket_scoring import _setup_fixture, _init_payload


def _play_completed_match(client, H, fid, team_ids):
    """Team A bats a 1-over innings (scores 4), Team B chases and wins with a 6."""
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0], overs=1), headers=H)
    p1 = init.json()["current_players"]
    client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p1["striker_id"], "non_striker_id": p1["non_striker_id"],
        "bowler_id": p1["bowler_id"], "runs_batter": 4}, headers=H)
    for _ in range(5):
        client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
            "striker_id": p1["striker_id"], "non_striker_id": p1["non_striker_id"],
            "bowler_id": p1["bowler_id"], "runs_batter": 0}, headers=H)
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/second-innings", json={
        "toss_winner_id": team_ids[0], "toss_decision": "BAT", "overs": 1,
        "striker_name": "B1", "non_striker_name": "B2", "bowler_name": "A1"}, headers=H)
    p2 = r.json()["current_players"]
    ball = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p2["striker_id"], "non_striker_id": p2["non_striker_id"],
        "bowler_id": p2["bowler_id"], "runs_batter": 6}, headers=H)
    assert ball.status_code == 200, ball.text
    assert ball.json()["match_state"]["status"] == "COMPLETED"


def test_completed_cricket_match_writes_real_scores_result_and_standings(client, db):
    """On completion the fixture must carry the real innings scores (not the old
    'Completed' placeholder), a human result line, and the two teams' standings
    must be updated exactly once."""
    from app.models.sports import Fixture, Team

    H, fid, team_ids = _setup_fixture(client, db)
    _play_completed_match(client, H, fid, team_ids)

    db.expire_all()
    fx = db.query(Fixture).filter(Fixture.id == fid).first()
    assert fx.status == "COMPLETED"
    # Real, NRR-parseable scores — never the "Completed" placeholder.
    assert fx.team_a_score and "Completed" not in fx.team_a_score
    assert fx.team_b_score and "Completed" not in fx.team_b_score
    assert "ov" in fx.team_a_score and "/" in fx.team_a_score
    assert fx.winner_id is not None
    assert fx.result_notes and "won by" in fx.result_notes

    # Team B chased and won → wins/points; Team A → a loss.
    a = db.query(Team).filter(Team.id == team_ids[0]).first()
    b = db.query(Team).filter(Team.id == team_ids[1]).first()
    assert str(fx.winner_id) == str(b.id)
    assert b.wins == 1 and b.points == 3
    assert a.losses == 1 and a.wins == 0


def test_editing_a_ball_after_completion_does_not_double_count_standings(client, db):
    """recalculate_match_state runs on every edit; the standings update must be a
    one-off on the transition into COMPLETED, never re-applied on replay."""
    from app.models.sports import Fixture, Team

    H, fid, team_ids = _setup_fixture(client, db)
    _play_completed_match(client, H, fid, team_ids)

    # Edit the winning delivery (6 → 5); still >= target, still a Team B win.
    ms = client.get(f"/api/v1/fixtures/{fid}/cricket", headers=H).json()["match_state"]
    last_ball_id = ms["overs_history"][-1]["balls"][-1]["id"]
    r = client.put(f"/api/v1/fixtures/{fid}/cricket/ball/{last_ball_id}",
                   json={"runs_batter": 5}, headers=H)
    assert r.status_code == 200, r.text

    db.expire_all()
    b = db.query(Team).filter(Team.id == team_ids[1]).first()
    a = db.query(Team).filter(Team.id == team_ids[0]).first()
    # Still exactly one win / one loss — not doubled.
    assert b.wins == 1 and b.points == 3
    assert a.losses == 1

def test_second_innings(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    
    # 1. Init match
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init", json=_init_payload(team_ids[0], overs=1), headers=H)
    players_1 = init.json()["current_players"]

    # 2. Score first innings (1 over)
    for i in range(6):
        r = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
            "striker_id": players_1["striker_id"],
            "non_striker_id": players_1["non_striker_id"],
            "bowler_id": players_1["bowler_id"],
            "runs_batter": 1,
            "extras_type": "NONE",
            "extras_runs": 0,
            "is_wicket": False,
        }, headers=H)
        assert r.status_code == 200, r.text

    # 3. Start second innings
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/second-innings", json={
        "toss_winner_id": team_ids[0],
        "toss_decision": "BAT",
        "overs": 1,
        "striker_name": "B1",
        "non_striker_name": "B2",
        "bowler_name": "A1"
    }, headers=H)
    assert r.status_code == 200, r.text
    
    players_2 = r.json()["current_players"]

    # 4. Score a ball in second innings WITH WRONG BATTERS (from first innings)
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": players_1["striker_id"], # WRONG
        "non_striker_id": players_1["non_striker_id"], # WRONG
        "bowler_id": players_2["bowler_id"],
        "runs_batter": 1,
        "extras_type": "NONE",
        "extras_runs": 0,
        "is_wicket": False,
    }, headers=H)
    print("WRONG BATTERS STATUS", r.status_code)
    print("WRONG BATTERS TEXT", r.text)

    # What if we pass the wrong bowler?
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": players_2["striker_id"],
        "non_striker_id": players_2["non_striker_id"],
        "bowler_id": players_1["bowler_id"], # WRONG
        "runs_batter": 1,
        "extras_type": "NONE",
        "extras_runs": 0,
        "is_wicket": False,
    }, headers=H)
    print("WRONG BOWLER STATUS", r.status_code)
    print("WRONG BOWLER TEXT", r.text)


def test_second_innings_scorecard_excludes_first_innings_players(client, db):
    """At the innings change the batters/bowlers scorecards reset, so innings 2
    never carries innings-1 players. Regression for the live bug 'Bowler does
    not belong to the bowling team': an innings-1 bowler (now on the batting
    side after the swap) lingered in state and the next-bowler picker offered
    them, producing a batting-team bowler_id the ball endpoint rejects."""
    H, fid, team_ids = _setup_fixture(client, db)
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0], overs=1), headers=H)  # Kumar/Raj bat, Vel bowls
    p1 = init.json()["current_players"]
    for _ in range(6):
        client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
            "striker_id": p1["striker_id"], "non_striker_id": p1["non_striker_id"],
            "bowler_id": p1["bowler_id"], "runs_batter": 1}, headers=H)

    r = client.post(f"/api/v1/fixtures/{fid}/cricket/second-innings", json={
        "toss_winner_id": team_ids[0], "toss_decision": "BAT", "overs": 1,
        "striker_name": "B1", "non_striker_name": "B2", "bowler_name": "A1"}, headers=H)
    assert r.status_code == 200, r.text
    p2 = r.json()["current_players"]

    ball = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p2["striker_id"], "non_striker_id": p2["non_striker_id"],
        "bowler_id": p2["bowler_id"], "runs_batter": 1}, headers=H)
    assert ball.status_code == 200, ball.text
    st = ball.json()["match_state"]

    batting_names = {b["name"] for b in st["batters"].values()}
    bowling_names = {b["name"] for b in st["bowlers"].values()}
    # innings-2 players are present…
    assert {"B1", "B2"}.issubset(batting_names)
    assert "A1" in bowling_names
    # …and innings-1 players do NOT linger into innings 2.
    assert "Kumar" not in batting_names and "Raj" not in batting_names
    assert "Vel" not in bowling_names

