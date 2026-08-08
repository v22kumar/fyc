# Home — audit

*From six full-scroll screenshots of the running app, and the source behind
them. Current self-rating from the club: 4.5–5 out of 10, down from 7 two
months ago — not because Home got worse, but because everything around it got
better and the bar moved.*

---

## 1. The size of the thing

**53 tappable elements on one screen.** That is a count from the source
(`grep -cE "onTap|onPressed|GestureDetector|InkWell"`), and the screenshots
confirm it: roughly 5,000 pixels of scroll, six phone-screens tall.

Counted by group, what a member can act on without leaving Home:

| Group | Actions |
|---|---:|
| Sticky header — language, bell, avatar, search, search filter | 5 |
| Today's Summary (AI prose) | 1 |
| News Digest + 3 topic chips | 4 |
| Manager Dashboard bar | 1 |
| "Explore FYC" View All + Sports hero | 2 |
| Service tiles | 7 |
| Pending Items — header + tile | 2 |
| Community — header + tile | 2 |
| Our Impact stats | 4 |
| Recent Reports — header + tile | 2 |
| Thirukkural card | 1 |
| News — 5 tabs, refresh, ~8 headlines | 14 |
| Weather | 1 |
| Floating: FAB, SOS | 2 |
| Bottom nav | 4 |
| **Total** | **~52** |

The 2026 research is blunt about what this costs: poor information
architecture produces "information overload, decision paralysis and high
bounce rates", and the guidance for a phone is **one primary action per
screen, secondary actions clearly secondary, and no third level fighting for
attention.**

Home currently has **three separate action systems competing at once** — a
bottom nav, a floating "+" and a floating SOS — on top of seven tiles and four
"View All" links.

---

## 2. Bugs visible in the screenshots

These are not taste. They are wrong.

### 2.1 ~~The weather says Bengaluru~~ — wrong, this was my error

I called this a bug. It is not: the member looking at that screenshot was in
Bengaluru, and the card was correctly reporting where they actually were.

Left in rather than deleted, because it is the more useful kind of mistake to
record — I read a screenshot, assumed the app's audience matched the app's
subject, and reported a working feature as broken. A club *for* Nagercoil is
used *by* people who travel.

### 2.2 Sports Arena appears twice — confirmed in the source

Confirmed rather than assumed this time. `home_screen.dart:754` renders
`_FeaturedSportsHero`, whose button calls `context.push('/sports')`;
`home_screen.dart:685` adds a tile with `route: '/sports'`. Both carry
`trId('sports_arena')` and `trId('tournaments_chess_live_scores')`.

Same title, same subtitle, same destination, about two hundred points apart in
the same scroll. A member has to work out whether these are two things.

### 2.3 The news presentation

Where the stories come from is a separate piece of work the club is handling —
Google RSS, after an experiment with Firecrawl. So the *source* is not the
question here. How it is shown is, and it is the weakest thing on the screen.

The same headlines repeat between screens. Every item is attributed to
**"Firecrawl"**, which is a scraping vendor rather than a publisher, so a
member reads it as the name of a newspaper. Several "headlines" are not
headlines: *"kanyakumari news"*, *"Kanyakumari district"*, *"Today Breaking
News | Kanyakumari Updates"* — those are search-result titles, so the card is
showing the query rather than the story.

And the shape is a plain list: five tabs, then eight near-identical rows of
grey text with an arrow. Nothing distinguishes an important story from a
routine one, nothing carries an image, and every row costs the same glance as
every other. It reads as a search results page, which is exactly what it is.

### 2.4 The floating "+" covers content

In three of the six screenshots the orange "+" sits directly on top of the
"Open →" of a tile — the Events tile, and Report an Issue. The single most
common control on the screen is being obscured by a button whose purpose is
not stated anywhere.

---

## 3. The architectural problem

Not the tiles. **Home has no answer to "what is this screen for".**

Every section is defensible alone. Together they are four different products
stacked in one scroll:

1. **A briefing** — Today's Summary, News Digest, Thirukkural, weather, news
2. **A launcher** — seven service tiles plus a hero
3. **A dashboard** — Pending Items, Team Approvals, Recent Reports, Impact
4. **An action bar** — FAB, SOS, bottom nav

A launcher wants to be scannable and identical every time. A briefing wants to
change daily. A dashboard wants to show *my* state. They have opposite
requirements, and interleaving them means none of them is good: the briefing
is buried under tiles, the tiles are buried under prose, and the dashboard is
somewhere in the middle where nobody scrolls.

**The most valuable space on the screen — the first viewport — is spent on two
blocks of AI prose**, about twenty lines, before a single thing a member can
tap to *do* anything.

### What the research says to do about it

> Mobile-first architecture forces focus — fewer entry points, clearer
> hierarchy, and faster paths to action… overloaded navigation, duplicated
> elements, and unclear priorities are inherited complexity.

> Most mobile UX problems are attention-management problems, not design
> problems, and reducing the number of decisions matters more than reducing
> the number of taps.

Home does not need fewer *features*. It needs to stop asking the member to
choose between fifty-two of them on arrival.

---

## 4. Smaller things worth naming

**The sticky header takes about 30% of the viewport** — logo, club name, three
circular buttons and a full search bar, permanently. On a 844pt screen that is
250pt of chrome above every single thing.

**"View All" appears four times**, each going somewhere different, none of
them saying where.

**The impact numbers are round and undated** — 1500+, 1200+, 80+, 5000+. They
read as decoration rather than as facts, which is the same failure the
Complaint Box rating rule was written about: a number nobody can check is
worth less than no number.

**Tiles are enormous for their content.** Each is roughly 380pt tall to hold a
title, one line of subtitle and an "Open →". Seven of those is 2,600pt of
scroll — three screens — to present seven links.

**Settings is not on Home at all.** It is behind the avatar, which is not
labelled. Members look for it and do not find it.

**The Thirukkural card is ~700pt** — Tamil verse, Tamil gloss, English
translation, attribution. Lovely, and larger than any service on the screen.

---

## 5. What this is not

The club likes this Home page, and it is genuinely much better than what came
before it. Nothing here says it is ugly. The problem is not the styling — the
cards, colours, illustrations and typography are good and should survive.

**The problem is that everything is on it, equally, at once.**

---

## 6. Open question, before redesign

Only the club can answer: **what should a member do first, on an ordinary
Tuesday?**

Not "what could they do" — the screen already answers that fifty-two times.
What is the *one* thing that, if it happened, would mean Home did its job? The
answer decides everything above the fold, and every proposal that follows is
guesswork without it.

---

## Sources

- [Information Architecture: 2026 Guide to Site Structure](https://www.parallelhq.com/blog/what-information-architecture)
- [Mobile App Experience in 2026: Why Apps That Ask Less Win More Users](https://userpilot.com/blog/app-experience/)
- [Mobile Application Architecture: A Practical 2026 Guide](https://capgo.app/blog/mobile-application-architecture/)
- [Mobile UX Design: A Complete Guide for 2026](https://uxcam.com/blog/mobile-ux/)
