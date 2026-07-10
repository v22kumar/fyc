"""Regression: the live cricket_balls table was created with player FKs pointing
at the removed `cricket_players` table. With PRAGMA foreign_keys=ON every ball
insert failed ("Unable to record this ball. Database constraint failed."). The
startup repair rebuilds the table with FKs to `players`.

This reproduces the stale-FK table on a throwaway SQLite file and asserts the
repair repoints the FKs and preserves existing rows.
"""
import uuid

from sqlalchemy import create_engine, text

from app.db_repairs import repair_cricket_balls_fk


# The stale table as the old model created it: same columns the current model
# has, but striker/non_striker/bowler FKs reference cricket_players.
_OLD_CRICKET_BALLS = """
CREATE TABLE cricket_balls (
    id CHAR(32) NOT NULL PRIMARY KEY,
    match_id CHAR(32) NOT NULL,
    innings_number INTEGER NOT NULL,
    ball_index INTEGER NOT NULL,
    striker_id CHAR(32) NOT NULL,
    non_striker_id CHAR(32) NOT NULL,
    bowler_id CHAR(32) NOT NULL,
    runs_batter INTEGER,
    extras_type VARCHAR(20),
    extras_runs INTEGER,
    is_wicket BOOLEAN,
    wicket_type VARCHAR(50),
    player_dismissed_id CHAR(32),
    scorer_id CHAR(32),
    edit_history JSON,
    notes VARCHAR(500),
    organization_id CHAR(32),
    created_at DATETIME,
    updated_at DATETIME,
    FOREIGN KEY(striker_id) REFERENCES cricket_players(id),
    FOREIGN KEY(non_striker_id) REFERENCES cricket_players(id),
    FOREIGN KEY(bowler_id) REFERENCES cricket_players(id),
    FOREIGN KEY(player_dismissed_id) REFERENCES cricket_players(id)
)
"""


def _fk_targets(engine):
    with engine.connect() as c:
        rows = c.execute(text("PRAGMA foreign_key_list('cricket_balls')")).fetchall()
    return {(r[2] or "").lower() for r in rows}


def test_repair_repoints_cricket_balls_fk_and_preserves_rows(tmp_path):
    db_file = tmp_path / "prod_like.db"
    engine = create_engine(f"sqlite:///{db_file}")

    raw = engine.raw_connection()
    try:
        cur = raw.cursor()
        cur.execute("PRAGMA foreign_keys=OFF")
        cur.execute("CREATE TABLE cricket_players (id CHAR(32) NOT NULL PRIMARY KEY)")
        cur.execute(_OLD_CRICKET_BALLS)
        # A legacy row (as if scored while FK enforcement was off). It must survive.
        cur.execute(
            "INSERT INTO cricket_balls (id, match_id, innings_number, ball_index, "
            "striker_id, non_striker_id, bowler_id, runs_batter, "
            "organization_id, created_at, updated_at) "
            "VALUES (?,?,?,?,?,?,?,?, ?, datetime('now'), datetime('now'))",
            (uuid.uuid4().hex, uuid.uuid4().hex, 1, 1,
             uuid.uuid4().hex, uuid.uuid4().hex, uuid.uuid4().hex, 4,
             uuid.uuid4().hex),
        )
        raw.commit()
    finally:
        raw.close()

    # Precondition: the stale FK targets cricket_players.
    assert "cricket_players" in _fk_targets(engine)

    # Repair.
    assert repair_cricket_balls_fk(engine) is True

    # FKs now target players, not the removed cricket_players table.
    targets = _fk_targets(engine)
    assert "players" in targets
    assert "cricket_players" not in targets

    # The existing row was preserved through the rebuild.
    with engine.connect() as c:
        n = c.execute(text("SELECT COUNT(*) FROM cricket_balls")).scalar()
    assert n == 1

    # Idempotent: a second run finds nothing stale and is a no-op.
    assert repair_cricket_balls_fk(engine) is False
    engine.dispose()


def test_repair_noop_when_table_absent_or_correct(tmp_path):
    # No cricket_balls table at all → no-op.
    e1 = create_engine(f"sqlite:///{tmp_path / 'empty.db'}")
    assert repair_cricket_balls_fk(e1) is False
    e1.dispose()

    # A table already pointing at players → no-op.
    e2 = create_engine(f"sqlite:///{tmp_path / 'ok.db'}")
    raw = e2.raw_connection()
    try:
        cur = raw.cursor()
        cur.execute("CREATE TABLE players (id CHAR(32) NOT NULL PRIMARY KEY)")
        cur.execute(
            "CREATE TABLE cricket_balls ("
            "id CHAR(32) NOT NULL PRIMARY KEY, striker_id CHAR(32), "
            "FOREIGN KEY(striker_id) REFERENCES players(id))"
        )
        raw.commit()
    finally:
        raw.close()
    assert repair_cricket_balls_fk(e2) is False
    e2.dispose()
