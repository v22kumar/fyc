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

- [ ] **Escalation in motion** — Lane A one rung up after the wait elapses,
      quoting the previous letter and the logged calls. The pieces exist: the
      ladder, `wait_days` per rung, and the call records the letter already
      quotes. What is missing is the thing that notices the clock ran out.
- [ ] **Lane B triage actions** — the reviewer's queue screen exists; forwarding
      from it, and the club-authored timeline entries that follow, do not.
- [ ] **Honest statistics** — last, and only above about twenty complaints.
      Rules written in the architecture §10; nothing implemented, which is
      correct for now since there is no sample.
- [ ] **Photo as a real attachment.** The letter carries the photo as a URL,
      which is better for an officer reading on a phone but does mean the
      picture lives behind a link. An `ACTION_SEND` intent could attach it;
      `mailto:` cannot.

## Done

- [x] Directory, ladders, jurisdiction resolution
- [x] `GET /civic/ladder` — the whole route for one complaint, nearest first,
      with `can_call` and `can_write` answered separately
- [x] Collectorate contacts parsed and imported, with provenance
- [x] **`ComplaintEvent`** — the authored timeline. Every row names who said it,
      which is what lets the interface avoid asserting anything nobody stated.
- [x] **Letter template** — skeleton in code, two model-filled slots, a Maps
      link instead of coordinates, and no club sign-off on the member's letter.
      Works with the model unavailable.
- [x] **Call logging**, and the paragraph it produces in the next letter.
- [x] **Draft and hand-off** to the member's own mail app, with the disclosed
      BCC switch and the single "did you send it?" question.
- [x] **Mark resolved / mark closed**, the lock, and one-tap reopen.
- [x] **Severity** — asked once at capture, steers the next screen, CCs the
      supervisor on serious complaints, halves the wait.
- [x] **Hand to FYC** — the lane switch.
- [x] **The Flutter feature** — `data/ domain/ presentation/` with a bloc, in
      the same shape as blood donation. All strings in the four-language
      registry.
- [x] Capture flows straight into the Complaint Box rather than a list.

## Decisions already made, so nobody reopens them by accident

- The **member sends**, from their own mail. The club drafts. (Liability, spam,
  deliverability, registration — all at once.)
- **Email intent**, not the Gmail API. `gmail.send` is a restricted scope
  needing a paid assessment.
- **BCC to the club, default on and disclosed.** Not silent.
- **The whole ladder is shown**, never one office.
- **No rate whose denominator contains things we did not observe.**

## Verified

- Backend: 22 tests across the endpoints and the letter.
- Mobile: 8 bloc tests; `flutter analyze` clean.
- Not verified on a device or against a real government mailbox. Nobody has
  yet sent a letter written by this to an actual officer.

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
- The send sheet uses `mailto:`, which every device with a mail app handles but
  which cannot attach a file and breaks on very long bodies. The letter is
  trimmed at 4000 characters to stay inside that. An `ACTION_SEND` intent is
  the upgrade when the photo needs to travel as an attachment.
- `CLUB_COMPLAINT_BCC` is unset, so the blind copy is disclosed in the UI but
  goes nowhere until somebody configures an address. The switch will show as on
  with an empty `bcc` list — harmless, but it means the escalation clock cannot
  start by itself yet.
- Sending from the club's mailbox is still not built at all, only decided. The
  narrow exception for members with no email address has no code.
