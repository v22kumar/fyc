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
    db.add(org)
    db.commit()
    t = Tournament(id=uuid.uuid4(), organization_id=org.id, name_ta="லீக்",
                   name_en="Test League", sport="cricket", year=2026, status="ONGOING")
    db.add(t)
    db.commit()
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
    seed.seed_round(db, t, ROUND, commit=True, log=_mute, pending_teams=[])

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

    seed.seed_round(db, t, ROUND, commit=True, log=_mute, pending_teams=[])
    fyc = db.query(Team).filter(Team.tournament_id == t.id, Team.name == "FYC B").all()
    assert len(fyc) == 1
    assert fyc[0].wins == 1


def test_idempotent_rerun(db):
    t = _tournament(db)
    seed.seed_round(db, t, ROUND, commit=True, log=_mute, pending_teams=[])
    seed.seed_round(db, t, ROUND, commit=True, log=_mute, pending_teams=[])

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
    db.add(a)
    db.add(b)
    db.commit()
    ph = Fixture(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id,
                 team_a_id=a.id, team_b_id=b.id, match_number=99, status="SCHEDULED")
    db.add(ph)
    db.commit()

    seed.seed_round(db, t, ROUND, commit=True, log=_mute, pending_teams=[])
    kept = db.query(Fixture).filter(Fixture.match_number == 99).first()
    assert kept is not None and kept.status == "SCHEDULED"


def test_fills_scheduled_fixture_with_same_number(db):
    """A pre-existing SCHEDULED fixture that shares a match number with the round
    is filled in (placeholder -> completed), not duplicated."""
    t = _tournament(db)
    x = Team(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id, name="Alpha", status="APPROVED")
    y = Team(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id, name="Beta", status="APPROVED")
    db.add(x)
    db.add(y)
    db.commit()
    ph = Fixture(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id,
                 team_a_id=x.id, team_b_id=y.id, match_number=1, status="SCHEDULED")
    db.add(ph)
    db.commit()

    seed.seed_round(db, t, ROUND, commit=True, log=_mute, pending_teams=[])
    fixtures_1 = db.query(Fixture).filter(Fixture.tournament_id == t.id, Fixture.match_number == 1).all()
    assert len(fixtures_1) == 1
    assert fixtures_1[0].status == "COMPLETED"


def test_removes_junk_team_and_its_fixture(db):
    """A team in REMOVE_TEAMS (a misspelling) is deleted along with any fixture
    that references it, before seeding."""
    t = _tournament(db)
    junk = Team(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id,
                name="NMC pandaraparambu", status="APPROVED")
    other = Team(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id,
                 name="FYC B", status="APPROVED")
    db.add(junk)
    db.add(other)
    db.commit()
    placeholder = Fixture(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id,
                          team_a_id=other.id, team_b_id=junk.id, match_number=50, status="SCHEDULED")
    db.add(placeholder)
    db.commit()
    junk_id = junk.id
    ph_id = placeholder.id

    result = seed.seed_round(db, t, ROUND, commit=True, log=_mute, pending_teams=[])
    assert result["teams_removed"] == 1
    assert db.query(Team).filter(Team.id == junk_id).first() is None
    assert db.query(Fixture).filter(Fixture.id == ph_id).first() is None
    # FYC B (a real team) is untouched and reusable.
    assert db.query(Team).filter(Team.tournament_id == t.id, Team.name == "FYC B").count() == 1


def test_pending_teams_added_without_downgrading_existing(db):
    """PENDING_TEAMS are created with status PENDING and no fixtures; a team that
    already exists (approved) keeps its status."""
    t = _tournament(db)
    # 'FYC A' pre-exists as APPROVED (it's in PENDING_TEAMS but must not downgrade)
    db.add(Team(id=uuid.uuid4(), organization_id=t.organization_id,
                tournament_id=t.id, name="FYC A", status="APPROVED"))
    db.commit()

    seed.seed_round(db, t, ROUND, commit=True, log=_mute)  # default PENDING_TEAMS

    fyc_a = db.query(Team).filter(Team.tournament_id == t.id, Team.name == "FYC A").one()
    assert fyc_a.status == "APPROVED"  # untouched, not downgraded
    for name in ["Kollamcode", "Thozikode", "Marthandam", "Irenipuram", "Karungal"]:
        tm = db.query(Team).filter(Team.tournament_id == t.id, Team.name == name).one()
        assert tm.status == "PENDING"
        # a pending team is in no fixture
        assert db.query(Fixture).filter(
            (Fixture.team_a_id == tm.id) | (Fixture.team_b_id == tm.id)).count() == 0


def test_aborts_on_conflicting_completed_fixture(db):
    """If match #1 is already COMPLETED with a different result, the backfill
    aborts instead of silently corrupting standings."""
    import pytest
    t = _tournament(db)
    p = Team(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id, name="P", status="APPROVED")
    q = Team(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id, name="Q", status="APPROVED")
    db.add(p)
    db.add(q)
    db.commit()
    done = Fixture(id=uuid.uuid4(), organization_id=t.organization_id, tournament_id=t.id,
                   team_a_id=p.id, team_b_id=q.id, match_number=1, status="COMPLETED",
                   winner_id=p.id, team_a_score="50/2", team_b_score="49/10")
    db.add(done)
    db.commit()

    with pytest.raises(SystemExit):
        seed.seed_round(db, t, ROUND, commit=True, log=_mute, pending_teams=[])
