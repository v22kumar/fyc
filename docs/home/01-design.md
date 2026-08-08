# Home — the redesign

*The club could not name the one thing a member should do first. That turned
out to be the right answer, and it decides the architecture.*

---

## 1. The question was wrong

"What should a member do first?" assumes one answer. There isn't one: somebody
opens this app to read the news, somebody else to find a carpenter, somebody
else to check whether their pothole got fixed. Asking the club to pick one
would have produced a guess, and the guess would have been wrong for most
people most days.

**A home screen that cannot name its primary action must stop trying to
present all of them.**

## 2. What the research says instead

The 2026 work is consistent on two points.

**Every extra element on screen has a measured cost.** Cognitive engineering
research puts it at **1.8× more fixations and 410ms more dwell time per
unnecessary element**. Home has fifty-two. That is not a metaphor for
"cluttered" — it is roughly twenty seconds of extra looking before a member
does anything.

**The alternative to guessing is context, not personalisation theatre.**
Conventional home screens are static grids "constant throughout the day",
while a context-driven one surfaces "the most relevant content based on
current context — time, location, activities, calendar events, alerts". No
machine learning required: the app already knows whether a match is live,
whether a blood request is open, and whether somebody's complaint has been
waiting eleven days.

## 3. The decision

**Home answers "what is happening, and what is waiting for you" — not "what
can you do".**

The launcher does not disappear. It stops being the point.

    ┌──────────────────────────────┐
    │  Header — compact             │  one row, not four
    │  Search                       │
    ├──────────────────────────────┤
    │  NOW                          │  0–2 cards, from real state.
    │  • Match live, 14.2 overs     │  Empty most days, and that is
    │  • B+ needed at Asaripallam   │  correct — an empty NOW is a
    │                               │  quiet Tuesday, not a bug.
    ├──────────────────────────────┤
    │  WAITING FOR YOU              │  only if something is.
    │  • Your complaint, 11 days    │  This is the screen's real job:
    │  • 3 team approvals           │  nobody else will tell them.
    ├──────────────────────────────┤
    │  Today                        │  the briefing, collapsed to
    │  Summary · Kural · Weather    │  one band instead of three
    │                               │  full-height cards
    ├──────────────────────────────┤
    │  Everything                   │  the launcher: eight compact
    │  ▣ ▣ ▣ ▣                      │  tiles, four across, one
    │  ▣ ▣ ▣ ▣                      │  screen — not three
    ├──────────────────────────────┤
    │  News — lead + list           │  as an edition, not a search
    └──────────────────────────────┘

### Why this order

**NOW is above everything because it is the only part that expires.** A live
match is worth nothing tomorrow. Tiles are worth exactly the same tomorrow, so
they can wait.

**WAITING FOR YOU is second because it is the thing only this app can say.**
Google can tell a member the news. Nobody else can tell them their complaint
has had no reply for eleven days, or that three teams need approving before
Saturday. That is the app's unique claim on somebody's attention and it
currently sits below four screens of tiles.

**The briefing drops from three cards to one band.** Today's Summary, the
Kural and the weather are all "nice to see" rather than "act on", and between
them they occupy about 1,400 points. Collapsed, they take 200 and lose nothing
a member needed.

**Tiles go from seven at ~380pt each to eight at ~110pt.** Seven tiles is 2,600
points — three full screens to present seven links. Four across at icon-plus-
label is one screen for all of them, and a launcher is scanned, not read.

## 4. Richness is not the thing to cut — I had this wrong

My first pass read "fewer elements" as "make it minimal", and the club
corrected it: they want gradients, imagery, overlays, depth. A wow factor.

**They are right, and the two things are not in conflict.** The research
measures the cost of *decisions*, not of *pixels*. Fifty-two things to choose
between is expensive. A gradient is free. Confusing the two is how a design
review ends up recommending grey rectangles and calling it discipline.

So the target is not minimal. It is **fewer things, each of them far richer**
— which is what the apps that feel expensive actually do. A streaming service
home is visually enormous: full-bleed artwork, scrims, saturated colour. It is
also about six decisions.

Concretely, for this Home:

**A mesh-gradient ground, not a flat one.** Several soft radial gradients
blended behind the whole page, shifting slowly with scroll. It reads as depth
rather than as a background colour, and it costs nothing to look at because
there is nothing in it to decide about.

**Full-bleed imagery with a scrim, on the few cards that matter.** A live
match, a blood request, the kural. Image, then a gradient scrim so text stays
legible over any photograph, then the words. This is the pattern every premium
app uses and it is the single biggest change in perceived quality.

**Saturated glass for the launcher.** The tiles get smaller in *height* and
much stronger in *colour* — a tinted translucent surface over the mesh, with
the blur showing through. Eight of those in one screen looks considered; seven
tall pale boxes over three screens looks unfinished.

**Depth as a system.** Two shadow levels and one blur level, used
consistently, so the page has a foreground and a background instead of one
plane.

**Motion that reports rather than performs.** A score that ticks, a
waiting-days count that increments, a NOW card that slides in when a match
starts. Motion attached to real change makes an app feel alive; motion
attached to navigation makes it feel slow.

The rule that keeps both honest: **richness goes into the things that are
staying, not into the number of things.**

## 5. Honest constraints

**NOW will be empty most days.** A club in Nagercoil does not have a live match
every afternoon. The design has to be good when NOW and WAITING are both
empty — which is the ordinary case, and where a launcher-first layout would
have been the right answer all along. So on a quiet day Home is: header,
briefing band, tiles, news. Which is a better quiet day than five thousand
pixels.

**This is a large change to a 2,641-line file.** It is staged: the state that
drives NOW and WAITING first, then the launcher compaction, then the briefing
band. Each is shippable alone.

---

## Sources

- [Adaptive UI: Interfaces That Learn From User Behavior](https://medium.com/@marketingtd64/adaptive-ui-creating-interfaces-that-learn-from-user-behavior-a69af1c2fe09)
- [Hyper-personalization: a practical UX guide](https://uxdesign.cc/hyper-personalization-a-practical-guide-8e5f7b89e26e)
- [Context-based user interface (patent, on context-driven surfacing)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10834546)
- [Nova Launcher: measured efficiency gains from removing elements](https://lifetips.alibaba.com/tech-efficiency/nova-launcher-updates-with-more-home-screen-customizati)
- [Mobile App Experience in 2026: Why Apps That Ask Less Win More Users](https://userpilot.com/blog/app-experience/)
