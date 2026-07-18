"""Guards the tournament-results backfill script (scripts/seed_tournament_results.py)
against model drift: idempotency, alias de-duplication, non-destructiveness,
dry-run safety, and standings.
"""
import uuid
import importlib

from app.models.tenant import Organization
from app.models.sports import Tournament, Team, Fixture

seed = importlib.import_module("scripts.seed_tournament_results")

# A tiny two-match round that exercises the alias ("7YC B" -> "FYC B").
ROUND = [
    dict(no=1, a="Alpha", a_score="80/5 (10.0 ov)", b="Beta", b_score="81/2 (9.0 ov)",
         winner="Beta", notes="Beta won by 8 wickets"),
    dict(no=2, a="Gamma", a_score="60/10 (9.0 ov)", b="7YC B", b_score="61/1 (7.0 ov)",
         winner="7YC B", notes="FYC B won by 9 wickets"),
]


def _tournament(db):
    org = Organization(id=uuid.uuid4(), slug=f"t-{uuid.uuid4().hex[:6]}", name_ta="அ", name_en="Org")
    db.add(org); db.commit()
    t = Tournament(id=uuid.uuid4(), organization_id=org.id, name_ta="லீக்",
                   name_en="Test League", sport="cricket", year=2026, status="ONGOING")
    db.add(t); db.commit()
    return t


def _mute(*a, **k):
    pass


def test_dry_run_writes_nothing(db):
    t = _tournament(db)
    tid = t.id  # capture before the dry-run rollback expires `t`
    seed.seed_round(db, t, ROUND, commit=False, log=_mute)
    assert db.query(Fixture).filter(Fixture.tournament_id == tid).count() == 0
    assert db.query(Team).filter(Team.tournament_id == tid).count() == 0


def test_commit_creates_teams_fixtures_and_standings(db):
    t = _tournament(db)
    seed.seed_round(db, t, ROUND, commit=True, log=_mute)

    teams = db.query(Team).filter(Team.tournament_id == t.id).all()
    assert len(teams) == 4  # Alpha, Beta, Gamma, FYC B
    fixtures = db.query(Fixture).filter(Fixture.tournament_id == t.id).all()
    assert len(fixtures) == 2
    assert all(f.status == "COMPLETED" and f.winner_id for f in fixtures)

    beta = next(tm for tm in teams if tm.name == "Beta")
    assert beta.wins == 1 and beta.points == 3
    alpha = next(tm for tm in teams if tm.name == "Alpha")
    assert alpha.losses == 1


def test_alias_deduplicates(db):
    """A team already present under the canonical name must be reused, not
    duplicated, when the scoreboard uses a spelling variant ("7YC B")."""
    t = _tournament(db)
    db.add(Team(id=uuid.uuid4(), organization_id=t.organization_id,
                tournament_id=t.id, name="FYC B", status="APPROVED"))
    db.commit()

    seed.seed_round(db, t, ROUND, commit=True, log=_mute)
    fyc = db.query(Team).filter(Team.tournament_id == t.id, Team.name == "FYC B").all()
    assert len(fyc) == 1
    assert fyc[0].wins == 1


def test_idempotent_rerun(db):
    t = _tournament(db)
    seed.seed_round(db, t, ROUND, commit=True, log=_mute)
    seed.seed_round(db, t, ROUND, commit=True, log=_mute)

    assert db.query(Team).filter(Team.tournament_id == t.id).count() == 4
    assert db.query(Fixture).filter(Fixture.tournament_id == t.id).count() == 2
    beta = db.query(Team).filter(Team.tournament_id == t.id, Team.name == "Beta").first()
    assert beta.wins == 1  # not double-counted


def test_non_destructive_to_existing_fixture(db):
    """A pre-existing (placeholder) fixture with a different match_number is left
    untouched."""
    t = _tournament(db)
    a = Team(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id, name="X", status="APPROVED")
    b = Team(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id, name="Y", status="APPROVED")
    db.add(a); db.add(b); db.commit()
    ph = Fixture(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id,
                 team_a_id=a.id, team_b_id=b.id, match_number=99, status="SCHEDULED")
    db.add(ph); db.commit()

    seed.seed_round(db, t, ROUND, commit=True, log=_mute)
    kept = db.query(Fixture).filter(Fixture.match_number == 99).first()
    assert kept is not None and kept.status == "SCHEDULED"
