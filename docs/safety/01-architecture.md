# SOS, reconsidered

Companion to `00-audit.md`. This is the whole feature rethought — what it is
for, what it must never claim, the data model, the endpoints, the screens, and
what gets deleted.

---

## 1. The reframe

**FYC is not the ambulance. FYC is the neighbours.**

Three organisations already do emergency response in Kanniyakumari far better
than a youth club ever will: the Tamil Nadu Police (112 / **Kavalan SOS**),
108 Ambulance, and the phone in the member's hand (Apple and Google both ship
an Emergency SOS with satellite fallback and crash detection).

Trying to out-build them produces exactly what exists today: a menu of
half-versions of their features.

But there is one thing none of them has, and FYC does: **a roster of a few
hundred real people who live in this district and know these streets.** A
police vehicle takes eight minutes. Someone from the club who is 300 metres
away takes two.

So the feature has exactly three lanes, in strict priority, and the design of
each follows from who owns it.

| | Lane | Owner | FYC's only job |
|---|---|---|---|
| **0** | **The State** — 112 | TN Police | be a faster dialler than the dialler, and have the member's location already on screen to read out |
| **1** | **The people who love you** | the member | make sure they are told even if the phone is gone |
| **2** | **The people who are near** | FYC | **this is the product** |

Everything below serves that table.

---

## 2. What the research says

Four systems worth copying, and the specific number to copy from each.

**Kavalan SOS (Tamil Nadu Police).** SOS button → **five-second countdown** →
location + panic signal + a back-camera clip to the Master Control Room, and an
SMS to registered emergency contacts. ~1.1 million downloads in this state.
*Take: the countdown, and the fact that our members may already have this app —
we should point at it, not compete with it.*

**Apple / Android Emergency SOS.** Press-and-hold or a five-second countdown,
always cancellable; Safety Check shares location with contacts for up to 24
hours or until stopped. *Take: cancel is the feature. Sharing has an end.*

**PulsePoint.** Dispatches to opted-in volunteers within roughly **400 metres**
of the incident; acknowledging opens a map with the location and nearby AEDs.
*Take: a radius, opt-in, and something useful on the other side of the tap.*

**GoodSAM.** Alerts **the three nearest** responders; if one does not accept
**within 20 seconds** it moves to the next. *Take: nearest-N with escalation,
never broadcast.*

**And the number that governs the whole design:** volunteer response rates in
the published studies run **17–47%**. Between half and four-fifths of the
people you alert will not come.

That single fact kills the current design and dictates the new one. If most
alerts go unanswered, then:

- alerting **one** person is not a plan — you need several;
- alerting **everyone** is not a plan either — it destroys the channel, and the
  fifth-nearest person cannot help anyway;
- you must **escalate** on silence, on a timer;
- and the person in trouble must be able to **see who accepted**, because "we
  sent it to six people" and "Suresh is two streets away and coming" are
  completely different pieces of information.

---

## 3. Principles

1. **One committed act, with a way to take it back.** Not a menu. Press and
   hold, or a five-second countdown. Cancel is always the largest thing on the
   screen after the countdown starts.
2. **Never claim what nobody observed.** The same rule the Complaint Box runs
   on. "Sent to 6 members" is a fact. "Members have been alerted" is a hope.
   "Works offline" is a lie. Show delivered / acknowledged counts, or show
   nothing.
3. **An SOS is an incident, not a notification.** It has a row, a lifecycle,
   and an ending. Nothing is fire-and-forget.
4. **Radius before roster.** Nobody outside the radius is ever told, at any
   stage, for any reason.
5. **The member in trouble is the only source of truth about safety.** Only
   they, or an organiser after contact, may stand an incident down. Never a
   timer.
6. **Everything degrades, nothing blocks.** No GPS → send without it. No
   network → SMS. No app → the shell still dials 112.
7. **Four languages, on this screen more than any other.**
8. **Nothing about a safety feature may depend on a screen staying open.**

---

## 4. Data model

New module `app/models/safety.py`. No other feature may import it; it imports
nothing but `user` and `tenant`.

### `SafetyContact` — Lane 1, server-side

Moves off the device so the alert survives a lost phone and a reinstall.

| column | why |
|---|---|
| `id`, `organization_id`, `user_id` | |
| `name` | *"Amma"*, not `+919840011111`. A responder list of bare digits is unusable and undeletable-by-mistake. |
| `phone` (E.164) | validated on write, not on send |
| `relationship` | optional; helps the member confirm they picked the right person |
| `notify_sms` / `notify_push` | a contact who is also a member gets the push *and* the SMS |
| `verified_at` | nullable. A number that has never received a test message is a number we should not promise anything about. |
| `position` | order to try |

