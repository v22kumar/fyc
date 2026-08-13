"""Router package bootstrap.

The auth router is loaded here once, then the Google claim extension is applied
before main.py includes the router in FastAPI. This keeps the existing auth
router and browser fallback intact while changing only Google session semantics.
"""

from . import auth
from app.services.google_claim_auth import install as _install_google_claim_auth

_install_google_claim_auth(auth)

__all__ = ["auth"]
