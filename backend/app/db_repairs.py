"""One-off, idempotent schema repairs for the long-lived production SQLite.

`create_all` and the column-level reconcile in `main.py` can add missing tables
and columns, but they can never rewrite an existing table's FOREIGN KEY
constraints — SQLite bakes those into the CREATE TABLE statement. When a model's
FK target changes, the live table keeps enforcing the old one. These helpers
rebuild such tables.
"""
import logging

from sqlalchemy import inspect, text
from sqlalchemy.schema import CreateTable

logger = logging.getLogger(__name__)


def repair_cricket_balls_fk(engine) -> bool:
    """Rebuild `cricket_balls` if its player FKs still point at the removed
    `cricket_players` table.

    The cricket-scoring feature repointed striker/non_striker/bowler/dismissed
    FKs from `cricket_players` to the central `players` table, but the prod table
    was created under the old schema. With `PRAGMA foreign_keys=ON`, every ball
    insert (which uses `players.id`) then fails with "FOREIGN KEY constraint
    failed" — surfaced in the app as "Unable to record this ball."

    Returns True if a rebuild was performed. No-op on non-SQLite engines and when
    the FK is already correct, so it is safe to run on every startup.
    """
    if engine.dialect.name != "sqlite":
        return False

    insp = inspect(engine)
    if not insp.has_table("cricket_balls"):
        return False

    # Import here to avoid an import cycle at module load.
    from app.models.cricket import CricketBall

    with engine.connect() as conn:
        fks = conn.execute(text("PRAGMA foreign_key_list('cricket_balls')")).fetchall()
        # PRAGMA foreign_key_list columns: id, seq, table, from, to, on_update, ...
        stale = any((row[2] or "").lower() == "cricket_players" for row in fks)
    if not stale:
        return False

    live_cols = {c["name"] for c in insp.get_columns("cricket_balls")}
    # Only copy columns that exist in BOTH the old table and the new model.
    common = [c.name for c in CricketBall.__table__.columns if c.name in live_cols]
    collist = ", ".join(f'"{c}"' for c in common)
    create_sql = str(CreateTable(CricketBall.__table__).compile(engine))

    # Toggle FK enforcement off for the rebuild (must be outside a transaction),
    # so any orphaned legacy rows copy across instead of blocking startup.
    raw = engine.raw_connection()
    try:
        cur = raw.cursor()
        cur.execute("PRAGMA foreign_keys=OFF")
        cur.execute("BEGIN")
        cur.execute("ALTER TABLE cricket_balls RENAME TO _cricket_balls_stale")
        cur.execute(create_sql)
        cur.execute(
            f"INSERT INTO cricket_balls ({collist}) "
            f"SELECT {collist} FROM _cricket_balls_stale"
        )
        cur.execute("DROP TABLE _cricket_balls_stale")
        raw.commit()
        cur.execute("PRAGMA foreign_keys=ON")
    finally:
        raw.close()

    logger.info("[schema-repair] rebuilt cricket_balls with FK -> players")
    return True
