# Complaint Box — architecture

*Decision record. Written before the code, because the wrong answer here is
expensive to unwind and the cost is legal, not technical.*

## The question

A member sees a broken street light. They do not know how to write to the
Assistant Engineer, and would not know it was the Assistant Engineer. The app
knows both. Who presses send?

Today the club does: `issues.py` sends through FYC's own SMTP, sets `reply_to`
to the member, and signs off *"Submitted via FYC Connect — Friends Youth Club,
Nagercoil."* That makes the club the sender of record for every complaint any
member writes.

## Decision

**The member sends, from their own mail account. The app writes the draft.**

The club's contribution is the draft, the right officer, and the evidence
bundle — never the connection.

### Why

**Liability.** A complaint naming a contractor, sent from the club's mailbox, is
the club's publication. Sent from the member's own address with their name and
number, the club is a tool — the same as a word processor. Using published
government contacts is not the exposure; being the sender is.

**Spam stops being a problem to solve.** Nobody spams a District Collector from
their own Gmail with their name on it. The friction is exactly right, which
means **the approval gate can go**. That gate does not scale — an organiser
approving a hundred complaints one at a time is a bottleneck, and it quietly
makes them a censor deciding whose grievance counts.

**Officials treat it as a citizen grievance.** The same words from a club
mailbox "on behalf of" a resident read as a campaign and get discounted.

**Deliverability.** A small club's SMTP sending bulk mail to `nic.in` addresses
gets filtered, then blocklisted. The feature would die silently and nobody would
find out for weeks.

**No registration question.** Nobody needs to be a registered entity to help a
neighbour write a letter.

## How, concretely

Three ways to send from a member's own Gmail. They are not close.

### 1. Email intent — CHOSEN

`ACTION_SENDTO` with the draft prefilled, or `flutter_email_sender`. The member's
own mail app opens with recipient, CC, subject and body filled; they read it,
edit it, press send. It leaves from their real account and lands in their Sent
folder.

- Costs nothing, needs no review, ships this week.
- Handles long bodies and an attached photo, which a raw `mailto:` URI does not.
- `url_launcher` is already a dependency; `mailto:` is the fallback when no
  intent handler exists.

### 2. `mailto:` link — FALLBACK

Same model, simpler. Breaks on long bodies (URI length) and cannot attach. Kept
only for devices where the intent finds no handler.

### 3. Gmail API with the `gmail.send` scope — REJECTED

Genuinely the best product: we would know it was sent, hold the message id,
thread the follow-ups, and run the escalation clock automatically.

Rejected because `gmail.send` is a **restricted scope**. Google requires an
independent CASA security assessment — thousands of dollars a year and weeks of
process — for an app that would be doing this on behalf of an unregistered
youth club. It also only serves Gmail users. Revisit if the club is ever
registered and the volume justifies it.

## The consequence that shapes everything

**We cannot know whether they pressed send.** The app hands the draft to another
application and loses sight of it. Every part of the design has to be honest
about that rather than paper over it.

So:

- A complaint is never marked sent automatically. On return the app asks once:
  *"Did you send it?"* — one tap.
- `DRAFTED` and `SENT` are different states, and `DRAFTED` is not a failure. A
  member who drafted and thought better of it has done nothing wrong.
- **Opt-in BCC.** *"Keep a copy with the club so we can follow it up"* — plain
  words, off by default. When on, the club receives the mail, which is real
  proof of sending and starts the escalation clock without anyone being asked.
  Off, the member is on their own timeline and the app just nudges.
- The escalation ladder cannot read their inbox — reading Gmail is a restricted
  scope too. After 14 days it asks: *"Has anyone replied?"* If not, it drafts
  the next rung.

## The ladder

The feature that actually gets things fixed, and it requires sending nothing:

    Assistant Engineer / VAO  →  Tahsildar / Executive Engineer
      →  RDO  →  District Collector  →  CM Cell (1100)  →  CPGRAMS

