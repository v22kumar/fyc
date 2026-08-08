# Work — architecture

*Follows `00-research.md`. Where the research and the club disagreed, the club
won and the disagreement is written down.*

---

## 1. The problem, restated

A carpenter in Nagercoil is invisible online.

Not because he lacks a phone — he has WhatsApp. Because there is no index he
appears in. In a city, a plumber gets found through Google, JustDial, or a
delivery app. In Nagercoil that machinery does not reach far enough down, and
the one directory that would list him **charges around ₹11,000 a year** for a
city listing. He will never pay it, so he does not exist to anyone who has not
already met him.

Meanwhile a family two streets away spends an evening asking around for
somebody to fix a door.

**Both of them are already in the club's reach. Neither can find the other.**
That is the whole product.

## 2. What it is, and what it is not

**It is a local index.** Somebody who does work — a person or a shop — appears
in it, and somebody who needs work done can find them and ring them.

**It is not a marketplace.** No escrow, no cut, no ratings arms race, and no
attempt to keep the conversation inside the app. The research names
off-platform leakage as a marketplace killer; here the hand-off to a phone call
or WhatsApp *is the intended ending*, so leakage is not a failure mode. You
cannot leak from something that was never trying to contain you.

**It is not a job board.** Job boards need a constant flow of postings to look
alive. An index of who does what is useful on a day when nobody has posted
anything.

## 3. Everyone is a listing

Not two populations. One.

A member who fixes motorbikes needs a tutor for his sister. A tailor needs a
mason. Modelling "employers" and "workers" separately — which the current
`OpportunityType` enum and its applications table imply — is wrong on day one
and gets harder to unwind every week.

So there is one thing, a **Listing**, and it belongs either to a person or to a
business. A shop has an address and opening hours; a person has neither. That
is the only real difference and it is a nullable field, not a second model.

Anyone may create one — members, local businesses, anyone in Nagercoil. The
club is not the gate.

## 4. Categories: broad and flat

**Software. Not "React developer".**

This is the instruction and it is also correct. A deep taxonomy is how
directories die: nobody self-classifies into the right leaf, searchers pick a
different leaf, and both sides conclude the thing is empty. Roughly twenty
categories a person would say out loud:

    Tuition · Carpentry · Masonry · Painting · Electrical · Plumbing
    Welding · Motorbike repair · Car repair · Mobile repair
    Computer & hardware · Software · Photography · Videography
    Tailoring · Catering · Driver · Daily labour · Cleaning
    Beauty & salon · Events & decoration · Repairs — general

Each listing carries **free text alongside** its category, because that is
where "I do interlock brick work" lives, and it is searchable. The category is
for browsing; the words are for finding.

## 5. Trust without a gatekeeper

The club has decided there is **no organiser approval**. Anyone lists, and
anyone can report; reports get acted on.

That overrules what §2.3 of the research recommended, and the disagreement is
worth stating plainly rather than burying: Apna's whole product is vetting,
because the thing users fear most is fraud. Purely reactive moderation has a
known failure mode — the first bad actor does their damage *before* anybody
reports, and the person harmed is the one who trusted the club's list.

**But gatekeeping is not the only way to earn trust, and it is the most
expensive.** It costs an organiser's evening, every week, forever — and the
Complaint Box already showed what happens to an approval queue nobody has time
for.

So: trust is built from **facts that accumulate on their own**, none of which
require anybody's judgement.

| Shown on a listing | Where it comes from |
|---|---|
| Phone verified | The OTP they already did to sign in |
| Member since 2019 | The account, already there |
| 12 jobs marked done | Confirmed by the person who received the work |
| In the club's blood donor list | Already true of many of them |
| Reported twice, both upheld | The report queue |

None of that is a rating out of five, which people game and nobody believes. It
is a set of things that are simply true, shown plainly, letting the person
looking decide. A listing with nothing yet says so honestly — **new, not yet
worked through the app** — rather than pretending.

