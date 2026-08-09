# SOS as it stands — an audit

Read before `01-architecture.md`. Everything here is from the code on `main`
at 9 Aug 2026 and from two screenshots of the real widget tree
(`build/ui_shots/20_sos_sheet_today.png`, `21_safety_settings_today.png`).

The whole feature is 245 lines of service, 259 lines of sheet, 189 lines of
settings, one 33-line backend endpoint, and **zero tests**.

---

## What a member actually gets

Press the red disc in the shell — or shake the phone, which is on by default —
and a dark sheet slides up with four buttons of near-identical weight:

| Button | What it does | What actually happens |
|---|---|---|
| **Send SOS to my contacts** | primary, red | opens the **SMS composer**. The member must then find and press Send, in another app, under stress. |
| **Call 112** | outlined | opens the dialler. Does not dial. |
| **Alert nearby FYC members** | outlined | `POST /notifications/sos-alert` → **push to every member of the club**, in Nagercoil, Chennai and Dubai alike. Nothing is stored. |
| **Sound loud alarm** | outlined | loops a siren — **which stops the moment the sheet is dismissed**. |

Below them, four green ticks: *Share live location · Alert trusted contacts ·
Notify nearby FYC members · Works offline (SMS fallback).*

They are static text. They are not state, they are not toggles, and they are
not true.

---

## The twelve faults, worst first

### 1. "Nearby" is a broadcast to the entire organisation

`sos_alert` calls `NotificationService.broadcast(organization_id=...)`, which is
`SELECT * FROM users WHERE organization_id = ?`. The button says *nearby*, the
docstring says *nearby FYC members*, and the code says *everyone*.

This is the same class of error as the pothole in Bengaluru routed to an
Assistant Engineer in Nagercoil: a feature that has no concept of distance
inside a product whose entire value is being local.

The consequence is not merely cosmetic. A club that gets woken by an SOS from
someone 600 km away, twice, mutes the channel. Then the real one arrives and
nobody sees it. **Broadcast is how you destroy the only asset this feature
has.**

### 2. There is no incident. There is only a push.

No table, no model, no row. `sos_alert` fires a background task and returns
`{"message": "Alert sent to members"}` — to a member who is, by hypothesis, in
danger.

Because nothing is stored:

- nobody can say **"I'm safe"** — an SOS can be raised and never stood down;
- nobody can say **"I'm coming"** — there is no acknowledgement path at all;
- the person in trouble learns nothing about whether help exists;
- an organiser cannot see a live incident, or any past one;
- there is no audit trail after an event that may end up in front of police;
- there is no abuse control, because there is nothing to count.

### 3. It asserts things nobody observed

`"FYC members have been alerted."` is shown after a `202`-shaped response from
an endpoint that has only *scheduled* a background task. No delivery is
checked. No read is checked. Nobody has been alerted; a job has been queued.

This is exactly the failure the Complaint Box was rebuilt to remove — the app
stating as fact something it cannot see. It is much worse here, because a
member reads *"FYC members have been alerted"* and stops looking for help.

### 4. "Works offline (SMS fallback)" is false

Nothing in this feature works offline. `sendSms` shells out to the SMS app via
`url_launcher` — which needs the user to press Send. `alertMembers` needs the
network. The siren works offline; the alerting does not.

A false claim on a safety screen is worse than no claim. Delete it.

### 5. No countdown, and therefore no safe trigger

Apple, Android and Tamil Nadu's own **Kavalan SOS** all do the same thing: a
**five-second countdown that can be cancelled**, or press-and-hold. Kavalan
then sends location, a panic signal and a back-camera clip to the control room.

FYC has none of it. Every button fires immediately.

The countdown is not politeness. It is the mechanism that makes false positives
cheap — and only once false positives are cheap can you afford a hair-trigger
like shake-to-activate. FYC has the hair-trigger and not the safety catch,
which is precisely backwards.

### 6. Shake-to-trigger is on by default and opens a modal

`ShakeDetector` is decent work — three spikes above 18 m/s² inside 1.2 s, with
a 4-second cooldown. But it is enabled for everyone who installs the app, and
what it does is throw a full-screen modal over whatever they were doing. On a
motorbike on a Nagercoil road, that is a nuisance; in a pocket, it is a
nuisance every day until the member turns the whole feature off.

### 7. Trusted contacts live only on the device

`SharedPreferences`, a JSON array of raw phone strings. Consequences:

- reinstall the app, or change phone, and they are gone silently;
- the **server cannot reach them**, so if the phone is taken, smashed or out of
  battery the people who love you are never told;
- no names, no relationship, no validation, no contact picker — you type a
  phone number from memory into a text field (see screenshot 21);
- nothing tells you the list is empty until you press SOS and get
  *"Add at least one trusted contact first."* — at the worst possible moment.

### 8. The alarm dies with the sheet

`_SosSheetState.dispose()` calls `stopSiren()`. Dismiss the sheet — or have the
phone taken from you — and the siren stops. There is also no foreground
service, so Android will stop the audio when the app is backgrounded.

An alarm whose lifetime is a bottom sheet is not an alarm.

### 9. Every word is hardcoded English

*"Send SOS to my contacts"*, *"Getting location…"*, *"Alert your trusted
contacts and nearby FYC members, or call the emergency number."*, *"Couldn't
reach members — try SMS or call."*, *"Shake your phone hard to open the SOS
sheet"*, *"Vibrating alarm when you trigger SOS"*, *"Silent mode"* — around
eighteen strings, none in the registry.

The rest of the app does four languages. The screen a Nagercoil member opens
when they are frightened does one, and it is not theirs.

### 10. No rate limit, no abuse control

Any authenticated member can push-notify the entire club, unlimited times, with
no record. That is a spam cannon with a red button on it.

### 11. Two disconnected emergency surfaces

The Serve tab lists 100 / 108 / 101 / 1912 as dial buttons. The SOS sheet
offers 112. Neither knows about the other. A member has to already know which
screen holds which number.

### 12. Location is captured and thrown away

`currentLocation()` gets one fix with an 8-second cap, interpolates it into a
push body, and discards it. No accuracy is shown, no staleness, no updates. A
responder gets a Google Maps link to where the member was once, with no way to
know whether that was ten seconds or ten minutes ago.

---

## What is actually good, and should survive

- **`ShakeDetector`.** Three-spike debounce on `userAccelerometerEvents` with
  gravity removed and a cooldown. Keep the algorithm; change what it triggers.
- **The siren routing.** `AndroidUsageType.alarm` + speakerphone + `stayAwake`,
  with a system-tone fallback, is genuinely careful work. Keep it; move its
  lifetime out of the sheet.
- **`SosService`'s refusal to throw.** Every path degrades instead of failing.
  That instinct is right and the rewrite must keep it.
- **The persistent red disc in the shell.** Reachable from every tab. Correct.
- **Push is already high-priority** with an explicit Android channel.

---

## The one-sentence diagnosis

> It is built as a *menu of emergency-shaped actions*, when what an emergency
> needs is a *single committed act with a way to take it back* — and the only
> thing FYC can do that Apple, Google and the Tamil Nadu Police cannot do
> better is the one thing it does worst.
