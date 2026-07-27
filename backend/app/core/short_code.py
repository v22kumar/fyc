"""Short, human-typeable public share codes for events and tournaments.

A full UUID (…/event-detail?id=92e2d2ae-e755-…) is impossible to read aloud or
type onto a printed notice or banner. Instead every shareable entity gets a tiny
code like ``K7P2`` so the public link becomes ``fyc-web.fly.dev/e/K7P2``.

The alphabet excludes visually ambiguous characters (0/O, 1/I/L) so a code can be
copied off a poster without confusion. 5 chars over a 32-symbol alphabet is ~33M
combinations — far more than this club will ever need — and we retry on the rare
collision anyway.
"""
import secrets

# Crockford-style: no 0 O 1 I L to keep codes unambiguous in print.
_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"


def random_code(length: int = 5) -> str:
    return "".join(secrets.choice(_ALPHABET) for _ in range(length))


def generate_unique_short_code(db, model, length: int = 5, attempts: int = 12) -> str:
    """Return a `short_code` not yet used by `model`.

    `model` must expose `id` and `short_code` columns. Retries on collision and
    widens the code length if it somehow keeps colliding, so this always returns.
    """
    for i in range(attempts):
        code = random_code(length)
        exists = db.query(model.id).filter(model.short_code == code).first()
        if exists is None:
            return code
        if i and i % 4 == 0:
            length += 1  # space is crowded (or tiny test DB) — widen
    return random_code(length + 2)
