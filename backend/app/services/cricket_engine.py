"""The cricket engine — every rule about a ball, an over, an innings.

Extracted from routers/cricket.py, which had grown the innings state
machine, standings reversal and score formatting inline (the router was
the only large one importing zero services). The router keeps HTTP:
auth, tenancy, request shapes, status codes. This module keeps cricket.
"""
import logging
import uuid

from sqlalchemy.orm import Session, joinedload

from app.models.cricket import CricketBall, CricketMatch
from app.models.sports import Player, Team

logger = logging.getLogger(__name__)


def _get_or_create_player(db: Session, team_id: str, name: str, org_id=None) -> Player:
    if not name:
        return None
    player = db.query(Player).filter(Player.team_id == team_id, Player.name == name).first()
    if not player:
        player = Player(
            id=uuid.uuid4(), team_id=team_id, name=name, organization_id=org_id
        )
        db.add(player)
        db.commit()
    return player



def _fmt_innings(runs, wkts, overs, balls) -> str:
    """A NRR-parseable innings score, e.g. '146/3 (18.4 ov)'."""
    return f"{runs}/{wkts} ({overs}.{balls} ov)"


def _write_cricket_scores(fixture, first_innings, state) -> None:
    """Write both teams' final innings scores onto the fixture (score columns
    are free-text and are what the NRR service parses)."""
    scores = {}
    if first_innings:
        scores[str(first_innings["team_id"])] = _fmt_innings(
            first_innings["score"], first_innings["wickets"], first_innings["overs"], first_innings["balls"])
    scores[str(state["batting_team_id"])] = _fmt_innings(
        state["score"], state["wickets"], state["overs"], state["balls"])
    fixture.team_a_score = scores.get(str(fixture.team_a_id))
    fixture.team_b_score = scores.get(str(fixture.team_b_id))


def _cricket_result_notes(fixture, state, winner_id) -> str:
    """Human result line, e.g. 'Eagles won by 6 wickets' / 'Phoenix won by 24 runs'."""
    if winner_id is None:
        return "Match tied"
    winner_name = (
        fixture.team_a.name if fixture.team_a and str(winner_id) == str(fixture.team_a_id)
        else (fixture.team_b.name if fixture.team_b else "")
    )
    if state.get("target") is not None and state["score"] >= state["target"]:
        wl = 10 - state["wickets"]
        return f"{winner_name} won by {wl} wicket{'s' if wl != 1 else ''}"
    margin = (state["target"] - 1 - state["score"]) if state.get("target") is not None else 0
    return f"{winner_name} won by {margin} run{'s' if margin != 1 else ''}"


def _apply_cricket_standings(db: Session, fixture, winner_id, delta: int) -> None:
    """Apply (delta=+1) or reverse (delta=-1) a completed cricket result on the
    two teams' standings. Idempotent by construction — callers apply +1 only on
    the transition into COMPLETED and -1 only when reverting out of it."""
    team_a = db.query(Team).filter(Team.id == fixture.team_a_id).first()
    team_b = db.query(Team).filter(Team.id == fixture.team_b_id).first()
    if winner_id is None:
        for t in (team_a, team_b):
            if t:
                t.draws = (t.draws or 0) + delta
                t.points = (t.points or 0) + delta  # 1 point each for a tie
        return
    winner = team_a if str(winner_id) == str(fixture.team_a_id) else team_b
    loser = team_b if winner is team_a else team_a
    if winner:
        winner.wins = (winner.wins or 0) + delta
        winner.points = (winner.points or 0) + 2 * delta
    if loser:
        loser.losses = (loser.losses or 0) + delta