And the thing the club is uniquely able to offer sits on top of that: a
**record of work done**, confirmed by whoever received it. Not a self-declared
skill list — everyone claims everything and nobody believes it — but a
transcript. A nineteen-year-old in Nagercoil has no other way to obtain a
document saying *he has done this eleven times and eleven people confirmed it*.

## 6. Reporting, since it is the whole safety mechanism

If reports are the only line of defence, they must actually work, which means
they need more design than a button.

- **Anyone can report a listing.** Not only members, not only people who hired.
- **A reason, from a short list**, because "wrong number" and "he took money
  and did not come" need completely different responses.
- **Two upheld reports hides the listing** pending an organiser, automatically.
  A rule that acts without waiting for someone to be free is the only kind that
  works at 9pm on a Sunday.
- **A single report never hides anything.** One angry customer must not be able
  to remove a competitor.
- **The person listed is told, and can answer.** Being removed from a village
  index without explanation is a serious thing to do to somebody's livelihood.
- **Reports are visible to organisers as a queue**, with the same shape as the
  complaint reviewer's queue that already exists.

## 7. Money: built, and switched off

The club will charge eventually and does not want to yet. Both halves get
built; the switch stays off.

**But not for registration.** Charging to list would kill the supply side, and
the cold-start research is unambiguous that supply must be seeded first. The
carpenter who will not pay JustDial ₹11,000 will not pay FYC ₹100 either — and
an index with no carpenters is worth nothing to the family looking for one.
Free to list, permanently, is not generosity; it is the only way the thing
fills up.

What can be charged for, later, without breaking that:

1. **Prominence.** JustDial's actual model — free to appear, pay to appear
   first. The listing stays free forever; the top of the results is the product.
2. **Posting a job.** The demand side, which is the side with money in hand at
   the moment it wants something done.
3. **The record.** A printed, club-stamped work transcript for somebody
   applying for a real job. Small, and it is the thing they would actually pay
   for.

Shipped behind `WORK_PAYMENTS_ENABLED`, defaulting off, with the schema in
place so turning it on is a setting rather than a migration.

## 8. Shape

Three products that share a login and should share nothing else.

    backend/app/models/work.py        Listing, WorkRecord, Report — its own tables
    backend/app/routers/work.py       /api/v1/work/*
    mobile/lib/features/work/         data / domain / presentation, its own bloc

The rule the codebase needs, which the instinct behind "separate services" was
reaching for: **no feature may import another feature's models.** A `Listing`
and a `Complaint` have nothing in common, and any abstraction over both would
be a mistake.

Separate *deployments* would be a different thing and the wrong one — every
cost of microservices, none of the benefit, on one server with a few hundred
members and nobody on call. The boundary belongs in the code.

### Data

- **Listing** — owner (person or business), category, free text, area, phone,
  optional address and hours, active flag
- **WorkRecord** — a job done: listing, who received it, what, when, confirmed
  or not. The transcript is built from these.
- **Report** — listing, reporter, reason, status, and what an organiser decided
- **JobPost** — somebody asking for work rather than offering it. Second, not
  first: an index is useful with no posts in it, and posts are useless with no
  index.

## 9. Build order

1. **Listings and search.** The index. Useful the day it has fifty entries.
2. **Seed it by asking.** Same as the civic directory — deliberately, one
   conversation at a time, starting with members already visibly good at
   something. Nobody fills a profile field for an empty marketplace; the empty
   `skills` array on every member is the proof.
3. **Reporting**, before it is needed rather than after.
4. **Work records**, once real jobs are happening.
5. **Job posts.**
6. **Payments**, switched off.

## 10. What is being dropped

`VolunteerMetadata.skills` stays where it is and keeps meaning what it says —
what a volunteer can help the club with. It is not the skill directory and was
never filled as one.

The current `Opportunity` model does not survive. It is bilingual columns
around a decision nobody made, with a create screen and no browse screen. Its
one useful idea — that somebody can post work — comes back as `JobPost`, after
the index exists.