### `SosIncident` — the thing that was missing

| column | why |
|---|---|
| `id`, `organization_id`, `raised_by_user_id` | |
| `kind` | `MEDICAL · THREAT · ACCIDENT · FIRE · OTHER` — chosen *after* the alert goes out, never before |
| `status` | see the state machine below |
| `latitude`, `longitude`, `accuracy_m`, `located_at` | accuracy and time are stored because a responder must be able to tell a 12 m fix from a 2 km one |
| `place_name` | reverse-geocoded, best effort |
| `radius_m` | the radius actually used, recorded — so an incident can be explained later |
| `alerted_count` | how many were reached in the end |
| `stood_down_at`, `stood_down_by_user_id`, `stood_down_reason` | |
| `created_at` | |

### `SosResponder` — one row per person told

| column | why |
|---|---|
| `incident_id`, `user_id`, `wave` | which escalation round they were in |
| `distance_m` | at dispatch, frozen |
| `notified_at`, `acknowledged_at`, `arrived_at`, `declined_at` | four separate facts, each written by the person it is about |

### `SosEvent` — the authored timeline

Identical in spirit to `ComplaintEvent`: **every row names its author.** The
server never infers. `RAISED · WAVE_SENT · ACKNOWLEDGED · ARRIVED · DECLINED ·
CALLED_112 · CONTACTS_SMS_SENT · STOOD_DOWN · REOPENED`.

This is what makes an honest screen possible for the member *and* an
after-the-fact account possible for the club.

### What is deliberately absent

- **No continuous location track.** An SOS is not a tracker. Position updates
  attach to the incident and stop when it is stood down.
- **No responder rating, ever.** Same rule as the Work directory.
- **No auto-resolve timer.** An incident that times out is an incident nobody
  answered — that is a fact worth showing, not a state worth inventing.

---

## 5. The state machine

```
                    press & hold / countdown ends
                                │
                                ▼
   ┌──────────┐  cancel   ┌───────────┐
   │ COUNTING │──────────▶│ CANCELLED │   (never leaves the device)
   └──────────┘           └───────────┘
        │ 5s
        ▼
   ┌──────────┐  wave 1: nearest 5 within 1 km
   │  RAISED  │──────────────────────────────────┐
   └──────────┘                                  │
        │ nobody acknowledged in 45s             │
        ▼                                        │
   ┌──────────┐  wave 2: next 10 within 3 km     │
   │ WIDENING │──────────────────────────────────┤
   └──────────┘                                  │
        │ nobody in 90s                          ▼
        ▼                                 ┌──────────────┐
   ┌──────────┐  wave 3: organisers +     │ ACKNOWLEDGED │
   │ ESCALATED│  every member in district │  (≥1 coming) │
   └──────────┘                           └──────────────┘
        │                                        │
        └────────────────┬───────────────────────┘
                         ▼
                 ┌───────────────┐
                 │  STOOD_DOWN   │  only the member, or an organiser
                 └───────────────┘  who has spoken to them
```

Wave 3 is the *only* path that reaches the whole district roster, it happens
after **135 seconds of total silence**, and it still never leaves the district.
The current code starts at wave 3 and never leaves it.

---

## 6. API

All under `/api/v1/safety`. New router, new module, no reuse of
`/notifications/sos-alert` — which is deleted.

| method | path | notes |
|---|---|---|
| `POST` | `/sos` | raise. Body: lat/lng/accuracy optional, `kind` optional. **Idempotency-Key required** — a panicking thumb presses twice. Returns the incident with wave 1 already dispatched. |
| `POST` | `/sos/{id}/location` | a fresher fix while it is live |
| `POST` | `/sos/{id}/kind` | say what it is, after the fact |
| `POST` | `/sos/{id}/stand-down` | "I'm safe" |
| `POST` | `/sos/{id}/reopen` | pressed by mistake, or it got worse again |
| `GET` | `/sos/{id}` | the incident, its responders, its timeline |
| `GET` | `/sos/mine` | my history |
| `GET` | `/sos/live` | organisers only: what is happening right now |
| `POST` | `/sos/{id}/ack` | "on my way" |
| `POST` | `/sos/{id}/arrived` | "I'm here" |
| `POST` | `/sos/{id}/decline` | "can't" — recorded, because it is what lets the next wave go early |
| `GET`/`POST`/`PATCH`/`DELETE` | `/contacts` | Lane 1, server-side |
| `POST` | `/contacts/{id}/test` | send a test SMS, set `verified_at` |
| `PUT` | `/availability` | opt in / out of being a responder, with hours |

