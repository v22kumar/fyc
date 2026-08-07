# Complaint Box — architecture

*புகார் பெட்டி. Written before the code, because the expensive mistakes here are
legal and social, not technical.*

---

## 1. The problem

A member sees a broken street light. They do not know it is the Assistant
Engineer's job, do not have his number, and would not know how to write to him
if they did. So nothing happens, and the light stays broken for a year.

The club knows all three things. That knowledge — not a mail server — is the
product.

## 2. What was already there, and what is wrong with it

`issues.py` sends every complaint through FYC's own SMTP, sets `reply_to` to
the member, and signs off *"Submitted via FYC Connect — Friends Youth Club,
Nagercoil."*

Three problems. The club becomes the publisher of whatever any member writes
about any contractor. A small club's SMTP mailing `nic.in` addresses in bulk
gets blocklisted, and the feature dies silently. And it needs an organiser to
approve each one, which stops working at about complaint number twenty.

---

## 3. The decisions

### 3.1 The member sends. The app drafts.

The club's contribution is the draft, the right officer, and the evidence
bundle. Never the connection.

This removes the liability (the club is a tool, like a word processor), makes
the complaint land as a citizen grievance rather than a campaign, sidesteps the
deliverability problem entirely, and needs nobody to be a registered entity.

It also **dissolves the spam problem instead of policing it.** Nobody spams a
District Collector from their own Gmail with their name on it. So the approval
gate goes — the bottleneck disappears because the thing it was guarding against
stops happening.

Using published government contact details is not the exposure. Being the
sender is.

### 3.2 Mechanism: an email intent, not the Gmail API

| | Verdict |
|---|---|
| **Email intent** (`ACTION_SENDTO` / `flutter_email_sender`) | **Chosen.** Opens their own mail app prefilled; they read, edit, send. Free, no review, handles long bodies and an attached photo. |
| `mailto:` via `url_launcher` | Fallback when no intent handler exists. Breaks on long bodies, cannot attach. |
| Gmail API, `gmail.send` scope | **Rejected.** The better product — real send confirmation, message ids, an automatic escalation clock — but it is a *restricted scope* needing a paid CASA security assessment, thousands a year and weeks of process, for an unregistered youth club. Serves only Gmail users. Revisit if the club registers. |

### 3.3 The consequence that shapes everything

**We cannot know whether they pressed send.** The app hands the draft to another
application and loses sight of it. Every screen must be honest about that rather
than paper over it.

---

## 4. Three routes

Most civic problems are fixed by a phone call. A letter is the slower, colder
way to ask. So:

```
Your report is ready.

→ Call someone        5 numbers, nearest first
→ Send it yourself    we will write it for you
→ Ask FYC to help     someone from the club will take it on
```

Nothing is forced, and routes combine. Calling, getting nowhere, then writing is
the normal path — and the letter should already know about the call.

### 4.1 Calling shows the whole ladder

```
Assistant Engineer — your ward       9xxxxxxxxx   ← start here
Assistant Executive Engineer         9xxxxxxxxx
Executive Engineer — division        9xxxxxxxxx
District Collector                   04652 279090
CM Helpline                          1100
```

**One number is worse than none.** If that single person does not answer, or
listens and does nothing, the member has no visible next step and stops. The
ladder makes the next step obvious from the first screen, and lets them judge
who is worth calling — they know things about the local office we do not.

Each rung states what it covers: *your ward*, *the division*, *the district*.

### 4.2 Calls are logged because the member says so

One tap afterwards: **reached / no answer / promised to act**. Nothing is
detected; the member is asked and believed.

This record is worth more than it looks. It becomes the opening line of any
letter that follows:

> *"I spoke to the Assistant Engineer on 5 August, who said it would be seen to.
> There has been no action since."*

That sentence is what makes a letter land with an Executive Engineer, and it
exists only because somebody tapped a button after a phone call. Calls feeding
the letter is what makes these one product rather than three buttons.

---

## 5. Serious issues go by mail, and the app says so

**A call leaves no evidence. A letter is dated, addressed, referenced and
quotable.** For anything serious that difference decides whether there is a
record when it matters.

At capture the member answers one question — *how bad is it?* — and the app
steers accordingly:

| | Steering |
|---|---|
| **Routine** — a light out, a pothole, uncollected rubbish | Call first. It is faster and usually enough. |
| **Serious** — a danger to someone, a repeated failure already reported, sewage or contaminated water, an office that has refused | **Write.** *"Put this in writing — a letter leaves a record you can point to later. Call as well if you like."* |

