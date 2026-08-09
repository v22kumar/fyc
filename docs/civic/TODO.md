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
- [x] **"My complaints"** — `GET /civic/complaints` and the screen on it.
      Replaced the old track screen, which listed issues by a status column the
      server maintained by inference: a complaint nobody had touched read
      "Under review", which was nobody's statement. Rows now say what somebody
      said, ordered open-first then longest-ignored-first.
- [x] **Coverage** — a complaint from outside Kanniyakumari gets no ladder and
      is told why. It used to be handed four officers in Nagercoil.
- [x] **The feature has one name.** Home, the More sheet, the create sheet and
      the profile menu called it Report an Issue, Public Issues, Track Issues
      and My Reports. All four now say Complaint Box / My complaints.

## Decisions already made, so nobody reopens them by accident

- The **member sends**, from their own mail. The club drafts. (Liability, spam,
  deliverability, registration — all at once.)
- **Email intent**, not the Gmail API. `gmail.send` is a restricted scope
  needing a paid assessment.
- **BCC to the club, default on and disclosed.** Not silent.
- **The whole ladder is shown**, never one office.
- **No rate whose denominator contains things we did not observe.**

## Verified

- Backend: 491 tests, 22 of them the Complaint Box and the letter.
- Mobile: 120 tests, 8 of them the bloc; `flutter analyze` clean.
- The whole journey walked against a running server: report → ladder → ring
  somebody → say what happened → write → confirm sent → mark resolved → and a
  closed complaint refusing the next event with a 409. The letter came out with
  the logged call quoted, a Maps link, the member's own name, and the club's
  blind copy.
- **Not** run on a device, and nobody has yet sent a letter written by this to a
  real officer. Until that happens it is theory that passes its own tests.

## Dead code to decide about

`submit_issue_screen.dart` is now unreachable — nothing routes to it. It is the
older reporting flow, and it contradicts what was decided since: it asks for
the same description twice in two languages, tells the member the app will
"auto mail to department" when the club no longer sends anything, and opens
with a resolution rate computed from two reports.

Left in place rather than deleted, because removing a six-hundred-line screen
is a separate decision from fixing a route. But it should go: dead code that
contradicts the product is how the contradiction comes back.

`issues_track_screen.dart`, `issue_detail_screen.dart` and the two blocs behind
them **have** gone, for exactly that reason: both asserted a status nobody had
stated, and leaving them registered in the service locator would have kept two
contradicting screens compiling and looking maintained.

## Known rough edges

- `can_call` / `can_write` are computed per request from the Authority row.
  Fine now; if the ladder screen gets slow, it is the first thing to cache.
- The `_COVERS` map in `civic.py` translates rung numbers into words like
  *"your ward"*. It is currently English and Tamil only, unlike the rest of the
  app, which does four languages through the registry. Move it there when the
  screen exists to show it.
- `GET /civic/ladder` now takes `complaint_id` and resolves jurisdiction from
  the report's own geography, falling back to the reporter's. What it still
  cannot do is turn a coordinate into a local body — that needs boundary data
  the project does not have. Coverage is a bounding box (`jurisdiction.
  is_covered`), drawn generously: it catches Bengaluru, not a village on the
  Tirunelveli line. Being wrong at the margin means offering the ladder to
  somebody just outside it, which is the cheaper error.
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
