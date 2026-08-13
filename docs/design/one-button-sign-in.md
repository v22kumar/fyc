# One button: sign in with a phone number

The Android login screen has two buttons — **Get OTP** and **Continue with
Google** — and a member has to know which one is theirs. They become one
**Sign in**: type the number, tap once, you are in.

This is the spec, written down because it was designed at 3am with credits
running out and the implementation happens later. The drawing is the club's,
reproduced faithfully; the notes under it are the parts that are easy to get
wrong.

```
USER
  │  1. enters phone number
  ▼  2. taps Sign In
Google Sign-In
  │  succeeds
  ▼
User is AUTHENTICATED          ← Google identity = verified
  │  3. try to attach the phone
  ▼
Phone available? ──NO──→ don't attach (this time)
  │ YES
  ▼
Save phone as UNVERIFIED
  │
  ▼
Try sending OTP ──service down──→ phone stays UNVERIFIED
  │ OTP works
  ▼
Phone VERIFIED ✓
  │
  ▼
ENTER THE APP — chess, feed, events, community
```

## The rule that must not be got wrong

**The session comes from Google. The typed number is only ever a claim.**

If a session were keyed on the number somebody typed, then typing a
neighbour's number would hand over their account. So:

* Google proves who the member is. That is what creates the session.
* The number is attached to *that* account, unverified, and proves nothing
  until an OTP comes back.
* **If the number already belongs to a different account, do not attach it,
  and do not fail the sign-in.** The member is still legitimately signed in as
  themselves; they simply do not get that number. This is the `NO` branch, and
  it is the whole security of the design.
* An unverified number must never be used to *find* an account — only to
  decorate the one Google already identified. Matching on it would reopen the
  same hole from the other side.

## Nobody is blocked

A failure to verify is not a failure to sign in. OTP delivery breaks for
reasons that have nothing to do with the member — Twilio, a dead SIM, a
village with no signal — and the app stays usable throughout: chess, feed,
events, community.

The club chose the follow-up: **7 days of grace, then read-only** — still able
to open and read everything, unable to post, register or contribute until the
number is verified. Never a locked door.

## Shape of the work

1. **Backend** — `POST /auth/phone/claim` on the authenticated user. Attaches
   the number as unverified; refuses (200, `attached: false`) when it belongs
   to somebody else. OTP verification is what sets it verified.
2. **Mobile** — one Sign in button on `otp_login_screen.dart`; both it and
   `sign_in_sheet.dart` already send the same events to `auth_bloc.dart`, so
   the two doors stay one implementation.
3. **Fallback** — if Google is unavailable, today's OTP screen is still there,
   unchanged. Nobody is stranded by the new road.
4. **Reminder, not a wall** — a banner offering "verify now" while the number
   is unverified.

## Tests worth writing first

* signing in with Google and a number nobody holds → attached, unverified
* the same number already on another account → **not** attached, sign-in still
  succeeds, the other account is untouched
* OTP verified → the number becomes verified
* OTP never arrives → the member still reaches the app
* an unverified number never matches an existing account on any lookup path
