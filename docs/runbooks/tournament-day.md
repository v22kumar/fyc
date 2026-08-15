# Tournament-day runbook (organiser)

Written 2026-08-15 for the chess tournament. Keep this open on a laptop that
can reach the internet. The venue's 4G is weak — that is a real constraint, but
most of what breaks today is **not** the venue wifi. Read the "login" section
first; that is where the trouble is.

---

## The one-line summary

**Sign members in with the "Continue with Google" (one-button) sign-in. Do not
count on the phone-number / OTP path in the current app — it does not work for
most numbers today.** For anyone who cannot get in, the organiser records their
result manually (see "A player can't log in").

---

## The four health URLs (open these first, and again if something feels wrong)

Paste each into a browser on the laptop. What "good" looks like, and what "bad"
means:

| URL | Good | Bad → what it means |
| --- | --- | --- |
| `https://api.fycconnect.com/api/health/ready` | `{"status":"ready"}` | anything else → the API/database is down. Nothing will work. Call the tech contact. |
| `https://api.fycconnect.com/api/health/auth` | `can_deliver_a_code: true`, `session_store.database: postgresql` | `delivery.refused` climbing while `sent` stays low → OTP SMS is being rejected (this is today's known problem, see below). |
| `https://api.fycconnect.com/api/health/media` | `credentials_set: true`, `survives_a_deploy: true` | `credentials_set: false` → photo uploads will 500. Not tournament-critical. |
| `https://api.fycconnect.com/api/health/production` | `blockers: []` | any blocker listed → a security/config guard is unsatisfied. |

---

## A player can't log in  ← most likely problem today

**Why it happens.** Two independent things are wrong in the shipped app:

1. **The phone / OTP path in the pop-up sign-in sheet is broken.** The button
   that says *"send_otp" / "use phone OTP instead"* does not actually text a
   code in the app version everyone has installed. This cannot be fixed from
   the server; it needs a new app build, which we are **not** pushing today
   (nobody can re-download an app on weak 4G). Do not send people down this
   path — it will not work and it wastes their time.

2. **Even the real OTP screen only reaches Twilio-verified numbers.** Twilio
   (the SMS provider) is on a restricted/trial plan, so a code is delivered
   only to numbers that have been pre-verified in the Twilio console. A number
   that is not on that list gets *"We could not send your code."* Proven today:
   one test number received an SMS (HTTP 200), another was refused (HTTP 502).
   **A hotspot does not fix this** — the rejection is on Twilio's side, not the
   venue's.

**What to do instead — in order:**

1. **Continue with Google.** This is the door that works. The member taps
   "Continue with Google", picks their Google account, and lands on Home. This
   works for anyone who has signed in before (their account is matched by email).
   This is the primary sign-in for the day.
2. **Brand-new member, never signed in?** They need a phone number to register,
   and that path is the broken one. Do not block the event on it — see step 3.
3. **Can't get in at all → the organiser is the fallback.** The member still
   plays. The organiser records the pairing and the result on the organiser's
   own (working, signed-in) device. Record at the venue, verify later. A player
   never has to be logged in for their game to count — see the next section.

---

## A player's game stalls / freezes

Games do not depend on both phones staying online. Clocks are durable on the
server, and a background job (the "reaper") ends games that stall.

1. **A move didn't go through / the board looks frozen.** Have the player wait
   ~10–15 seconds, then pull to refresh / reopen the game. The board resyncs
   from the server; a move already made is not lost.
2. **A player's phone died, app crashed, or they walked out of signal.** The
   clock keeps running on the server. When they reopen the app the game resumes
   where it was. If they cannot return, the reaper will flag them on time and
   the game ends as a loss-on-time — the bracket does **not** freeze waiting.
3. **The reaper is slow / a bracket is stuck.** Do not wait indefinitely. The
   organiser records the result manually (below) and advances the round. The
   manual result is authoritative for the bracket; reconcile later if needed.

### Organiser records a result manually (the universal fallback)

From the **organiser surface** (Manager Dashboard → the tournament → the match):
record the winner. A confirmation dialog names the winner before it commits —
**read the name aloud to both players before confirming.** Then advance the
round. This is how you keep the tournament moving no matter what any individual
phone is doing.

---

## Low-internet drill (do this once before 4 PM)

- **One good phone as a hotspot beats thirty phones on weak 4G.** Put the
  organiser's device (and ideally the two players at the top board) on one
  strong connection. Reconnect banners and board resync depend on *some*
  connection existing, not a fast one.
- Note again: the hotspot helps chess sync and Google sign-in. It does **not**
  fix OTP delivery (that's a Twilio-account problem, not bandwidth).

---

## Escalation / tech contact checklist

If you need the tech contact, tell them which of these you're seeing — it saves
20 minutes of guessing:

- `health/ready` is not `ready` → API or DB down.
- `health/auth` `delivery.refused` climbing → Twilio is refusing codes (known).
- Members can Google-sign-in but not phone-sign-in → known, expected today.
- A bracket won't advance and the reaper hasn't ended a dead game → record the
  result manually and move on; flag it for later reconciliation.

---

## Known issues carried into today (context, not action items)

- Phone/OTP sign-in in the pop-up sheet is non-functional in the shipped app
  (hardcoded test path). Server-side unfixable; needs an app release.
- Twilio is on a restricted plan; OTP reaches only pre-verified numbers.
- Firebase Phone Verification is not configured on the server (returns 503);
  it is not a working door today.
- A committed test-token login backdoor was found and **closed** this morning
  (deployed and verified). Not a concern during the event.