def recalculate_match_state(db: Session, match: CricketMatch):
    # Eager-load the three player relationships: the replay loop reads
    # b.striker/non_striker/bowler.name, which was an N+1 lazy query per ball —
    # murderous on a remote Postgres (a network round-trip per player per ball).
    balls = (
        db.query(CricketBall)
        .options(
            joinedload(CricketBall.striker),
            joinedload(CricketBall.non_striker),
            joinedload(CricketBall.bowler),
        )
        .filter(CricketBall.match_id == match.id)
        .order_by(CricketBall.ball_index)
        .all()
    )
    
    # Base state
    state = {
        "innings": 1,
        "batting_team_id": None,
        "bowling_team_id": None,
        "score": 0,
        "wickets": 0,
        "overs": 0,
        "balls": 0,
        "target": None,
        "batters": {},
        "bowlers": {},
        "extras": {"w": 0, "nb": 0, "b": 0, "lb": 0},
        "recent_balls": [],
        "overs_history": []
    }
    
    if match.toss_decision == "BAT":
        state["batting_team_id"] = str(match.toss_winner_id)
        state["bowling_team_id"] = str(match.fixture.team_a_id if str(match.fixture.team_b_id) == str(match.toss_winner_id) else match.fixture.team_b_id)
    else:
        state["bowling_team_id"] = str(match.toss_winner_id)
        state["batting_team_id"] = str(match.fixture.team_a_id if str(match.fixture.team_b_id) == str(match.toss_winner_id) else match.fixture.team_b_id)

    current_innings = 1
    # Village house-rule: the first two wides in each over carry no penalty
    # run (still re-bowled). Tracks wides in the over currently in progress;
    # reset on over completion and at the innings change.
    village_wides = bool(getattr(match, "village_wides", False))
    wides_this_over = 0
    # Snapshot of the completed first innings (set at the innings change) — used
    # to write both teams' final scores when the match completes.
    first_innings = None

    def ensure_batter(pid, name):
        if str(pid) not in state["batters"]:
            state["batters"][str(pid)] = {"name": name, "runs": 0, "balls": 0, "fours": 0, "sixes": 0, "out": False}
    
    def ensure_bowler(pid, name):
        if str(pid) not in state["bowlers"]:
            state["bowlers"][str(pid)] = {"name": name, "legal_balls": 0, "runs": 0, "wickets": 0}

    for b in balls:
        if b.innings_number > current_innings:
            # Snapshot the just-completed first innings before we reset for the
            # second — needed to write both teams' final scores on completion.
            first_innings = {
                "team_id": state["batting_team_id"],
                "score": state["score"],
                "wickets": state["wickets"],
                "overs": state["overs"],
                "balls": state["balls"],
            }
            current_innings = b.innings_number
            state["innings"] = current_innings
            state["target"] = state["score"] + 1
            state["score"] = 0
            state["wickets"] = 0
            state["overs"] = 0
            state["balls"] = 0
            state["batting_team_id"], state["bowling_team_id"] = state["bowling_team_id"], state["batting_team_id"]
            state["extras"] = {"w": 0, "nb": 0, "b": 0, "lb": 0}
            state["recent_balls"] = []
            state["overs_history"] = []
            # Reset the per-innings scorecards too. Without this, innings-1
            # batters and bowlers linger into innings 2 — and since the teams
            # have just swapped, an innings-1 bowler now belongs to the batting
            # side. The mobile "next bowler" picker then offers them and the ball
            # endpoint rejects the delivery ("Bowler does not belong to the
            # bowling team"). Each innings starts with a clean scorecard.
            state["batters"] = {}
            state["bowlers"] = {}
            wides_this_over = 0

        striker_name = b.striker.name if b.striker else "Unknown striker"
        non_striker_name = b.non_striker.name if b.non_striker else "Unknown non-striker"
        bowler_name = b.bowler.name if b.bowler else "Unknown bowler"
        ensure_batter(b.striker_id, striker_name)
        ensure_batter(b.non_striker_id, non_striker_name)
        ensure_bowler(b.bowler_id, bowler_name)

        is_legal = b.extras_type not in ["WIDE", "NO_BALL"]

        ball_runs = b.runs_batter
        bowler_runs = b.runs_batter

        free_wide = False
        if b.extras_type == "WIDE":
            wides_this_over += 1
            # First two wides of the over are free under the village rule:
            # no penalty run added, but still an illegal (re-bowled) delivery.
            free_wide = village_wides and wides_this_over <= 2
            if free_wide:
                # No 1-run penalty under the village rule, but runs physically
                # run off the delivery (byes/overthrows) still count against the
                # bowling side — a free wide can still be run on.
                if b.extras_runs:
                    ball_runs += b.extras_runs
                    bowler_runs += b.extras_runs
                    state["extras"]["w"] += b.extras_runs
            else:
                ball_runs += 1 + b.extras_runs
                bowler_runs += 1 + b.extras_runs
                state["extras"]["w"] += 1 + b.extras_runs
        elif b.extras_type == "NO_BALL":
            ball_runs += 1 + b.extras_runs
            bowler_runs += 1 + b.runs_batter
            state["extras"]["nb"] += 1 + b.extras_runs
        elif b.extras_type == "BYE":
            ball_runs = b.extras_runs
            bowler_runs = 0
            state["extras"]["b"] += b.extras_runs
        elif b.extras_type == "LEG_BYE":
            ball_runs = b.extras_runs
            bowler_runs = 0
            state["extras"]["lb"] += b.extras_runs

        state["score"] += ball_runs
        
        if b.extras_type not in ["WIDE"]:
            state["batters"][str(b.striker_id)]["balls"] += 1
            
        state["batters"][str(b.striker_id)]["runs"] += b.runs_batter
        if b.runs_batter == 4: state["batters"][str(b.striker_id)]["fours"] += 1
        if b.runs_batter == 6: state["batters"][str(b.striker_id)]["sixes"] += 1

        state["bowlers"][str(b.bowler_id)]["runs"] += bowler_runs
        if is_legal:
            state["balls"] += 1
            state["bowlers"][str(b.bowler_id)]["legal_balls"] += 1
            if state["balls"] == 6:
                state["overs"] += 1
                state["balls"] = 0
                wides_this_over = 0

        if b.is_wicket:
            state["wickets"] += 1
            if b.player_dismissed_id:
                pid_str = str(b.player_dismissed_id)
                if pid_str in state["batters"]:
                    state["batters"][pid_str]["out"] = True
            if b.wicket_type in ["BOWLED", "CAUGHT", "LBW", "STUMPED", "HIT_WICKET"]:
                state["bowlers"][str(b.bowler_id)]["wickets"] += 1

        ball_str = ""
        if b.is_wicket:
            ball_str = "W"
        elif b.extras_type == "WIDE":
            # Free (village-rule) wide: show only runs physically run (bare
            # "wd" when none); a normal wide includes the 1-run penalty.
            if free_wide:
                ball_str = f"{b.extras_runs}wd" if b.extras_runs else "wd"
            else:
                ball_str = f"{1 + b.extras_runs}wd"
        elif b.extras_type == "NO_BALL":
            ball_str = f"{1 + b.extras_runs}nb"
        elif b.extras_type == "BYE":
            ball_str = f"{b.extras_runs}b"
        elif b.extras_type == "LEG_BYE":
            ball_str = f"{b.extras_runs}lb"
        else:
            ball_str = str(b.runs_batter) if b.runs_batter > 0 else "•"
        
        state["recent_balls"].append(ball_str)
        
        # Build over history
        over_num = state["overs"]
        # If a ball completes an over, state["overs"] is already incremented.
        # But this ball belongs to the PREVIOUS over index.
        # However, wait! If state["balls"] == 0, then we just incremented overs.
        actual_over_idx = state["overs"] - 1 if state["balls"] == 0 and is_legal else state["overs"]
        
        while len(state["overs_history"]) <= actual_over_idx:
            state["overs_history"].append({"over_index": len(state["overs_history"]), "balls": []})
            
        state["overs_history"][actual_over_idx]["balls"].append({
            "id": str(b.id),
            "ball_index": b.ball_index,
            "striker_id": str(b.striker_id),
            "striker_name": b.striker.name,
            "non_striker_id": str(b.non_striker_id),
            "non_striker_name": b.non_striker.name,
            "bowler_id": str(b.bowler_id),
            "bowler_name": b.bowler.name,
            "runs_batter": b.runs_batter,
            "extras_type": b.extras_type,
            "extras_runs": b.extras_runs,
            "is_wicket": b.is_wicket,
            "wicket_type": b.wicket_type,
            "player_dismissed_id": str(b.player_dismissed_id) if b.player_dismissed_id else None,
            "ball_str": ball_str,
            "is_legal": is_legal,
            "notes": b.notes,
            "edit_history": b.edit_history
        })

    innings_over = state["wickets"] >= 10 or (
        state["overs"] == match.overs_per_innings and state["balls"] == 0 and state["overs"] > 0
    )
    chase_done = state["innings"] == 2 and state["target"] is not None and state["score"] >= state["target"]

    if chase_done or (innings_over and state["innings"] == 2):
        # True only the first time we cross into COMPLETED — gates the one-off
        # standings update so replaying (every ball/edit) can't double-count.
        newly_completed = match.fixture.status != "COMPLETED"
        match.status = "COMPLETED"
        if state["score"] >= state["target"]:
            winner_id = match.fixture.team_a_id if str(match.fixture.team_a_id) == state["batting_team_id"] else match.fixture.team_b_id
        elif state["score"] == state["target"] - 1:
            winner_id = None
        else:
            winner_id = match.fixture.team_a_id if str(match.fixture.team_a_id) == state["bowling_team_id"] else match.fixture.team_b_id

        match.fixture.winner_id = winner_id
        match.fixture.status = "COMPLETED"
        # Write the real scores (NRR-parseable) + a human result line, instead
        # of the old "Completed" placeholder.
        _write_cricket_scores(match.fixture, first_innings, state)
        match.fixture.result_notes = _cricket_result_notes(match.fixture, state, winner_id)
        if newly_completed:
            _apply_cricket_standings(db, match.fixture, winner_id, +1)
    elif innings_over and state["innings"] == 1:
        match.status = "INNINGS_BREAK"
    else:
        # Live play (also reverts a stale INNINGS_BREAK/COMPLETED after an undo).
        match.status = "FIRST_INNINGS" if state["innings"] == 1 else "SECOND_INNINGS"
        if match.fixture.status == "COMPLETED":
            # Reverting a completed match (e.g. an undo dropped the winning run)
            # — roll the standings back and clear the result.
            _apply_cricket_standings(db, match.fixture, match.fixture.winner_id, -1)
            match.fixture.status = "LIVE"
            match.fixture.winner_id = None
            match.fixture.team_a_score = None
            match.fixture.team_b_score = None
            match.fixture.result_notes = None

    # Surface lifecycle status inside match_state so the mobile scorer sees
    # INNINGS_BREAK / COMPLETED without a second request.
    state["status"] = match.status
    # Surface the village-wides rule + how many wides have landed in the over
    # in progress, so the scorer knows when the next wide is still "free".
    state["village_wides"] = village_wides
    state["wides_this_over"] = wides_this_over
    match.match_state = dict(state)

    db.commit()
    return state
