# Where things live

**Status:** decided · **Applies to:** every new member-facing feature

This is the rule the project is held to. If a change does not fit it, the rule
gets revisited on purpose — it does not get quietly bent.

---

## The rule

**Split by what a page is for, not by what technology it is written in.**

| | surface | built with | why |
|---|---|---|---|
| **Arrived at** | landing, about, share links (`/e/K7P2`, `/t/K7P2`), public live scoreboards, anything a stranger reaches from Google or WhatsApp | **Astro** | must paint in about a second on a weak connection, must be indexable, is free to look however it likes |
| **Returned to** | the member app — blood donation, chess, events, feed, profile, anything behind a name | **one codebase, shared with Android** | opened fifty times, cares nothing for SEO, and must not behave differently from the phone |

A scoreboard link and a donor registration are not the same product wearing
different clothes. One is read once by a stranger; the other is used weekly by
a member who also has the app. Optimising either for the other's constraints
makes both worse.

## Why not the alternative

The tempting plan is to grow the Astro site until it matches Android
feature-for-feature. Its first build is not the problem — every change after it
is. Each feature becomes two implementations, two tests, two reviews, and two
chances to be subtly different.

And the failure mode is not "we did not get to it". It is **silent divergence**.
This project has already lived it: an entire rebuild of blood donation — the
map, presence colouring, ask-a-donor, the emergency broadcast, taluk grouping —
landed on Android only, and nobody knew until somebody asked. That was one
sprint with one implementation. Two implementations makes it structural.

Every large product built this way converges away from it eventually. Google
does not maintain a second Gmail for SEO; `microsoft.com` is marketing and
`outlook.office.com` is the product. The split above is what that looks like at
our size.

## The honest costs, written down so nobody rediscovers them in a panic

- **First load of the member app is heavy.** Measured, not guessed: ~2.17 MB of
  JavaScript plus ~2.09 MB of CanvasKit, gzipped. It caches, so it is a
  once-per-device cost paid by people who already chose to use the app — and it
  never lands on someone tapping a shared link, because those never touch it.
- **No SEO inside the member app.** It renders to a canvas. This is fine: the
  pages that need to be found are Astro's, by design.
- **Deferred loading is the lever** if the first load has to come down. CanvasKit
  is roughly a 2 MB floor; do not promise better than that without measuring.

## What this means in practice

1. A new **member-facing feature** is built once, in the shared codebase. It
   reaches the web when the web build ships — not by being written again.
2. A new **public page** is built in Astro, and is free to have a design of its
   own. It must not require a session.
3. If a feature needs both — a public teaser and a member action — the teaser is
   Astro and links into the app. It does not reimplement the action.

## How the rule defends itself

Documents rot; tests do not. Two checks in CI hold this:

- **`Web — the member app still builds`** compiles the shared codebase for the
  browser on every push. The moment the member app stops being deployable to
  the web, parity has been lost, and it fails loudly instead of drifting.
- **`Web — public pages stay light`** asserts a page-weight budget on the Astro
  build, so the fast public surface stays fast as it grows.

The same discipline as the four-language rule: a rule nobody can forget beats a
rule everybody agrees with.
