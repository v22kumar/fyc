from tests.test_cricket_scoring import _setup_fixture, _init_payload

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

