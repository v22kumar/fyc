# Complaint Box — what is left

Working notes. The architecture is in `complaint-box-architecture.md`; this is
the running list of what it still needs, and what is knowingly unfinished.

Add to it rather than keeping it in your head.

## Blocked on data, not code

**22 of 39 offices have no contact.** The Collectorate page covered 17
(`seeds/civic_contacts.worksheet.json`, imported 7 Aug 2026). The rest are not
on a district page at all:

- **Ward councillors** — Nagercoil Corporation ward list
- **Village panchayat presidents and ward members** — the largest gap, and the
  one that matters most for potholes and street lights, because these are the
  people who actually get them fixed
- **TANGEDCO section offices** — the first rung for a power cut
- **TNPCB District Environmental Engineer** — the Collectorate page has one
  Pollution Control row and it is not this desk
- **PWD / TWAD / Health** — officers are listed with phones but no published
  email, so they can be rung and not written to

Every one needs a source URL and the date a human read it. The worksheet is the
place; `scripts/import_civic_contacts.py` checks it.

## Built, deliberately switched off

- **Sending from the club's own mailbox.** The club decides whether it wants to
  be the sender of record. Off by default; when on, needs a named organiser and
  a per-week cap.

## Not started

Roughly in the order the architecture proposes.

- [ ] **Letter template** — skeleton in code, two slots for the model. Removes
      the *"Submitted via FYC Connect"* footer, which in Lane A is false.
- [ ] **Location as a place name and a Maps link** rather than coordinates.
- [ ] **Capture screen** — photo first, description, location confirm, one
      severity question.
- [ ] **Routes screen** — call / write yourself / hand to FYC, steered by
      severity.
- [ ] **Call logging** — *reached / no answer / promised to act*, and the line
      it produces for a later letter.
- [ ] **Draft and hand-off** to the member's own mail app, with the disclosed
      BCC switch.
- [ ] **Member-owned timeline** — every row names its author.
- [ ] **Mark resolved / mark closed**, and the lock that follows.
- [ ] **Severity steering** — serious goes by mail, CC the next rung, 7-day
      clock instead of 14.
- [ ] **Lane B** — the club inbox, triage, forward.
- [ ] **Escalation** — Lane A one rung up, quoting the previous letter and the
      logged calls.
- [ ] **Honest statistics** — last, and only above about twenty complaints.

## Done

- [x] Directory, ladders, jurisdiction resolution
- [x] `GET /civic/ladder` — the whole route for one complaint, nearest first,
      with `can_call` and `can_write` answered separately
- [x] Collectorate contacts parsed and imported, with provenance

## Decisions already made, so nobody reopens them by accident

- The **member sends**, from their own mail. The club drafts. (Liability, spam,
  deliverability, registration — all at once.)
- **Email intent**, not the Gmail API. `gmail.send` is a restricted scope
  needing a paid assessment.
- **BCC to the club, default on and disclosed.** Not silent.
- **The whole ladder is shown**, never one office.
- **No rate whose denominator contains things we did not observe.**

## Known rough edges

- `can_call` / `can_write` are computed per request from the Authority row.
  Fine now; if the ladder screen gets slow, it is the first thing to cache.
- The `_COVERS` map in `civic.py` translates rung numbers into words like
  *"your ward"*. It is currently English and Tamil only, unlike the rest of the
  app, which does four languages through the registry. Move it there when the
  screen exists to show it.
- `GET /civic/ladder` resolves jurisdiction from the reporter's own geography
  when the report has no tag. Right most of the time, wrong for somebody
  reporting a pothole outside their ward. Coordinates would fix it and need
  boundary data the project does not have.