Each rung is a fresh draft quoting the previous one and its date. The directory
already holds all six.

## Club-sent, as a narrow exception

Some members have no email at all. For them the current path stays: organiser
approves, club sends. Small volume, so the gate works there — it just stops
being the default. Capped per member per week.

## Naming

**Complaint Box** — புகார் பெட்டி. A familiar civic object, and broad enough for
anything. Replaces "Report an issue".

## Shape

Following the blood-donation feature, which is the cleanest thing in the app:

    features/complaint_box/
      data/          api client, models, repository impl
      domain/        entities, repository interface, usecases
      presentation/  bloc + event + state, screens, widgets

Server keeps: the directory, the AI draft, the ladder rules, the public tracker,
the timeline. Server loses: being the sender.

## Open, and needing a human

- The exact source URL for the scraped Collectorate contacts (blocks import).
- Whether the club wants the BCC copy at all — it is a privacy call, not a
  technical one.
- Not legal advice. The member-sends model removes the largest exposure by not
  making the club the publisher; it does not make the question disappear.

---

# Two lanes

The decision above answered *who presses send*. It left out that there are two
different journeys, and only one of them is the club's business.

## Lane A — straight to the department

The member writes it, the app drafts it, **they** send it from their own mail.
The club never touches it and never sees it.

## Lane B — to the club

The member sends it **to FYC**, because they want help, or the office ignored
them, or they would rather someone else dealt with it. Now the club owns it: an
organiser reads it and either raises it with the department or closes it with a
reason.

Lane B is the second priority to build, but it is the one that makes the club
useful rather than merely helpful — and it is the only lane where the club can
honestly claim to know anything.

## Who owns the truth, per lane

This is the whole design. Every screen follows from it.

| | Lane A — direct | Lane B — via the club |
|---|---|---|
| Who sends | The member, from their own mail | The club, from the club's mail |
| Who knows it was sent | Only the member | The club |
| Who knows if anyone replied | Only the member | The club |
| Who sets the status | The member | The club |
| How much we track | As much as they tell us | All of it |

**In Lane A the member is the source of truth.** Not the server, not a webhook,
not a guess. The app asks and believes the answer.

**In Lane B the club is the source of truth**, and it can be complete, because
the mail genuinely went from the club's mailbox and the reply comes back to it.

# Making unknown state not look broken

The hard part. We often will not know the stage of a Lane A complaint, and a
list of rows reading `Unknown` looks like a bug.

Three rules:

**1. Never show a status the system invented.** Every entry on the timeline
carries an author, and the UI says who:

> **You** · 5 Aug — *You said you sent this to the Assistant Engineer*
> **FYC** · 6 Aug — *Forwarded to the Executive Engineer, TWAD*

Not "Sent" floating with no subject. A sentence with an author cannot be wrong
in the way a status badge can.

**2. Absence of news is a state, and it has a name.** Not `Unknown` —
**"Waiting to hear"**, with the days visible: *waiting 12 days*. That is a true
and useful thing to display, and it is what a person would actually say.

**3. The member can always close it.** Two taps available on every complaint,
at any time, regardless of what we know:

- **Mark resolved** — *"the light is fixed"*. Nothing else needed.
- **Mark closed** — *"I gave up"* or *"I sent it another way"*. No judgement, no
  form.

A member who fixed the problem by walking into the office should be able to say
so. A complaint that can only be closed by an event the app can observe is a
complaint that stays open forever and makes the list useless.

Once closed, the row is locked: no more nudges, no escalation prompts, and it
moves out of the active list. Reopening is one tap if they were wrong.

# The letter is a template, not a generated document

Asking an AI to write the whole letter gives a different letter every time, and
a bill for each one. Worse, when the quota runs out or the call fails there is
no letter at all.

**The skeleton is code. The AI fills two slots.**

