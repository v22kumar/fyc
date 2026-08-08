# Skills and Opportunities — research before architecture

*The Complaint Box worked because the data came first and the design came
second. Same order here.*

---

## 1. What exists today

Two half-features that never meet.

**Skills** live in `VolunteerMetadata.skills` — a JSON array on the
volunteering-hours table. It is initialised to `[]` in three places
(`auth.py:318`, `events.py:523`, `users.py:326`) and **there is no screen
anywhere that fills it.** Every member has an empty list, and always will.

**Opportunities** is a separate model with bilingual titles, a `budget` string,
a `contact_phone`, and an applications table. On mobile there is
`opportunity_create_screen.dart` and **no browse screen** — you can post work
that nobody can find.

They share no code, no concepts and no join. A skill cannot be matched to an
opportunity because nothing connects them. That is what "patchwork" means
concretely: 504 lines of clean architecture around a product decision that was
never made.

---

## 2. What the research says

Four threads, all landing in the same place.

### 2.1 Marketplaces die of illiquidity, and local ones die fastest

The cold-start problem is structural: a provider joining an empty marketplace
finds no customers and leaves; a customer finds no providers and leaves.
Liquidity means a relevant counterparty at the right time, in the right place,
at the right price — and without it buyers "leave, tell no one to come back",
which starts the death spiral.

Geographic marketplaces are explicitly the hard case: they take four to six
months per area "because the cell-by-cell density gate is harder to compress".
The named post-launch killers are spreading supply too thin, seeding the wrong
side first, and **off-platform leakage**.

> **What this means for a club in Nagercoil.** One town is one cell, which is
> the *only* good news here — no spreading thin. But off-platform leakage is
> not a risk for FYC, it is a certainty: these people already have each other's
> numbers. Any design that needs the transaction to stay on the platform is
> dead before it ships.

### 2.2 Markets here actively resist being platformed

The research is blunt: "markets often resist platformization, creatively using
tools such as WhatsApp to maintain informal coordination and community
control." WhatsApp *extends* existing trust networks "rather than replacing
them". Domestic work has long been organised through "neighbourhood networks,
word of mouth, or intermediaries".

> **What this means.** Do not build something that competes with the WhatsApp
> group. It will lose, and it deserves to. Build the thing WhatsApp cannot do,
> and make its output land *in* WhatsApp.

### 2.3 The product that won in India is verification, not listings

Apna reached 2 crore users, and the reason given everywhere is trust:
candidates "fear falling into fraudulent hiring traps", employers are "thoroughly
vetted", every listing "undergoes rigorous verification". Users "joined
skeptically but stayed because interactions felt genuine". Referrals are
trusted because they carry "a built-in vouch... that a faceless application
never can".

> **What this means.** FYC cannot out-list Apna and should not try. It can
> out-*vouch* anyone in Nagercoil, because it has actually known these people
> for years. The vouch is the entire asset.

### 2.4 Time banks show what a vouched record looks like

The most useful idea in the whole search: a timebank can produce **portfolio
reports** listing a member's activity in detail, "validated by the timebank,
similar to a university transcript rather than traditional resumes".

And on cold start: they start small and member-led, and they seed supply by
**asset mapping** — literally surveying neighbours about their skills — rather
than waiting for self-registration.

> **What this means.** A self-declared skill list is worthless; everyone claims
> everything and nobody believes it. A record of work actually done, confirmed
> by the person who received it and issued by the club, is a document a
> nineteen-year-old in Nagercoil currently has no way to obtain.

---

## 3. The finding

**This is not a marketplace. Building one would fail, and the research says why
in four independent ways.**

FYC has one asset no platform can buy: it knows who these people are. A club
that has watched somebody run the cricket scoreboard for three seasons can say
something about their reliability that no rating system can manufacture.

So the product is not a job board with a directory attached. It is:

1. **A vouched record of what members can do and have done** — the transcript,
   not the resume.
2. **A way to ask the club for that record** — and for the club to answer with
   a name and a vouch.
3. **A hand-off to WhatsApp or a phone call**, where the actual work gets
   arranged, because that is where it was always going to happen.

