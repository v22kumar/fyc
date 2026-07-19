"""Backfill completed-match results for an already-played cricket round.

Use case: a round was played offline and needs to land in the DB as COMPLETED
fixtures, while the remaining matches will be scored live in the app. Completed
matches store their result on the fixture itself (team_a_score / team_b_score /
winner_id / result_notes / status=COMPLETED) — no ball-by-ball is required, which
is exactly how an executive enters a result by hand in the app.

Design goals:
  * IDEMPOTENT   — teams matched by name (case-insensitive), fixtures by
                   match_number; re-running does not duplicate anything.
  * DRY-RUN FIRST — prints the full plan and writes NOTHING unless --commit.
  * NON-DESTRUCTIVE — never deletes; only creates missing teams/fixtures and
                   fills results. Leaves any existing placeholder fixture alone.
  * QUIET        — sets standings directly and does NOT broadcast the per-result
                   push notification (this round already happened).

Run inside the backend (e.g. `fly ssh console`):
    python scripts/seed_tournament_results.py                 # dry-run
    python scripts/seed_tournament_results.py --commit        # apply
    python scripts/seed_tournament_results.py --tournament "<id or name>" --commit

Team-name aliases (see ALIASES) collapse spelling variants (e.g. "7YC B"/"FYC B")
onto one canonical team so a result never creates a duplicate side.
"""
import argparse
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import SessionLocal
from app.models.sports import Tournament, Team, Fixture

# ── The round, exactly as supplied. Each match: teams, scores, winner, notes. ──
# `winner` MUST equal one of the two team names (post-alias).
MATCHES = [
    dict(no=1, a="Keelkulam Stars",      a_score="34/10 (6.3 ov)",
              b="NRS Pandaraparambu",    b_score="34/1 (3.3 ov)",
              winner="NRS Pandaraparambu", notes="NRS Pandaraparambu won by 9 wickets"),
    dict(no=2, a="ARASAMOODU",           a_score="90/2 (10.0 ov)",
              b="Achalipuram",           b_score="90/5 (8.0 ov)",
              winner="Achalipuram",      notes="Achalipuram won by 5 wickets"),
    dict(no=3, a="Cherivilei 11 Star",   a_score="66/10 (10.0 ov)",
              b="Mukkadu",               b_score="68/2 (8.0 ov)",
              winner="Mukkadu",          notes="Mukkadu won by 8 wickets"),
    dict(no=4, a="TCC",                  a_score="47/10 (10.0 ov)",
              b="Nethaji Sports Club",   b_score="49/6 (6.0 ov)",
              winner="Nethaji Sports Club", notes="Nethaji Sports Club won by 4 wickets"),
    dict(no=5, a="Mexianz",              a_score="68/10 (10.0 ov)",
              b="Chenithottam",          b_score="68/0 (4.0 ov)",
              winner="Chenithottam",     notes="Chenithottam won by 10 wickets"),
    dict(no=6, a="Cherukarai",           a_score="69/10 (10.0 ov)",
              b="FYC B",                 b_score="93/4 (7.0 ov)",
              winner="FYC B",            notes="FYC B won by 6 wickets"),
    dict(no=7, a="Kalungu",              a_score="121/9 (10.0 ov)",
              b="Thondanamvilai",        b_score="122/7 (10.0 ov)",
              winner="Thondanamvilai",   notes="Thondanamvilai won by 3 wickets"),
    # 8th match — a 9-over game (Kollamcode batted first).
    dict(no=8, a="Kollamcode",           a_score="112/6 (9.0 ov)",
              b="Karungal",              b_score="54/9 (9.0 ov)",
              winner="Kollamcode",       notes="Kollamcode won by 58 runs"),
]

# Spelling variants -> canonical team name. Extend if the DB uses another form.
ALIASES = {
    "7yc b": "FYC B",
    "kollemcode": "Kollamcode",
    "karugal": "Karungal",
}

# Junk/misspelled teams to delete from the tournament before seeding (matched
# case-insensitively). Removing a team also removes any fixtures referencing it
# (e.g. a placeholder), so the standings/feed only carry the real entries.
REMOVE_TEAMS = [
    "NMC pandaraparambu",  # misspelling; the real team is "NRS Pandaraparambu"
]

# The balance of the 20-team bracket — registered as PENDING (awaiting approval
# / later rounds), no fixtures. Teams that already exist (e.g. FYC A) are left
# with their current status untouched.
PENDING_TEAMS = [
    "FYC A",
    "Kollamcode",
    "Thozikode",
    "Marthandam",
    "Irenipuram",
    "Karungal",
]