Fixed, written once, identical every time:

    To: <designation>, <office>
    Subject: <slot: subject>

    Sir / Madam,

    <slot: body>

    Location:  <place name>
               <Google Maps link>
    Reported:  <date>
    Photo:     <url, if any>
    Reference: <short code>

    <name>
    <phone>
    <address>

The AI is asked for exactly two things: a one-line subject, and three sentences
of formal description in the member's language. Nothing else. If it fails, the
member's own words go in the body slot and the letter still sends — it is
plainer, not broken.

This also fixes something the current draft gets wrong: it appends
*"Submitted via FYC Connect — Friends Youth Club, Nagercoil"*, which in Lane A
is false. In Lane A the letter is from the member and says so.

# Location is a link, not coordinates

`GPS 8.1833, 77.4119` means nothing to an Assistant Engineer reading mail on a
phone. Every complaint carries:

- the place as a person would say it — *"Vadasery bus stand, near the
  footbridge"* — from reverse geocoding, editable by the member
- a Google Maps link that opens the exact pin

Coordinates stay in the record for the app's own use and never appear in the
letter.

# Build order

1. The template and the Maps link — improves the letter that already exists.
2. Lane A end to end, with the member-owned timeline and the two close buttons.
3. Lane B — the club inbox, triage, forward, and its fuller timeline.
4. The ladder, which is just Lane A again one rung up, quoting the last letter.

---

# Three routes, and mail is not the first one

The design so far assumed every complaint is a letter. Most are not. A blocked
drain is usually fixed by ringing the right person, and a letter is the slower,
colder way to ask.

So the screen offers three routes, in this order:

## 1. Call someone — the default

Show the **whole ladder**, not the one "correct" officer:

    Assistant Engineer — your ward          9xxxxxxxxx     ← start here
    Assistant Executive Engineer            9xxxxxxxxx
    Executive Engineer, division            9xxxxxxxxx
    District Collector                      04652 279090
    CM Helpline                             1100

Showing a single number is worse than showing none. If that one person does not
pick up, or listens and does nothing, the member has no visible next step and
stops. The ladder makes the next step obvious from the first screen, and it
lets them judge for themselves who is worth calling — often they already know
someone, or know that the ward office is useless on a Friday.

Each rung shows what it covers, so the choice is informed rather than a guess:
*"your ward"*, *"the whole division"*, *"the district"*.

**Calls are logged because the member says so, not because we detect them.**
One tap after the call: *did you get through?* — reached / no answer / promised
to act. That record is worth more than it looks: it becomes the first line of
the letter if one is needed later.

> *"I spoke to the Assistant Engineer on 5 August, who said it would be seen
> to. There has been no action since."*

That sentence is what makes a letter land, and it exists only because someone
tapped a button after a phone call.

## 2. Write it yourself

The app drafts it, supplies the right address, and hands it to their own mail
app. As decided above. This is where people go when calls have failed, or when
they want a record.

## 3. Hand it to FYC

The club takes it on. An organiser can ring the department, write from the
club's own name, or close it with a reason. This is for members who would
rather not deal with an office at all — which is a real and reasonable
preference, not a failure on their part.

# Sending from the club's own mailbox

Build it, ship it switched off.

The capability is small and the decision is not ours: whether an unregistered
club wants to be the sender of record is a question for the club, and the
answer may change once the volume is visible. So the code exists behind a
setting, defaults to off, and no member sees the option until someone turns it
on deliberately.

Turning it on should require a named organiser account, and should be capped —
a stuck loop that mails a Collector two hundred times would end the club's
relationship with that office permanently.

# What this means for the screen

The complaint is captured once — what, where, a photo. Then the member chooses
what to do with it, and can do more than one thing:

    Your report is ready.

    → Call someone        (5 numbers, nearest first)
    → Send it yourself    (we will write it for you)
    → Ask FYC to help     (someone from the club will take it on)

Nothing is forced. A member who calls, gets nowhere, and then writes has done
the normal thing, and the letter should already know about the call.
