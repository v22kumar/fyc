# Consent for location, without a wall of toggles

The instinct is right: a second, separate opt-in for the app-open position would
be answered "no" by most people, and a feature nobody opts into is a feature
that does not exist. We are not adding a toggle.

But putting it only in the privacy policy does not work either, for two reasons
that are practical rather than philosophical.

## 1. Android will ask anyway

The operating system owns the location permission. There is no arrangement of
policy text that lets the app read a position without the system prompt
appearing. **The member will be asked regardless.**

So the choice was never "ask or don't ask". It is only whether the app has
explained itself before the system prompt appears, or whether that prompt
arrives cold. A cold prompt is the one that gets denied — and on Android a
denial is sticky, so the feature is lost for that member more or less
permanently.

Framing the ask is therefore not a cost to be minimised. It is the thing that
determines whether the answer is yes.

## 2. Play policy, and the DPDP Act, both want specifics

Two rules bear on this, and both are about what happens before the permission
is requested, not what is written in a document elsewhere.

**Google Play** requires a prominent in-app disclosure for location access —
what is collected and why — shown before the request, and a Data Safety
declaration that matches the app's behaviour. Apps get removed over this, and we
are days from a launch.

**India's DPDP Act 2023** asks for consent that is specific and informed, with an
itemised notice saying what data and for what purpose, and withdrawal that is as
easy as giving it. A blanket acceptance covering everything is weaker than it
looks under that standard.

Neither rule demands a settings screen. Both demand that at the moment we ask,
the member knows what they are agreeing to.

## What we do instead

**Ask once, in context, where the reason is obvious.**

When someone registers as a donor — the moment they have already decided to
help — one screen, in their language, saying plainly:

> To show you to people nearby who need blood, the app records roughly where you
> are when you open it. It does not track you in the background.
>
> [ Share my location ]   [ Not now ]

Then the system prompt. That is the whole interaction, it happens once, and it
happens when the purpose is self-evident rather than in a settings list nobody
opens.

This converts better than either alternative. A prompt with a visible reason at
a relevant moment is accepted far more often than a cold system dialog, and far
more often than a toggle buried where only the cautious go looking.

The privacy policy still describes all of it — but as the **record**, not the
mechanism. It is where someone goes to check what they agreed to, not where
they are supposed to have discovered it.

## What this means in the schema

`location_consent` stays. It is the stored answer to that one question, and it
is what makes withdrawal possible — which the DPDP Act requires and which is
right anyway.

What we are *not* doing is adding a second flag for last-seen. One ask covers
both positions, because the member was told plainly what both are for. Splitting
the flag would recreate the toggle wall by another route.

The honest boundary is this: **one clear ask, covering a stated purpose.** If we
later want the position for something the member was not told about — tracking a
lost phone, say — that is a new purpose and needs its own ask. Reusing a
donor-matching consent for location tracking would be exactly the kind of quiet
scope creep that costs a small club its standing.

## How it is built

`core/location/location_disclosure.dart` holds the sheet;
`core/location/member_location.dart` is the only place in the app that asks the
phone for a position. Everything else calls one of three methods, and the choice
between them is a design decision, not a convenience:

| | Asks the member? | Wakes the GPS? | Used by |
|---|---|---|---|
| `forRanking` | yes, once | no — cached fix | the donor list, the map |
| `precise` | yes, once | yes | pinning a home area at registration |
| `ifAlreadyAllowed` | never | no — cached fix | raising a blood request |

Two rules follow from the table.

**Never ask mid-task.** Someone who has tapped *submit* on a blood request is
not in a state to read a disclosure, and a sheet answered in a panic is not
consent. That path takes a position only if one was already granted elsewhere.

**Never spend the ask on nothing.** If location services are switched off at the
system level, agreeing achieves nothing — so the sheet is not shown at all, and
the one chance survives until it can actually be used.

Five screens each had their own copy of this logic before, and every copy called
`requestPermission` cold. Whichever screen a member happened to open first got to
spend the single permanent chance to ask, with no explanation attached.

### Recovering from a fumbled prompt

"Not now" is remembered and we do not ask again. But if the member agreed to
*us* and then the system dialog was dismissed or missed, that is not a decision
to hold them to — the flag stays unset and the next visit tries once more.
Android permits one further prompt before it stops asking for good, and that is
worth spending. A permanent denial is recorded and never re-asked, because the
system would not honour it.


## The switch starts on, and that is still consent

Registering as a blood donor already means *find me*. Leaving the location
switch off by default meant people lost the feature by not noticing it — which
in an emergency is the expensive kind of quiet, and nobody ever discovers it,
because what they see is simply not being asked.

The reason it was not safe to flip before is that two different things were
living in one switch:

| | what it is | can it be pre-set? |
|---|---|---|
| **Willingness to be located** | an intent, already stated by opening a screen called "Register as donor" | yes |
| **Permission to read the GPS** | owned by Android, and the DPDP Act wants a clear affirmative act | never |

So they are separated. The switch expresses the intent and starts on. The
permission is still asked once, at submit — through the same disclosure sheet
as everywhere else, never on screen open, never as a pre-ticked substitute for
an answer. The affirmative act is unchanged: they press *Register as donor*
with the switch visibly on, and then they agree on the sheet.

Turning it off now says what it costs, rather than leaving it to be discovered:
you stay in the directory, you stop appearing in "nearest to me".

### Consent and coordinates are two different columns

The server was making the same conflation, and it was worse there:

```python
consent = bool(payload.location_consent
               and payload.latitude is not None
               and payload.longitude is not None)
```

A member who said yes and then missed the Android dialog was recorded as having
said **no**. The yes was gone, with nothing to indicate it had ever been given —
so the opportunistic capture designed for exactly this case could never fire,
because `PATCH /me/location` is a no-op without consent.

`location_consent` now stores the answer as given. Coordinates arrive when they
arrive — the next time that member opens the blood screen — and the feature
starts working on its own. Coordinates *without* consent are still refused,
which is the direction that matters for privacy.


### The switch is set by Android, not by hope

Defaulting it on is only safe if it is also *corrected*. A switch reading
"sharing my location" while the operating system has the permission blocked is
not a preference — it is a false promise, and the member goes on believing they
are findable in an emergency with nothing on the screen to tell them otherwise.

So the screen reads the real state on open, and again whenever the member comes
back from system settings:

| Android says | switch | what the card says |
|---|---|---|
| granted | **on** | nothing left to ask |
| not asked yet | **on** | intent; the permission is requested at submit |
| blocked | **off** | *"Your phone is blocking location for this app"* + **Open phone settings** |
| services off | **on** | *"Location is switched off on this phone. Turn it on and this will start working."* |

Tapping the switch on while Android has it blocked does not flip it. There is
exactly one place that can be changed, so the app opens it and then **re-reads
the answer** rather than assuming the member did what they were sent to do.

`blocked` is the only state that forces the switch off, because it is the only
one we cannot honour. Services being off is temporary and nobody's fault; the
intent survives it.