The club never takes a cut, never holds the money, and never tries to keep the
conversation on the platform. Which removes leakage as a concern entirely —
you cannot leak from something that was never trying to contain you.

---

## 4. What follows from that

Stated as decisions, to be argued with before anything is built.

**Both sides are the same people.** A member who fixes motorbikes needs a
tutor for their sister. Modelling "employers" and "workers" as separate
populations — which is what `OpportunityType` and a separate applications table
imply today — is wrong on the first day.

**Seed by asking, not by waiting.** The empty-skills field is the whole
lesson: nobody fills a profile section for a marketplace with no demand. Skills
get collected the way the civic directory did — deliberately, by people, one
conversation at a time — starting with the members already visibly good at
something.

**The record is the product, and it is earned.** A skill claimed is a claim. A
skill plus three completed jobs, each confirmed by whoever received the work,
is a document. The second one is worth building; the first is a text field.

**The club vouches, and that means the club can be wrong.** Vouching is a real
liability, exactly as sending a complaint was. It needs the same treatment: a
named organiser, a reason, and a record of who vouched for what and when.

**Send it to WhatsApp.** The app's job ends at "here is who to call and why you
can trust them" — as a message that leaves the app, the way the scoreboard
already does.

---

## 5. On separate services

The instinct is right and the conclusion is not.

Complaint Box, Blood Donation and Work are three different products that happen
to share a login. They should not share models, tables, or vocabulary — a
`Complaint` and an `Opportunity` have nothing in common and any abstraction
over both would be a mistake.

But **separate deployments would be a serious error here.** Microservices buy
independent scaling and independent release cycles, at the cost of network
calls between things that used to be function calls, distributed transactions,
and an operations burden. FYC has one server, a few hundred members, and no
dedicated operations person. It would be paying every cost and receiving no
benefit.

The correct shape is what the codebase nearly has already: **a modular
monolith** — hard boundaries in the code, one thing to deploy. Each feature
owns its models, its router, its screens and its language, and reaches other
features only through explicit interfaces. Blood Donation and Complaint Box are
already close to this. The rule worth adding is that no feature may import
another feature's models.

That is the design the instinct is reaching for. It is a boundaries problem,
not an infrastructure one.

---

## 6. Open questions, for a person

These decide the design and I cannot answer them.

1. **What work do members actually need?** Tuition, motorbike repair, event
   photography, wiring, tailoring? The categories decide everything downstream
   and guessing them is how the current `OpportunityType` enum happened.
2. **Who is the demand?** Other members, local businesses, or families in
   Nagercoil generally? Each is a different product.
3. **Is money involved, or is this mutual aid?** The `budget` field says money.
   The volunteering table says aid. It cannot be both without saying so.
4. **Will the club actually vouch?** Everything here rests on that. If no
   organiser will put their name to "yes, he is reliable", there is no product
   — only a list.

---

## Sources

- [Why Two-Sided Marketplaces Fail After Launch](https://www.raftlabs.com/blog/two-sided-marketplace-failure-rate)
- [Two-Sided Marketplace Cold Start: 2026 Playbook](https://forkoff.xyz/blog/founder-growth/two-sided-marketplace-cold-start-2026)
- [Solving the Marketplace Cold-Start Problem](https://www.davidciccarelli.com/articles/product-marketing-playbook-for-two-sided-platforms/)
- [DAIEM: Decolonizing Algorithm's Role as a Team-member in Informal E-market](https://arxiv.org/pdf/2506.12910)
- [The App Fixes the Hour: How Platforms Are Reorganising Domestic Work in India](https://behanbox.com/2026/06/12/the-app-fixes-the-hour-how-platforms-are-reorganising-domestic-work-in-india/)
- [Why Millions of Job Seekers in India Trust Apna Jobs](https://apna.co/career-central/trusted-job-portal-in-india-apna-jobs/)
- [Coordinating Community Cooperation: Integrating Timebanks and Nonprofit Volunteering by Design](https://www.ijdesign.org/index.php/IJDesign/article/view/2302/763)
- [Time Banking: A Community Path to Addressing Social Exclusion](https://nonprofitquarterly.org/time-banking-a-community-path-to-addressing-social-exclusion/)