def _canon(name: str) -> str:
    return ALIASES.get(name.strip().lower(), name.strip())


def _find_tournament(db, ident):
    """Resolve by id, else exact/like name, else the sole ongoing cricket one."""
    if ident:
        t = db.query(Tournament).filter(Tournament.id == ident).first()
        if t:
            return t
        # Never let a substring silently pick one of several tournaments — that
        # could backfill the wrong one. Require an unambiguous match.
        matches = db.query(Tournament).filter(
            Tournament.name_en.ilike(f"%{ident}%")).all()
        if len(matches) == 1:
            return matches[0]
        if len(matches) > 1:
            names = ", ".join(f"{m.name_en} ({m.id})" for m in matches)
            raise SystemExit(f"Multiple tournaments matched '{ident}': {names}. Pass the id.")
        raise SystemExit(f"No tournament matched id/name '{ident}'.")
    ongoing = db.query(Tournament).filter(
        Tournament.sport == "cricket", Tournament.status == "ONGOING").all()
    if len(ongoing) == 1:
        return ongoing[0]
    if not ongoing:
        raise SystemExit("No ongoing cricket tournament found — pass --tournament <id or name>.")
    names = ", ".join(f"{t.name_en} ({t.id})" for t in ongoing)
    raise SystemExit(f"Multiple ongoing cricket tournaments — pass --tournament. Candidates: {names}")


