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


## Deploying the member app to the browser

`mobile/Dockerfile.web` + `mobile/fly.toml` → **fyc-webapp** (`app.fycconnect.com`),
built from exactly the source Android ships. The public Astro site stays a
separate app (`web/fly.toml`, `fyc-web`), which is the whole point.

Two things in the nginx config are worth knowing before anyone "optimises" them:

**Every path that is not a file serves `index.html`.** go_router reads the URL
after boot, so `/blood-donation` and `/blood-requests/<id>` — where a blood
notification lands — must reach the app rather than 404.

**Nothing is cached blind, because Flutter web fingerprints nothing.** The
static-site habit of hashing a filename and then caching it for a year as
`immutable` is wrong here: `flutter_bootstrap.js` asks for `main.dart.js` by
that exact name on every build, and the assets keep their paths. A year of
`immutable` would strand every existing member on whichever build they loaded
first — the deploy goes out, the server is new, the app is old, and nothing
says so.

`Cache-Control: no-cache` does not mean "do not store". It means store it and
revalidate: nginx sends an ETag, the browser sends `If-None-Match`, an
unchanged file returns 304 with no body. Repeat visits stay nearly free and a
deploy always lands.

That includes CanvasKit, tempting as an exception is at ~5 MB. The engine
revision appears in the *gstatic* URL, not ours — with
`--no-web-resources-cdn` it is served from a flat `/canvaskit/` path whose
contents change on a Flutter upgrade without the path moving. One conditional
request answered 304 is the price of not stranding somebody on an engine that
no longer matches their app.