For serious complaints the app additionally:

- pre-selects the **next rung up** as a CC from the start, so the supervisor
  sees it at the same time as the officer
- keeps the photo, since evidence is the point
- shortens the escalation clock from 14 days to 7

The app suggests; it never blocks. A member who wants to call about a serious
problem may.

---

## 6. Two lanes, and who owns the truth

**Lane A — direct.** The member sends from their own mail. The club never sees
it.

**Lane B — via the club.** The member hands it to FYC. An organiser reads it and
either raises it with the department or closes it with a reason.

| | Lane A | Lane B |
|---|---|---|
| Who sends | The member | The club |
| Who knows it was sent | Only the member | The club |
| Who knows if anyone replied | Only the member | The club |
| Who sets the status | The member | The club |
| How much we track | What they tell us | All of it |

**In Lane A the member is the source of truth.** Not the server, not a webhook,
not an inference. The app asks and believes the answer.

**In Lane B the club is the source of truth,** and can be complete — the mail
really did leave its mailbox, and the reply really does come back to it.

---

## 7. Status, when we often do not know it

A list of rows reading `Unknown` looks like a bug. Three rules.

**7.1 Never show a status the system invented.** Every timeline entry names its
author:

> **You** · 5 Aug — *You said you called the Assistant Engineer. He promised to
> look at it.*
> **You** · 6 Aug — *You said you sent the letter.*
> **FYC** · 8 Aug — *Forwarded to the Executive Engineer, TWAD.*

A sentence with an author cannot be wrong in the way a floating badge can.

**7.2 Absence of news is a state with a name.** Not `Unknown` — **"Waiting to
hear · 12 days"**. True, useful, and what a person would actually say.

**7.3 The member can always close it.** Available on every complaint at any
time, whatever we know:

- **Mark resolved** — *the light is fixed*
- **Mark closed** — *I gave up*, or *I sorted it another way*. No judgement, no
  form.

Someone who fixed it by walking into the office must be able to say so. A
complaint that can only be closed by an event the app can observe stays open
forever, and an active list full of dead complaints is a list nobody opens.

Closed rows lock: no nudges, no escalation prompts, out of the active list, one
tap to reopen.

### 7.4 States

```
        ┌──────────┐
        │ CAPTURED │  what, where, photo, severity
        └────┬─────┘
   ┌─────────┼──────────────┬────────────────────┐
   ▼         ▼              ▼                    ▼
 CALLED   DRAFTED      HANDED_TO_FYC        (abandoned)
   │         │              │
   │         ▼              ▼
   │    SENT_BY_YOU    FYC_REVIEWING ──► FYC_FORWARDED
   │    (they said)         │                 │
   └────┬────┴──────────────┴─────────────────┘
        ▼
   WAITING_TO_HEAR ──► REPLY_RECEIVED
        │                    │
        └────────┬───────────┘
                 ▼
        RESOLVED / CLOSED     (locked; reopen in one tap)
```

`CALLED`, `SENT_BY_YOU` and `REPLY_RECEIVED` are only ever set by the member in
Lane A, and by the club in Lane B. The server never infers them.

---

## 8. The letter is a template, not a generated document

Asking a model to write the whole letter gives a different letter every time, a
bill for each one, and no letter at all when the quota runs out.

**The skeleton is code. The model fills two slots.**

```
To: <designation>, <office>
Subject: <slot: subject>

Sir / Madam,

<slot: body>

<if calls logged>
I contacted <office> by telephone on <dates>. <outcome>.
</if>

Location:  <place name>
           <Google Maps link>
Reported:  <date>
Photo:     <url, if any>
Reference: <short code>

<member name>
<member phone>
<member address>
```

The model is asked for exactly two things: a one-line subject, and three
sentences of formal description in the member's language. If it fails, the
member's own words fill the body slot and the letter still sends — plainer, not
broken.

This also removes the *"Submitted via FYC Connect"* footer, which in Lane A is
simply false. It is the member's letter and says so.

---

## 9. Location is a link

`GPS 8.1833, 77.4119` means nothing to an engineer reading mail on a phone.
Every complaint carries:

- the place as a person would say it — *"Vadasery bus stand, near the
  footbridge"* — reverse-geocoded, editable by the member