def seed_round(db, t, matches=MATCHES, *, commit, log=print, pending_teams=PENDING_TEAMS):
    """Ensure teams + fixtures + results for `matches` on tournament `t`.

    Idempotent and non-destructive. Standings are credited only the first time a
    fixture flips to COMPLETED. Never broadcasts a notification. Returns a
    summary dict. Writes only when `commit` is True (otherwise rolls back).
    """
    org_id = t.organization_id
    log(f"Tournament: {t.name_en}  [{t.id}]  status={t.status}  org={org_id}")
    log(f"Mode: {'COMMIT' if commit else 'DRY-RUN (no writes)'}\n")

    # Remove junk/misspelled teams first, along with any fixtures that reference
    # them (a placeholder fixture, say), so they don't linger in the standings.
    removed_teams = 0
    remove_keys = {n.strip().lower() for n in REMOVE_TEAMS}
    for tm in db.query(Team).filter(Team.tournament_id == t.id).all():
        if tm.name.strip().lower() in remove_keys:
            fx = db.query(Fixture).filter(
                Fixture.tournament_id == t.id,
                (Fixture.team_a_id == tm.id) | (Fixture.team_b_id == tm.id)).all()
            for f in fx:
                log(f"  - fixture #{f.match_number} ({f.status}) — references removed team")
                db.delete(f)
            db.delete(tm)
            removed_teams += 1
            log(f"  - team  {tm.name}")
    if removed_teams:
        db.flush()

    existing = {(_canon(tm.name)).lower(): tm
                for tm in db.query(Team).filter(Team.tournament_id == t.id).all()}
    created_teams = 0

    def ensure_team(name):
        nonlocal created_teams
        key = _canon(name).lower()
        if key in existing:
            return existing[key]
        tm = Team(id=uuid.uuid4(), organization_id=org_id, tournament_id=t.id,
                  name=_canon(name), status="APPROVED")
        db.add(tm)
        db.flush()              # get an id without committing
        existing[key] = tm
        created_teams += 1
        log(f"  + team  {tm.name}")
        return tm

    fx_by_no = {f.match_number: f
                for f in db.query(Fixture).filter(Fixture.tournament_id == t.id).all()
                if f.match_number is not None}
    created_fixtures = 0

    for m in matches:
        a = ensure_team(m["a"])
        b = ensure_team(m["b"])
        win = ensure_team(m["winner"])
        # A team that has actually played can't stay PENDING (some were
        # pre-registered as balance-of-bracket placeholders).
        for tm in (a, b):
            if tm.status == "PENDING":
                tm.status = "APPROVED"
                log(f"  ~ approved {tm.name} (now has a played match)")
        f = fx_by_no.get(m["no"])
        # Refuse to clobber a fixture that is already COMPLETED with a *different*
        # result — overwriting would leave standings crediting the old winner.
        # An identical re-completion (same pair + winner) passes through as a
        # harmless idempotent no-op.
        if f and f.status == "COMPLETED":
            same_pair = {str(f.team_a_id), str(f.team_b_id)} == {str(a.id), str(b.id)}
            same_winner = f.winner_id is None or str(f.winner_id) == str(win.id)
            if not (same_pair and same_winner):
                raise SystemExit(
                    f"Match #{m['no']} is already COMPLETED with a conflicting result "
                    f"({f.team_a_score} / {f.team_b_score}). Refusing to overwrite — "
                    f"clear that fixture in-app first, then re-run.")
        action = "update" if f else "create"
        if not f:
            f = Fixture(id=uuid.uuid4(), organization_id=org_id, tournament_id=t.id,
                        team_a_id=a.id, team_b_id=b.id, match_number=m["no"],
                        venue="Munchirai")
            db.add(f)
            fx_by_no[m["no"]] = f
            created_fixtures += 1
        else:
            # keep the sides consistent with the supplied scoreboard
            f.team_a_id, f.team_b_id = a.id, b.id

        already_done = f.status == "COMPLETED"
        f.team_a_score = m["a_score"]
        f.team_b_score = m["b_score"]
        f.result_notes = m["notes"]
        f.winner_id = win.id
        f.status = "COMPLETED"

        # Credit a win/loss only the first time this fixture completes, so
        # re-runs stay idempotent. (No push notification is sent.)
        if not already_done:
            loser = b if win.id == a.id else a
            win.wins = (win.wins or 0) + 1
            win.points = (win.points or 0) + 3
            loser.losses = (loser.losses or 0) + 1

        log(f"  {action:<6} match #{m['no']}: {a.name} ({m['a_score']}) vs "
            f"{b.name} ({m['b_score']}) -> {win.name}")

    # Register the balance-of-bracket teams as PENDING (no fixtures). Existing
    # teams keep their current status — an already-APPROVED team isn't downgraded.
    added_pending = 0
    for name in pending_teams:
        key = _canon(name).lower()
        if key in existing:
            continue
        tm = Team(id=uuid.uuid4(), organization_id=org_id, tournament_id=t.id,
                  name=_canon(name), status="PENDING")
        db.add(tm)
        db.flush()
        existing[key] = tm
        added_pending += 1
        log(f"  + pending team  {tm.name}")

    # Pin the village-wides house rule (first 2 wides/over free) on this live
    # tournament, and ensure a small TEST tournament (also village-wides) exists
    # for trial scoring — "one is live, one is test".
    if not getattr(t, "village_wides", False):
        t.village_wides = True
        log("  village_wides pinned ON for this tournament")
    # NRR over-quota for the all-out rule. The league is a 10-over competition
    # (a side bowled out early is still charged the full 10 overs). Match #8 was
    # a 9-over game but had no all-out innings, so the 10-over quota doesn't skew
    # it. Without this the quota silently defaults to 20, deflating every all-out
    # side's run rate.
    if t.match_config != "10 Overs":
        t.match_config = "10 Overs"
        log("  match_config pinned to '10 Overs'")
        
    test_name = "FYC Test — Village Wides"
    test_t = db.query(Tournament).filter(
        Tournament.organization_id == org_id, Tournament.name_en == test_name).first()
    if not test_t:
        test_t = Tournament(
            id=uuid.uuid4(), organization_id=org_id, name_ta=test_name, name_en=test_name,
            sport="cricket", year=t.year, status="ONGOING", format="KNOCKOUT",
            village_wides=True, match_config=t.match_config or "10 Overs")
        db.add(test_t)
        db.flush()
        for nm in ("Test A", "Test B"):
            db.add(Team(id=uuid.uuid4(), organization_id=org_id, tournament_id=test_t.id,
                        name=nm, status="APPROVED"))
        db.flush()
        log(f"  + test tournament '{test_name}' (village_wides ON) with 2 teams")

    log(f"\nTeams: {len(existing)} ({created_teams} new, {added_pending} pending, "
        f"{removed_teams} removed)   Fixtures set: {len(matches)} ({created_fixtures} new)")
    if commit:
        db.commit()
        log("Committed. ✔  Remaining matches can be scored live in the app.")
    else:
        db.rollback()
        log("Dry-run only — nothing written. Re-run with --commit to apply.")
    return {"teams": len(existing), "teams_created": created_teams,
            "teams_pending": added_pending, "teams_removed": removed_teams,
            "fixtures": len(matches), "fixtures_created": created_fixtures}


def run(ident, commit):
    db = SessionLocal()
    try:
        t = _find_tournament(db, ident)
        seed_round(db, t, commit=commit)
    finally:
        db.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Backfill completed cricket match results.")
    ap.add_argument("--tournament", default=None,
                    help="Tournament id or name substring (default: the sole ongoing cricket one).")
    ap.add_argument("--commit", action="store_true", help="Apply changes (default is dry-run).")
    args = ap.parse_args()
    run(args.tournament, args.commit)
