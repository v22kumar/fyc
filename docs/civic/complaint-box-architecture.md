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
