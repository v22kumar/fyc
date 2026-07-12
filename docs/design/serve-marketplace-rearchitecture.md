# Serve Re-architecture — The FYC Marketplace

_Status: proposed · Owner: FYC Connect · Supersedes the "Opportunities & Skills" screen_

## 1. The problem

The current **Opportunities & Skills** screen conflates four unrelated ideas
behind one vague label:

- **Volunteer** drives (unpaid community work)
- **Courses** (learning / tuition)
- a **Local Services** directory (carpenters, electricians, tutors — people who
  *offer* a skill), buried behind a single banner that links out to a
  completely separate feature
- a generic "Opportunity" that is neither a job nor a profile

The result reads as a grab-bag. Users can't tell whether they're meant to
*offer* something or *request* something.

## 2. The insight

There are only **two** things here, and they are the two sides of a
marketplace — exactly like Upwork:

| Side | Question it answers | Who acts | Data (already exists) |
|------|--------------------|----------|-----------------------|
| **Skills** (supply) | "I have a skill — hire me" | providers list themselves | `CommunityProfile` |
| **Opportunities / Jobs** (demand) | "I have work — apply to it" | posters create, members apply | `Opportunity` + `OpportunityApplication` |

Both models already exist in the codebase. This is a **reframe and reconnect**,
not a rebuild.

## 3. Target concept — "FYC Marketplace"

The Serve section presents two first-class, equal peers (no more buried
banner):

### 3.1 Skills Directory (supply side) — `CommunityProfile`
A directory of community members offering a skill or service. The model is
already rich: `category` (carpenter, electrician, plumber, tutor, tailor,
doctor, driver, photographer, … ), business name, description, contact
phone/WhatsApp, service area, years of experience, availability, and a
verified badge.

- **Browse:** filter by category, see verified providers first.
- **List yourself:** any signed-in member (CLUB_MEMBER+) can publish one profile.
- **Courses fold in here.** A tutor offering "spoken English" is a Skills
  listing under the `tutor` category — not a separate concept. The standalone
  "Courses" tab is retired.

### 3.2 Opportunities / Jobs (demand side) — `Opportunity`
A feed of postings that members **apply** to. Two posting types:

- `JOB` — a paid gig. Shows a **budget** string (e.g. `₹500/day`, `₹2,000 fixed`).
- `VOLUNTEER` — unpaid community work. Budget renders as "Volunteer".

`COURSE` is retained in the enum only so legacy rows keep parsing; it is not
offered when posting and not shown as a filter.

**No in-app payments.** Budget is informational; poster and applicant settle
offline via the poster's contact. This keeps the community app free of payment
rails and compliance overhead.

## 4. Data changes

### Backend — `Opportunity` (additive, low-risk)
`OpportunityType`: add `JOB`. Keep `VOLUNTEER`; keep `COURSE` (legacy only).

New nullable columns (picked up by the startup column-reconcile in `main.py`;
no destructive migration):

| Column | Type | Purpose |
|--------|------|---------|
| `budget` | `String(60)` | pay/budget display, e.g. `₹500/day`; null ⇒ unspecified |
| `contact_phone` | `String(15)` | how an applicant reaches the poster |
| `posted_by` | `GUID` | the member who posted (for "my postings" + authorship) |

Schemas (`OpportunityCreate/Update/Out`) gain `budget`, `contact_phone`. `Out`
also exposes `posted_by`.

The SQLite `type` column is a plain `VARCHAR` (SQLAlchemy does not emit a CHECK
constraint here), so adding the `JOB` value needs no table rewrite.

### Backend — router
- `GET /opportunities?type=JOB|VOLUNTEER` — filter unchanged mechanism, new values.
- `POST /opportunities` — **opened from admin-only to any signed-in member
  (CLUB_MEMBER+)**, stamping `posted_by` = current user. This is what makes it a
  member marketplace rather than a noticeboard. (Answers the earlier pending
  "who can create volunteer drives" question: members can.)

### Skills — `CommunityProfile`
No schema change. Already supports self-service listing and browse.

## 5. Mobile IA

```
Serve
 ├─ Jobs & Gigs         (Opportunity list)   "Find work · post work"
 │   ├─ filter: All · Jobs · Volunteer
 │   ├─ card: title · budget · category · location · Apply
 │   └─ FAB: Post a Job  (members)
 └─ Skills Directory    (CommunityProfile)   "Hire local skills · offer yours"
     ├─ filter: category chips
     ├─ card: name · category · service area · verified · Call/WhatsApp
     └─ FAB: List my skill  (members)
```

- "Opportunities & Skills" title retires; the two become sibling destinations.
- The old `_LocalServicesBanner` (a link buried in the opportunity list) is
  removed — Skills is now a peer, reached directly.
- Create form: type = Job / Volunteer; budget field shows only for Job;
  contact phone added. Posting opens to members.

## 6. Removed — Challenge FYC

The "Challenge FYC — send your team a match request" banner in Sports Hub is
removed per product direction. Scope: **mobile surface only** — the banner,
the `/sports/challenge` route, and `ChallengeFormScreen`. The backend
`ChallengeMatch` model, schemas, and `/sports/challenges` endpoints are left
dormant (reversible; no destructive migration). If they should be fully removed
later, that is a separate, isolated change.

## 7. Rollout (CI-gated PRs, in order)

1. **PR-1** — this spec + remove Challenge FYC mobile surface.
2. **PR-2** — backend: `Opportunity` → Jobs schema (JOB type, budget,
   contact_phone, posted_by), open posting to members, tests.
3. **PR-3** — mobile: two-sided Serve IA (Jobs list + Skills directory as
   peers), budget/contact on card + create form, retire Courses tab and the
   buried banner.

## 8. Non-goals (for now)

- In-app payments / escrow.
- Ratings & reviews on providers (the `is_verified` flag is the trust signal
  for v1).
- Application messaging/chat — apply routes to the poster's contact.