**Rate limit:** 3 incidents per member per hour, 10 per day. Exceeding it does
**not** block the SOS — it raises the incident, alerts nobody beyond wave 1,
and flags it for an organiser. You never refuse someone who might be dying;
you contain the blast radius.

**Distance query:** bounding box on `(latitude, longitude)` then Haversine in
Python for the shortlist. Postgres/SQLite-portable, and at a few hundred
members it is microseconds. PostGIS when the roster passes ~50 000.

---

## 7. Privacy — the part that is not optional

Location is the most sensitive thing this app touches, and this is a club, not
a hospital.

- **Responder location is never stored.** The server keeps only a
  coarse "last known cell" per opted-in responder (~2 decimal places, ≈1 km),
  refreshed opportunistically, and only for those who opted in. It is used to
  rank, then discarded from the response.
- **A responder never sees another responder's position** — only the incident's.
- **The member's exact position is visible only to responders in the current
  wave, and only while the incident is live.** After stand-down it is coarsened
  to the place name in the timeline.
- **Opting in to respond is opt-in, per member, with hours** ("not between
  22:00 and 06:00"). Nobody is a responder by default.
- **The whole roster is district-bounded** by the same `is_covered` check the
  Complaint Box uses. Consistency matters: one definition of "our area".
- **Every incident is visible to the member who raised it, forever,** including
  who was told and who came. It is their event.

---

## 8. Screens

Five surfaces. The current feature has two, one of which is a menu.

### 8.1 The trigger — replaces the four-button sheet

Full screen, not a sheet. Dark, one thing on it.

```
      ┌─────────────────────────────┐
      │                             │
      │        ( hold  3s )         │   ← press-and-hold ring, fills
      │                             │      with heavy haptics
      │      Hold to send SOS       │
      │                             │
      │   ─────────  or  ─────────  │
      │                             │
      │   ☎  Call 112 now           │   ← always present, never gated
      │                             │
      │   Location: Vadasery ±12 m  │   ← state, not a feature list
      │   6 members within 1 km     │
      │   2 trusted contacts        │
      └─────────────────────────────┘
```

The three lines at the bottom are the replacement for the four green ticks.
They are **read from actual state**, and each one is a link to fix itself when
it reads badly (*"No trusted contacts — add one"*).

On release: a **five-second countdown filling the whole screen with CANCEL
underneath it**, siren already sounding, then it goes.

### 8.2 The live incident — what the member sees after

The screen that does not exist today, and the reason the feature is worthless
without it.

```
  SOS sent · 00:42
  ─────────────────────────────────
  Suresh K.      300 m   on the way ✓     ← the whole point
  Meena R.       800 m   on the way ✓
  4 others       told, no answer yet
  ─────────────────────────────────
  Amma           SMS sent 00:03
  Appa           SMS sent 00:03
  ─────────────────────────────────
  [ ☎ Call 112 ]      [ I'm safe ]
  [ Alarm: ON ]
```

`told, no answer yet` is the honest rendering of the 17–47% number. It is not a
failure message; it is the truth, and it is what tells the member to press
**Call 112**.

### 8.3 The responder alert — full-screen, not a notification row

Tapping the push opens straight into it. Three facts and two buttons:

```
   🆘  Arun Kumar needs help
       300 m away · Vadasery bus stand · 40 s ago

       [  I'm coming  ]      [  Can't  ]

       ── after accepting ──
       [ Navigate ]  [ Call Arun ]  [ I've arrived ]
```

"Can't" matters as much as "I'm coming": a decline sends the next wave early
instead of waiting out the timer.

### 8.4 Safety setup — replaces the settings screen

- Contacts with **names**, via the **system contact picker**, with a
  **Send test message** button that sets `verified_at`.
- **Be a responder** — off by default, with a radius and quiet hours, and one
  honest sentence: *"You'll be told when a member within 1 km needs help. Most
  people can't come, and that's fine — tapping Can't helps too."*
- **Shake to send** — off by default, and it now goes to the *trigger screen*
  with its countdown, not to a menu.
- A **rehearsal**: *Try it — nobody is alerted.* Nobody presses this button for
  the first time in an emergency and finds out then that they have no contacts.

### 8.5 Organiser: live incidents

`/safety/live` — what is open right now, who is going, and a **Stand down**
that requires ticking *"I have spoken to them."* An organiser guessing that
somebody is fine is exactly the inference this architecture exists to forbid.

---

## 9. Degradation ladder

Ordered by what survives what. Each rung runs even if the rung above failed.

| condition | behaviour |
|---|---|
| everything works | incident raised, wave 1 pushed, contacts SMS'd server-side, siren |
| no GPS fix | raised without coordinates; alert says **"location unknown"**, wave = whole district; the member is asked to say where they are in one tap |
| no network | **SMS from the device** to trusted contacts + a `SOS` SMS to the club's number; incident queued and posted when connectivity returns |
| app cannot start | the shell's red disc still dials 112 — no login, no network, no state |
| phone taken/destroyed | the **server** already SMS'd the contacts and pushed wave 1; nothing depends on the device staying alive |

Rung four is why contacts must live on the server, and rung five is why the
alert must be raised before anything else is attempted.

---

## 10. Mobile structure

Promoted out of `core/` into a real feature, in the same shape as
`blood_donation` and `complaint_box`:

```
lib/features/safety/
  domain/entities/      SosIncident · Responder · SafetyContact · SosEvent
  domain/repositories/  SafetyRepository        (no setStatus, by design)
  data/                 datasource · models · repository_impl
  presentation/bloc/    SosBloc (trigger + live) · ResponderBloc · SetupBloc
  presentation/screens/ sos_trigger · sos_live · responder_alert ·
                        safety_setup · live_incidents (organiser)
  presentation/widgets/ hold_ring · countdown · responder_row · readiness_row
```

`core/services/sos_service.dart` shrinks to what is genuinely
platform-plumbing and keeps its no-throw discipline:

- `SirenController` — moved to a **foreground service** so it outlives the
  screen, and stopped only by an explicit tap or stand-down;
- `ShakeDetector` — unchanged algorithm, now off by default and wired to the
  trigger screen;
- `LocationProbe` — returns position **with accuracy and age**, never bare
  coordinates.

---

## 11. What gets deleted

- `POST /api/v1/notifications/sos-alert` and its org-wide broadcast.
- The four-button `sos_sheet.dart`.
- The four green feature ticks, all of them.
- `SharedPreferences`-only contact storage — migrated on first launch.
- The string *"Works offline (SMS fallback)"*, which will be true only once
  rung three of §9 exists, and must not be written down before then.

---

## 12. Build order

Each step is shippable and leaves the app better than it found it.

1. **Stop lying.** Delete the four ticks; make every string a registry id in
   four languages; replace *"FYC members have been alerted"* with a real count.
   *One day. No new tables.*
2. **Make the trigger safe.** Press-and-hold + five-second countdown + cancel;
   siren to a foreground service; shake off by default and pointed at the new
   screen. *Two days.*
3. **The incident exists.** `SosIncident`/`SosResponder`/`SosEvent`, `POST
   /safety/sos`, nearest-5-within-1 km wave 1, the responder screen with
   I'm coming / Can't, the live screen with real counts, stand-down. **This is
   the step that turns the feature from theatre into a product.** *One week.*
4. **Contacts server-side.** Model, migration from device storage, names, the
   picker, the test message, server-side SMS so a lost phone does not silence
   the alert. *Three days.*
5. **Waves and escalation.** The 45 s / 90 s timers, decline-triggers-next-wave,
   organiser live board. *Three days.*
6. **Degradation.** Offline SMS path, queued incident, the honest
   "location unknown" alert. *Three days.*

Steps 1 and 2 alone move it from actively misleading to trustworthy. Step 3 is
where it becomes the thing only FYC can build.

---

## Sources

- [112 India / ERSS](https://112.gov.in/) — single emergency number; the SHOUT
  feature alerts registered volunteers in the vicinity
- [Kavalan SOS, Tamil Nadu Police](https://eservices.tnpolice.gov.in/CCTNSNICSDC/KavalanMobAppInformation)
  — five-second countdown, location + camera to the Master Control Room
- [Android Personal Safety / Emergency SOS](https://support.google.com/android/answer/9319337)
  — five-second countdown, cancellable; Safety Check with an end time
- [PulsePoint](https://www.pulsepoint.org/) — dispatch to opted-in volunteers
  within ~400 m
- [Predictive dispatch of volunteer first responders](https://mhealth.jmir.org/2023/1/e41551)
  — response rates of 17–47%; GoodSAM's three-nearest with 20-second escalation
