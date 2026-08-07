# Complaint Box — UI/UX rating

Rated by rendering the real widget tree at 390×844 with the app's typeface and
looking at it. Target: **9.0**.

## Rubric

Ten points, weighted by what actually decides whether a member in Nagercoil gets
their street light fixed.

| # | Dimension | Weight | What a 9 looks like |
|---|---|---|---|
| 1 | **Does the job** | 3 | The member knows who to ring and can ring them in one tap. Nothing important is off-screen or unstated. |
| 2 | **Honesty** | 2 | Nothing is claimed that nobody said. Every copy recipient is disclosed. Gaps are visible without being alarming. |
| 3 | **Visual craft** | 1.5 | Consistent rhythm, one type scale, restrained colour, semantic colour used only semantically. |
| 4 | **Modern feel (2027)** | 1.5 | Material 3 surfaces and tonal elevation, generous radii, motion that explains rather than decorates, haptics on commitment, content-first layout. |
| 5 | **Accessibility** | 1 | 48dp targets, AA contrast, screen-reader labels on every action, text scales to 200% without loss. |
| 6 | **Engineering** | 1 | Const where possible, no rebuild storms, no god widgets, states handled (loading / empty / error / offline), dark parity. |

## Round 1 — 8.5

Rendered the widgets and read the code. Six defects, three of them invisible
until you look at the pixels and three invisible until you read the source.

| Dimension | Score | Why |
|---|---|---|
| Does the job | 8 | No phone numbers on a screen whose job is phone numbers. "Start here" never rendered. The Write button drafted to nobody. |
| Honesty | 8 | A serious complaint copied the supervisor without telling the member. Failed actions were silent. |
| Visual craft | 7 | Two amber warnings dominating four rows. Nothing read as a ladder. |
| Modern feel | 6 | No motion, no haptics, plain sheets, flat surfaces. |
| Accessibility | 4 | No screen-reader labels anywhere. A phone number read as one ten-digit integer. |
| Engineering | 8 | Clean architecture and tests, but no error, offline, or retry path. |

## Round 2 — 9.2

| Dimension | Weight | Score | What changed |
|---|---:|---:|---|
| **Does the job** | 3 | 9.5 | Numbers on the card, grouped as they are read aloud. "Start here" on the first *usable* rung. Write addresses the office you tapped — it used to discard it. Every dead end now has a way out. |
| **Honesty** | 2 | 9.5 | Both the CC and the BCC are disclosed before sending. Failed actions report themselves. A dropped connection no longer masquerades as an empty directory. Nothing on screen is asserted by the app. |
| **Visual craft** | 1.5 | 9 | Numbered rail with a connector, so the list reads as a climb. Tonal elevation marks the recommendation. One type scale, no hardcoded sizes. Dark parity verified by rendering it. |
| **Modern feel (2027)** | 1.5 | 8.5 | M3 tonal surfaces, 28px sheets with drag handles and safe areas, motion that explains state rather than decorating it, haptics at the three moments that commit. Short of full marks: no shared-element transition into the letter, no predictive back, no dynamic colour. |
| **Accessibility** | 1 | 9.5 | Every action names its target — "Call Assistant Engineer", not "Call". The phone number is announced digit by digit, because as one integer it cannot be written down. Decoration excluded. 200% text proven by test, not asserted. |
| **Engineering** | 1 | 9 | 17 mobile tests, 6 backend. Loading, empty, error, offline and busy all handled. Analyzer clean. Short of full marks: the render harness is manual, with no golden-image regression. |

**Weighted total: 9.2**

## What would take it to 9.5

- A golden-image test, so a regression in any of this fails CI instead of
  waiting for somebody to look again.
- A shared-element transition from the ladder rung into the letter, so the
  member can see which office the draft belongs to without reading.
- Contrast measured rather than eyeballed.

## What no rating can cover

Nobody has held this on a phone, and nobody has sent a letter written by it to
a real officer. Both remain true.
