# Work — the screens, and why

*Designed from what a person is feeling when they open it, because that
decides the endpoints rather than the other way round.*

---

## Two intents, wildly unequal

**"I need somebody to fix my door."** Urgent, specific, and they want a phone
number inside ten seconds. This is almost all the traffic.

**"I want to be findable."** Done once, then forgotten. Rare, but the whole
index depends on it happening.

Designing both into one screen with equal weight would serve neither. So: one
destination, two modes, stated at the top and never mixed in a list. A person
looking to hire does not want to scroll past other people looking to hire.

## The four feelings that decide everything

**They are afraid of being cheated.** The strongest finding in the research —
users fear "fraudulent hiring traps" above all else. Every card has to answer
*can I trust this?* before being asked. Not with a five-star average, which
people game and nobody believes, but with facts: verified number, member since,
jobs confirmed.

**They scan, they do not read.** Twenty results get reduced to three in a few
seconds, on name, distance and trust. Anything else on the card is noise
competing with the number they came for.

**An empty category is fatal.** A person who taps *Plumbing* and finds nothing
concludes the entire app is empty and does not come back. Categories with no
listings must never be offered as if they were full.

**The person who lists has fragile motivation.** They register once. If nothing
visibly happens they conclude it did not work and never return. They must be
shown something true — *seen by 12 people this week* — or the supply side
quietly dies.

---

## Screen 1 — Work

The single place. Skills, jobs and gigs all arrive here.

    ┌─────────────────────────────────┐
    │  Work                           │
    │  ┌───────────────────────────┐  │
    │  │ 🔍 Carpenter, tuition…    │  │   free text first: people
    │  └───────────────────────────┘  │   arrive with a word in mind
    │                                 │
    │  [ Find someone ] [ Find work ] │   two intents, never mixed
    │                                 │
    │  Near you                       │
    │  ┌────────┐ ┌────────┐          │
    │  │Carpentry│ │ Mobile │  …      │   only categories with
    │  │   12   │ │   8    │          │   somebody in them, count shown
    │  └────────┘ └────────┘          │
    │                                 │
    │  ▸ List what you do             │   quiet, always reachable
    └─────────────────────────────────┘

**Search is above categories** because a person arrives already knowing the
word — "carpenter" — and making them find it in a grid is a step for our
convenience, not theirs.

**Counts on every category, and empty ones are not shown.** A tile reading
*Plumbing 0* is an advertisement that the app does not work.

## Screen 2 — Results

    ┌─────────────────────────────────┐
    │  Carpentry · 12                 │
    │                                 │
    │  Murugan A.                     │
    │  Vadasery · interlock, doors    │
    │  ✓ Number verified              │   the trust line, always
    │  9 jobs done · member 4 years   │   present, never a rating
    │  ┌──────────┐ ┌──────────────┐  │
    │  │ 📞 Call  │ │  WhatsApp    │  │
    │  └──────────┘ └──────────────┘  │
    ├─────────────────────────────────┤
    │  Selvam Furniture               │
    │  ● Open now · Putheri           │
    │  New — no jobs through the app  │   honest, not hidden
    │  ┌──────────┐ ┌──────────────┐  │
    └─────────────────────────────────┘

**The number is one tap from the list**, not behind a detail screen. Somebody
whose door is broken should not have to open a profile to make a call.

**A new listing says so.** Pretending a blank record is a good record is how a
directory loses the trust that is its only asset.

## Screen 3 — The listing

Everything, once they have decided to look closer. Free text in full, the work
record as a list of confirmed jobs, hours and address for a shop, and — at the
bottom, quiet but findable — **Report this listing**.

## Screen 4 — List what you do

The supply side, done once, so it must be short enough to finish standing up.

Name, category, what you do in your own words, area, phone. Nothing else is
required. Address and hours appear only if they say they are a shop.

Afterwards it says what happens next, because the alternative is silence: *your
listing is live — people searching for carpentry in Vadasery will see it.*

## Screen 5 — My listing

Where fragile motivation is repaid. Views this week, calls this week, and the
confirmed jobs building up. This is the screen that decides whether somebody
lists a second thing, or tells a friend.

## Screen 6 — Reports queue

Organisers only. The same shape as the complaint reviewer's queue, because it
is the same job: read something a member said, decide, and record why.

---

## The endpoints these need

Eleven, which is the whole backend.

    GET   /work/categories                    flat list + counts, empties dropped
    GET   /work/listings                      q, category, area, page
    POST  /work/listings                      create
    GET   /work/listings/{id}
    PATCH /work/listings/{id}                 owner only
    GET   /work/my                            my listings + their view counts
    POST  /work/listings/{id}/view            fires the count behind the card
    POST  /work/listings/{id}/report          anyone
    POST  /work/listings/{id}/records         a job was done
    POST  /work/records/{id}/confirm          the person who received it agrees
    GET   /work/reports                       organiser queue
    POST  /work/reports/{id}/review           uphold or dismiss

Job posts add two more when that phase arrives. Payments add none — they are a
flag on listings that already exist.

---

## Deliberately absent

**No ratings.** A five-star average in a town of this size is a popularity
contest with a feud attached, and the research is clear that people do not
believe them anyway.

**No chat.** WhatsApp exists, everybody has it, and it is better. The app's job
ends at the phone number.

**No payments in the flow.** No escrow, no cut. The money is arranged between
two people who can see each other's faces, and trying to intermediate it would
add liability without adding trust.

**No login to search.** Somebody with a broken door should not have to make an
account to find a carpenter. Listing requires one; looking does not.
