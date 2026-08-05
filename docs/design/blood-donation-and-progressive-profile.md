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