- a Google Maps link that opens the exact pin

Coordinates stay in the record for the app's own use and never appear in the
letter.

---

## 10. Numbers we are allowed to show

The current screen opens with *0 Issues Resolved · 0% Resolution Rate · 0.0 Days
Avg. Response · 0.0K Active Citizens* — four statistics, all zero, in four
unrelated colours.

Beyond being empty, most of these are **not knowable**. In Lane A we do not see
replies, so there is no response time. We do not learn outcomes unless somebody
tells us, so any "resolution rate" has unknowns in its denominator and is a
guess presented as a measurement.

**The rule: never publish a rate whose denominator contains things we did not
observe.**

What can be shown honestly:

| Number | Source | Shown as |
|---|---|---|
| Complaints raised | Observed | *"142 reports this year"* |
| Calls made | Member said so | *"members made 88 calls"* |
| Letters sent | Member said so | *"61 letters sent"* |
| Marked resolved | Member said so | *"37 of the 92 people who told us said it was fixed"* — denominator visible |
| Lane B outcomes | Club owns it | Full, including response times — this is the club's credibility, and it is real |

And: **nothing is shown until the sample is worth showing.** Below about twenty
complaints the strip stays hidden. Four zeroes at the top of a screen is the
loudest way to say the feature is unused.

Semantic colour is reserved for meaning — green for resolved, amber for waiting.
Neutral counts get one tone.

---

## 11. Sending from the club's mailbox

Built, shipped **switched off**.

Whether an unregistered club wants to be the sender of record is the club's
decision, not this document's, and it may change once the volume is visible.
Behind a setting, default off, invisible to members until deliberately enabled.

When enabled: a named organiser account, and a cap. A stuck loop mailing a
Collector two hundred times would end that relationship permanently.

---

## 12. Shape

Following the blood-donation feature, the cleanest thing in the app:

```
mobile/lib/features/complaint_box/
  data/          api client, models, repository impl
  domain/        entities, repository interface, usecases
  presentation/  bloc + event + state, screens, widgets
```

Server keeps the directory, the ladder rules, the draft slots, the public
tracker, the timeline. Server loses being the sender.

### Data model

- `Complaint` — what, where (lat/lng + place + maps url), photo, severity, lane,
  state, short code
- `ComplaintEvent` — the timeline. **Every row has an author** (`MEMBER`, `FYC`,
  `SYSTEM`) and a verb. This table is why the UI can never assert something
  nobody said.
- `ComplaintContact` — which rung was called or written to, and when
- `Authority` — exists already, with the ladder and jurisdictions

### API

```
POST   /civic/complaints                 capture
GET    /civic/complaints/{id}/ladder     contacts for this category + location
POST   /civic/complaints/{id}/draft      subject + body slots filled
POST   /civic/complaints/{id}/events     "I called", "I sent it", "they replied"
POST   /civic/complaints/{id}/resolve    resolved | closed(reason)
POST   /civic/complaints/{id}/handover   → Lane B
GET    /civic/inbox                      Lane B queue (organisers)
```

### Screens

1. **Capture** — photo first, description, location confirm, one severity question
2. **What next** — the three routes, steered by severity
3. **Ladder** — the stack of contacts, call buttons, log-the-call prompt
4. **Draft** — the letter, editable, then hand to their mail app
5. **My complaints** — active and closed, "waiting 12 days", the two close buttons
6. **Detail** — the authored timeline
7. **FYC inbox** — organiser triage (Lane B)

---

## 13. Build order

1. **Template, Maps link, ladder** — improves the letter that exists today, and
   the ladder is the highest-value screen. Neither needs an open decision.
2. **Capture → routes → call logging** — Lane A without the letter.
3. **Draft → hand-off → member-owned timeline → the two close buttons.**
4. **Severity steering**, once there is a real letter to steer towards.
5. **Lane B** — the club inbox and triage.
6. **The ladder in motion** — escalation is Lane A one rung up, quoting the
   previous letter and the logged calls.
7. **Honest statistics**, last, when there is a sample.

---

## 14. Open, and needing a person

- **The source URL of the scraped Collectorate contacts.** Blocks importing the
  17 offices already matched. Only the person who fetched the page knows it.
- **Does the club want a BCC copy** of Lane A letters? A privacy decision.
- **Not legal advice.** The member-sends model removes the largest exposure by
  not making the club the publisher. It does not make the question disappear.
