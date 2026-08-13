"""Which user rows are *people the club browses*.

Not every row in `users` is somebody you would put in a list of members. Two
kinds are not:

  * `F2S_IMPORT` — Friends2Support donors, scraped contact records rather than
    members who joined. They belong in donor search and nowhere else.
  * `SIMULATED_BOT` — the chess opponents a load simulation creates. They
    exist to play games at 3am, and they turned up in the club's own member
    list, offered as people to challenge and to appoint.

The rule was written out longhand at eight call sites, each spelling
`(source is null) or (source != 'F2S_IMPORT')` by hand. Adding a second
excluded kind to eight places is how one gets missed, and the one that gets
missed is a bot sitting in the members list. One definition, used everywhere.
"""
from sqlalchemy import or_

# Rows that exist for a purpose other than being a member of this club.
HIDDEN_SOURCES = ("F2S_IMPORT", "SIMULATED_BOT")


def real_people(model):
    """A filter clause: rows that represent somebody the club would list."""
    return or_(model.source.is_(None), model.source.notin_(HIDDEN_SOURCES))
