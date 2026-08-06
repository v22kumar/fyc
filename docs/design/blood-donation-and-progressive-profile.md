# Blood donation, and how we get the data to make it work

Two connected pieces of design. The first is a screen; the second is the reason
the screen will have anything to show.

## The situation, as it actually happens

Someone needs blood. It is usually urgent, usually at a hospital, often at
night. They open the app.

What they must not be given is a hundred contacts and the job of working
through them. That is not help — it is a decision problem handed to the person
least able to solve it, at the worst moment to solve it.

## What the app should do instead

**Sort by distance, because we already know it.** GPS is enabled and donors who
consented have a base location. The list should open ranked by who is *near*,
not alphabetically and not by whoever registered first.

**Then availability.** Near and available is the pair that matters. Everything
else is detail.

**One tap sends a request, not a phone call.** The requester should not be
cold-calling strangers. They ask; the donor accepts or does not.

**Emergency broadcasts to everyone.** One button, one message to the whole club,
and people accept. Once someone accepts, the two of them sort out the rest
between themselves — which hospital, when, who drives. The app's job ends at
"someone accepted". It should not try to manage a donation.

**Everything on one page.** The map is currently its own screen, which means
nobody will ever open it. Map, nearby list and request belong together: tap a
person and see where they are, how far, their number and their age, without
leaving.

Age and phone matter here and we already hold both — `UserProfile.date_of_birth`
and the user's number. A donor's age is one of the first things a hospital asks.

### What already exists and is simply unused

- `GET /blood-donors/nearby` — ranks by real distance from a lat/lng, widens to
  compatible blood groups, and filters to donors currently eligible. The app
  never calls it; it calls the plain list instead.
- `POST /blood-donors/{id}/request-contact` — reveals a number and audit-logs
  who took it.
- `BloodDonor.latitude/longitude/location_consent`, `last_donation_date`
  (eligibility), `notify_opt_in`.
- `UserProfile.date_of_birth`, `UserProfile.blood_group`.

The plumbing was built and the screen was never rewired to it. That is the
whole gap.

## The second piece: ask for data later, a little at a time

Registration deliberately does not ask for blood group. That is the right call —
a long signup form loses people, and the club would rather have a member with a
thin profile than no member at all.

But it leaves us without the one field the blood feature depends on.

So: **ask afterwards, one question at a time, spaced out.** Every couple of
days, a single question, answerable in one tap:

- What is your blood group?
- Which area do you live in?
- What did you study?
- Would you help at events?

One question is not a form. It reads as the app taking an interest rather than
demanding paperwork, and it can be dismissed without cost. Over a year it
produces a community dataset the club could never have collected at signup —
and the blood feature stops depending on a field nobody filled in.

Rules that keep it from becoming a nuisance:

- One question at a time, never a queue.
- A minimum gap between questions (days, not hours).
- Dismissing is free and the question goes to the back.
- Never ask something already answered.
- Never block anything on an answer.

## Order of work

1. Wire the app to `/nearby` so the default view is GPS-ranked. Add age to the
   donor payload.
2. Bring the map onto the page: list and map together, tap-to-locate.
3. Request-to-donate as the card's action, replacing the call button.
4. Emergency broadcast with accept, reusing the push stack the chess feature
   already uses.
5. Progressive profiling, starting with blood group — the field the rest of
   this depends on.

---

# Architecture: who decides, and where the answers live

Two questions, raised after the first version was built. Both change the design.

## 1. The app should decide when to ask, not the server

The first version asked the server on every app open: *what should I ask this
member now?* The answer is almost always "nothing", so that is a round trip per
launch per member, to be told to do nothing.

It is also unnecessary. Deciding whether to ask is a pure function of facts the
app already has, or could have: which questions this member has answered, which
they pushed away, and when they were last asked anything. None of that needs a
server to work out.

**So the server stops deciding and starts publishing.**

- The server serves a **catalogue** — the list of questions, their options, their
  order. It changes rarely, so it is cached with an ETag and re-fetched only when
  it actually changes.
- The app keeps its own record of what has been asked and answered, and applies
  the cadence rules locally. No network call to decide anything.
- The app **posts answers up** when it has one — batched, fire-and-forget.

The load goes from *one read per app open* to *one small cached read per
catalogue change, plus one write per answer given*. With a hundred members
opening the app a few times a day, that is the difference between thousands of
requests and a few dozen.

Two honest costs, and what to do about them:

- **Local state can be lost** — a reinstall, or a second device. The catalogue
  response therefore includes the ids this member has already answered, so a
  fresh install reconciles once and does not re-ask what is known.
- **Two devices can both ask the same thing.** Rare, harmless, and the
  reconciliation above closes it on the next fetch. Not worth a distributed lock.

## 2. How the data stays expandable

The worry is right: if every new question means a new column, then every
question means a migration, and `user_profiles` grows a column per question,
almost all of them NULL. That does not scale, and it makes asking a new question
a deployment rather than a config change.

But the opposite — everything in one loose bag — is also wrong: you cannot index
it, you cannot filter on it, and the donor search needs to filter on blood group.

**So: two tiers, with an explicit rule for moving between them.**

### Tier 1 — promoted columns

A real column on `user_profiles`. Deliberately few. Today: `blood_group`,
`gender`, `date_of_birth`.

A field earns a column when **a feature needs to query, filter, sort or index
by it**. Blood group qualifies: the donor search filters on it and it is
indexed. Education does not — nobody searches members by degree.

### Tier 2 — the attribute store

Everything else: one row per answer, keyed by question id.

    profile_attributes(user_id, key, value, answered_at)

Unbounded keys. A new question is a new *row*, never a new column, so adding one
is a catalogue edit and not a migration. Per-answer timestamps come free, which a
JSON blob would not give — and they matter, because "what did the club look like
last year" is a question worth being able to answer.

### Promotion, when it is earned

When a feature finally needs to filter on something in tier 2 — say the club
wants to find every member who offered to teach — that key is promoted: add the
column, backfill from the attribute rows, and point the reader at the column.
One migration, once, driven by a real need rather than a guess.

This is the part worth being disciplined about. The temptation is to promote
everything "in case", and that is how `user_profiles` becomes eighty mostly-empty
columns. The rule is: **no column without a query that needs it.**

### Where this leaves what is already built

`profile_prompt_states` already stores an answer per question per member, so
tier 2 exists in all but name — it is currently mixed in with the scheduling
bookkeeping. Splitting the answer out into `profile_attributes` separates "what
we know about this member" from "what we have asked them", which are different
things with different lifetimes: the bookkeeping can be reset, the knowledge
should not be.
