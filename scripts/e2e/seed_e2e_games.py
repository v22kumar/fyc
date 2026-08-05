"""Seed the games the end-to-end tests play on, and print their credentials.

The browser and Flutter integration tests drive the real clients against a real
backend. Both need the same thing first: an organisation, two players, and a
game each of them is a side of. Without this the tests cannot run at all, which
is how they quietly stopped being run — so it lives in the repo next to them.

Usage (backend importable, DATABASE_URL pointing at a scratch database):

    python scripts/e2e/seed_e2e_games.py --games 2

Prints one JSON object on stdout; everything else goes to stderr so the caller
can pipe it straight into a test runner.
"""
import argparse
import json
import os
import sys
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "backend"))

from app.core.database import Base, SessionLocal, engine  # noqa: E402
from app.core.security import create_access_token, get_password_hash  # noqa: E402
from app.models.chess import ChessGame  # noqa: E402
from app.models.tenant import Organization  # noqa: E402
from app.models.user import User, UserProfile  # noqa: E402

# Fixed phone numbers so re-running against the same database reuses the same
# two players instead of piling up test accounts.
HOME_PHONE = "+919770000001"
AWAY_PHONE = "+919770000002"


def _member(db, org, name, phone):
    u = db.query(User).filter(User.phone_number == phone).first()
    if u:
        return u
    u = User(
        id=uuid.uuid4(),
        organization_id=org.id,
        phone_number=phone,
        password_hash=get_password_hash("e2e-not-a-real-password"),
        # Deliberately an ordinary member: these tests must exercise what a
        # player can do, never what an organiser can.
        role="USER",
        is_verified=True,
    )
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
    db.commit()
    return u


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", type=int, default=1,
                    help="how many boards to seed (the Flutter suite plays several)")
    ap.add_argument("--time-control", default="rapid_10_0")
    args = ap.parse_args()

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        org = db.query(Organization).first()
        if not org:
            org = Organization(id=uuid.uuid4(), slug="e2e",
                               name_en="E2E Club", name_ta="E2E Club")
            db.add(org)
            db.commit()

        home = _member(db, org, "Web Player", HOME_PHONE)
        away = _member(db, org, "Opponent Bot", AWAY_PHONE)

        game_ids = []
        for _ in range(max(1, args.games)):
            g = ChessGame(
                id=uuid.uuid4(), organization_id=org.id,
                white_id=home.id, black_id=away.id,
                mode="online", status="waiting",
                time_control=args.time_control,
                white_time_ms=600_000, black_time_ms=600_000,
            )
            db.add(g)
            game_ids.append(str(g.id))
        db.commit()

        print(json.dumps({
            "org_id": str(org.id),
            "game_id": game_ids[0],
            "game_ids": game_ids,
            "home_name": "Web Player",
            "web_token": create_access_token(str(home.id), home.role, str(org.id)),
            "opp_token": create_access_token(str(away.id), away.role, str(org.id)),
        }))
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
