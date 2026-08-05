# Location: what we collect, when, and why

Written in response to a real question — *if we are asking for GPS anyway,
should we be collecting it continuously, and can a nonprofit afford that?*

## The cost is not the server

Worth settling first, because it is the thing being worried about and it is not
the constraint.

Fly bills machine time and bandwidth, not requests. A location update is a few
hundred bytes and a single indexed insert. Five hundred members reporting every
fifteen minutes is about 48,000 writes a day — which sounds like a lot and is
perhaps two minutes of CPU spread across twenty-four hours, on a machine that is
already running and already paid for. Postgres will not notice.

So: **do not shape this decision around API cost.** At club scale it rounds to
nothing.

Two things *are* expensive, and neither appears on an invoice:

**Battery.** A phone reporting its position continuously is a phone whose owner
notices the drain and uninstalls the app. This is the practical ceiling, and it
is much lower than the server's.

**Trust.** A community club that quietly tracks where its members are is a
different organisation from one that does not. In a town where everyone knows
everyone, one leak or one misuse is not a support ticket — it is the end of the
club's standing. That risk dwarfs any hosting bill.

## Three tiers, by purpose

Continuous tracking is the wrong shape because almost nothing needs it. Split by
what the location is actually *for*:

### Tier 1 — a home area, stored once

For matching donors. Finding who lives near a hospital does not need to know
where anyone is *right now*; it needs to know roughly where they live.

Captured once, with consent, and refreshed rarely — when the member updates
their profile, or occasionally on a prompt. This is what `BloodDonor.latitude`,
`longitude` and `location_consent` already hold.

Ongoing cost: zero. Battery cost: zero.

### Tier 2 — a single reading, at the moment of use

When a member raises a blood request or taps SOS, take one position *then* and
attach it to that event. Nothing before, nothing after.

This is the tier that answers "who is nearest to this emergency" accurately,
and it is one GPS fix per incident rather than one every few minutes forever.

### Tier 3 — live position, only while something is happening

This is the lost-phone and lost-person case, and it is the only one that needs a
stream. The rule that makes it safe is that **it is off by default and bounded**:

- It starts only when the member themselves triggers an alert, or when a
  standing opt-in they gave earlier is invoked.
- It runs for a bounded window — an hour, say — and **expires by itself**. There
  is no state where it is quietly still running next week.
- While it runs, the phone shows it plainly, with a stop control that always
  works.
- Only a named, small set of responders can see it. It is never a member-visible
  map of where everyone is.
- Every view of a live position is audit-logged, exactly as revealing a donor's
  phone number already is.
- The trace is deleted after a short retention period. An emergency that ended
  three weeks ago does not need its route kept.

Even at one point every thirty seconds for an hour, that is 120 rows per
incident. The volume is irrelevant; the guardrails are the entire design.

## The consent point that is easy to get wrong

Tracking *yourself* is a choice you make. Tracking *someone else* — the missing
person, the child, the elderly relative — is not something a third party can
consent to on their behalf, however good the reason and however urgent the
moment.

So the opt-in has to be given **in advance, by the person being located**, and be
revocable by them at any time. A family member can then invoke it during an
emergency; they cannot create it. Anything looser and the club is running
surveillance that someone will eventually, and rightly, object to.

## What this means for what is built now

- Tier 1 exists and works.
- Tier 2 exists in the request flow — it takes a position when a request is
  raised. The donor list now does the same on open, which is the same idea.
- Tier 3 is not built, and should not be built until the guardrails above are,
  because the feature without them is the thing that damages the club.

The order matters: the bounded window, the visible indicator, the audit trail
and the retention limit are not polish to add afterwards. They are what makes
the feature defensible, and they are cheap to build first and expensive to
retrofit.
