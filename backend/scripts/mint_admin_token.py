#!/usr/bin/env python3
"""Print a valid admin JWT for the deployed backend — run INSIDE the container
(it has SECRET_KEY + DATABASE_URL), e.g. for load-test metrics/health calls:

    flyctl ssh console -a fyc-backend -C "python /app/scripts/mint_admin_token.py"

Prints ONLY the token on stdout. Picks an existing SUPER_ADMIN/ADMIN user.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal          # noqa: E402
from app.core.security import create_access_token   # noqa: E402
from app.models.user import User                    # noqa: E402


def main():
    with SessionLocal() as s:
        u = (
            s.query(User)
            .filter(User.role.in_(["SUPER_ADMIN", "ADMIN"]))
            .first()
        )
        if not u:
            print("NO_ADMIN_USER_FOUND", file=sys.stderr)
            sys.exit(1)
        print(create_access_token(subject=str(u.id), role=u.role,
                                   organization_id=str(u.organization_id)))


if __name__ == "__main__":
    main()
