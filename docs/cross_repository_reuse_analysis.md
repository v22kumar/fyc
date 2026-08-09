# Cross-repository reuse analysis

**Four repositories, one body of work.** SEASON BLACK, FYC Connect, ZISUN and TheGypsy,
read as a single engineering corpus rather than four unrelated products.

| | |
|---|---|
| **Corpus** | 1,733 tracked files · 183,556 lines of code · 38,599 lines of documentation · 253 commits · 5 languages |
| **Method** | Full read of all four working trees, tracing real call paths through services, models, routers, migrations, CI configuration and client code. Not READMEs. |
| **Dated** | 9 August 2026 |
| **Canonical copy** | This file is byte-identical in all four repositories up to the final section, so a finding ID cited in one repo resolves to the same finding in the others. |

Every finding carries a stable ID in the convention SEASON BLACK already uses, so this
document can be cited from commits, ADRs and issues rather than paraphrased:

| Prefix | Meaning |
|---|---|
| `SHAPE-n` | A recurring architectural shape, implemented more than once |
| `REUSE-nn` | Something that should move from one repository to another |
| `DUP-nn` | The same problem solved more than once, with a verdict |
| `INV-nn` | An accidental invention — a feature that is really a capability |
| `BIZ-nn` | A business mechanism that transfers between products |
| `IDEA-nn` | A product or package hiding inside existing code |
| `AVOID-nn` | Something that looks reusable and is not |
| `DEF-nn` | A defect found while reading |

---

## 0. The short answer

**The most valuable reusable asset in the corpus is not code. It is the method invented in
SEASON BLACK for making an AI-built repository trustworthy** — a machine-readable context
spine, a `null` + `blocked_by` hard stop that forbids invented answers, an append-only
decision ledger where every entry carries a revisit trigger, and CI lints that enforce brand
and design rules a reviewer would miss. Nothing else here is as differentiated, as portable,
or as immediately applicable to the other three repositories, all of which are AI-built and
none of which have it.

Below that, the picture is consistent: **the same five shapes recur in all four codebases,
each time reinvented, and each time one repository solved it visibly better than the
others.** There are four WhatsApp senders and only one is a real outbox. There are four
ordered-fallback "ladders" — OTP channels, complaint escalation, notification retry,
payment-then-SMS — and no shared abstraction for any of them. There are three money
representations and exactly one GST engine, sitting in the repository that sells two
T-shirts, while the repository built to sell a whole catalogue has no tax code at all.

Three things are worth extracting into shared packages, and they are not the ones that look
most reusable: **the outbox** (SEASON BLACK), **the escalation ladder** (FYC), and **the
operator worklist** (SEASON BLACK and FYC, independently arrived at). One thing is worth
extracting as a product: **the context spine**.

---

## 1. Repository inventory

### SEASON BLACK — Go, 20,096 LOC, 70 commits, 22,231 lines of docs

A single-binary D2C storefront for premium black apparel, India-only, launching January 2027.
Server-rendered HTML, no frontend framework, PostgreSQL, one Go binary carrying its own
migrations and templates.

The unusual part is the ratio: more documentation than code, and the documentation is
normative rather than descriptive. Research findings carry source URLs and confidence
ratings; 22 ADRs carry revisit triggers; constraints are stated as physics.

- **Core** — catalogue, cart, checkout, payment (Razorpay redirect), returns, guarantee, fulfilment, ops worklist
- **Money** — integer paise, per-piece GST, Indian digit grouping
- **Notify** — transactional outbox to WhatsApp Cloud API templates
- **Auth** — operator only; guest checkout by phone
- **Gate** — SQL invariant suite, design-token lint, copy lint, real-browser UI test
- **Maturity** — feature-complete, unproven against live vendors

### FYC Connect — Python + Flutter + Next + Astro, 136,921 LOC, 126 commits

A community operating system for a youth club in Nagercoil: civic complaints, blood donation,
cricket and chess tournaments with live scoring, events, volunteering, a public directory, a
news and Thirukkural digest, a social feed. Four surfaces, one FastAPI core.

By volume this is 75% of the corpus, and it contains the densest concentration of genuinely
novel mechanisms — most of them buried under a domain nobody would search for them in.

- **Backend** — 46 routers, 34 services, 35 model modules, multi-tenant by header + contextvar
- **Auth** — HS256 JWT, phone OTP, Google, refresh with token-version revocation, role checker
- **Notify** — FCM + WhatsApp + SMS + email fan-out with per-user category preferences
- **AI** — Gemini: complaint drafting, daily digest, news summary, notification rewriting
- **Mobile** — own design system, 4-language registry, offline outbox, device tiers, self-hosted crash reporting, OTA updates
- **Maturity** — shipping to real phones; carries real debt

### ZISUN — Python + Next, 20,274 LOC, 42 commits

A Myntra-class custom commerce platform for a womenswear brand: catalogue with variants,
cart, checkout with inventory locks, Razorpay, coupons, reviews with moderation, wishlist,
Shiprocket, an admin panel, and a planned pgvector recommendation engine.

Its own strategy document concludes the platform is the wrong tool for the business — a
₹1-lakh brand does not need Myntra's architecture. That verdict is correct, and it makes
ZISUN the corpus's best *parts donor*: the business may not need the platform, but the
platform contains well-built parts the others do need.

- **Strengths** — RS256 keypair auth with JTI denylist, Redis rate limiting, tsvector search, transactional outbox drained by Celery, idempotent checkout
- **Gaps** — no GST, no multi-tenancy, no notification preferences, no i18n
- **Maturity** — well tested against a real database; strategically shelved

### TheGypsy — TypeScript monorepo, 6,265 LOC, 15 commits

A collaborative OS for group travel: trip rooms, per-member preference collection, an AI
destination-compatibility engine, voting, itinerary, multi-currency expense splitting and
settlement. Turborepo, Next 14, Drizzle, Neon, Clerk.

The youngest and smallest, and the best-engineered per line. Strict TypeScript with
`noUncheckedIndexedAccess`, pure functions separated from database access, network
dependencies injected so they can be tested, and a test file for nearly every library module.
It is the only repository whose AI layer is unit-testable.

- **Strengths** — injected-dependency AI client, tolerant response parser, canonical shared-types package, schema-first data model
- **Gaps** — invites mint tokens with no way to deliver them; orgs, subscriptions and affiliate tables exist with no code behind them
- **Maturity** — M1 foundation complete; M2 not started

---

## 2. Architecture reconstruction — the five recurring shapes

None of these is named anywhere in the corpus. All are implemented more than once.

### SHAPE-1 · The ladder

An ordered chain of attempts with per-step waits and a published fallback. An action that can
fail is not retried blindly; it walks an ordered list of *increasingly different* options,
each with its own timeout, each recorded.

- **FYC** `backend/app/services/complaint_routing.py` — `Ladder`/`Rung`: department chain per category and jurisdiction, `wait_days` per rung, `reachable`, `fallback` portal/helpline
- **FYC** `docs/design/one-door-many-roads.md` — OTP: Twilio Verify → WhatsApp → email → log
- **SEASON BLACK** `internal/notify/notify.go` — `nextAttemptAfter`: 1, 4, 16, 64 min, capped at the two-hour business deadline, abandon at 6
- **ZISUN** `backend/app/services/whatsapp.py` — WhatsApp → Twilio SMS → dev log

Four implementations, zero shared code. Three independently discovered that the fallback must
be reachable *when the primary is configured but failing* — FYC wrote a whole design document
about getting this wrong.

### SHAPE-2 · Detect, never repair

The most distinctive doctrine in the corpus, arrived at twice independently in two languages.

- **SEASON BLACK** `internal/payment/reconcile.go` — "reconciliation detects and reports; it does not silently self-heal… a job that quietly corrects money discrepancies destroys the only signal that something is systematically wrong"
- **FYC** `backend/app/services/complaint_workflow.py` — "`next_due` reports which complaints have run out their wait. It does not escalate them. A machine that mails a District Collector unattended will one day mail a District Collector about a duplicate report of a puddle"

Both pair the detector with an append-only ledger of what was tried
(`reconciliation_finding`, `IssueEscalation`) and a deduplication rule so one real problem
does not become a hundred rows.

### SHAPE-3 · The worklist

A queue ordered by consequence, not by table.

- **SEASON BLACK** `internal/ops/ops.go` — "the organising idea is a WORKLIST, not a set of tables… money problems first, then things a customer is waiting on, then things we are waiting on." `Queue.NeedsAttention()` separates *wrong* from *merely pending*; `OrderRow.Overdue()` renders the SLA breach rather than making the operator compute it
- **FYC** `complaint_workflow.next_due()` — feeds "14 days, no reply from the Commissioner — send to the Collector?" with the next letter already drafted underneath

### SHAPE-4 · Provenance-carrying answers

A guess that admits to being one.

- **FYC** `backend/app/services/jurisdiction.py` — `Confidence.DECLARED / INHERITED / GUESSED`, a human-readable `reason` trail, and `needs_human_check`. "Pretending otherwise — snapping a point to the nearest node and calling it certain — would produce confident wrong answers"
- **SEASON BLACK** `context/project.json` — every field carries a `source`; `_inferred` marks derived facts as provisional
- **TheGypsy** `apps/web/lib/ai/compatibility.ts` — `minorityReport`: which group member compromises most, surfaced rather than hidden behind an aggregate score

### SHAPE-5 · Polymorphic attachment

One table serving every entity type.

- **FYC** `backend/app/models/core_services.py` — `CommunityActivity`, `Follow`, `Comment` all keyed by `(entity_type, entity_id)`; comments carry a partial unique index on an idempotency key
- **FYC** `backend/app/models/profile_attribute.py` — key/value profile facts with an explicit doctrine for when a key graduates to a real column

### Classification

| Class | What it looks like here | Examples |
|---|---|---|
| **A · Intentional architecture** | Decided, documented, enforced by a test or lint | SEASON BLACK's whole stack (ADR-cited in code comments); Gypsy's shared-types package as the single source of data shapes; FYC's tenant contextvar + cross-tenant assertion |
| **B · Accidental architecture** | A pattern that emerged from repetition and was never named | All five shapes above. Also: every repo independently landed on "presigned URL + CDN base" for media, and on integer minor units for money except where it didn't |
| **C · Technical debt** | Known-wrong, still load-bearing | FYC's two parallel push systems (one calling an API decommissioned in 2024); FYC's broadcast committing once per recipient; ZISUN's Razorpay mock-on-failure; FYC's chess WebSocket state pinning the app to one machine |
| **D · Valuable pattern, wrong home** | Correct and general, trapped in a domain-specific package | The outbox in `internal/notify`; the escalation ladder in `complaint_routing`; the worklist in `internal/ops`; the progressive-profile engine in `profile_questions`; the GST engine in a two-SKU storefront |

---

## 3. Capability map

Repository boundaries removed. **best** marks the implementation that should become the
reference; **gap** marks a repository that needs the capability and does not have it.

| Capability | SEASON BLACK | FYC | ZISUN | TheGypsy | Verdict |
|---|---|---|---|---|---|
| **Authentication** | Operator only, guest checkout by phone | HS256 + OTP + Google + token-version revocation | RS256 keypair, JTI denylist in Redis, hashed refresh tokens — **best** | Clerk (bought) | ZISUN's crypto + FYC's OTP ladder and multi-tenancy is the ideal |
| **Authorization / RBAC** | — | 6 roles, `RoleChecker` dependency factory — **best** | Two roles, inline | One boolean, `canManageTrip` | FYC's factory is directly portable to both |
| **Multi-tenancy** | Single tenant by design | Header + contextvar + `TenantModelMixin` + cross-tenant assertion — **best** | None — **gap** | Tables exist, no code — **gap** | Gypsy's B2B plan is blocked on exactly what FYC runs in production |
| **Notifications — fan-out** | One template, one recipient, no campaign concept (deliberate) | FCM + WhatsApp + SMS + email, per-user category preferences — **best** | Order confirmation only | None — **gap** | FYC's `NotificationPreference` is the only real preference system in the corpus |
| **Notifications — delivery** | Transactional outbox: enqueue in caller's tx, `SKIP LOCKED` claim, attempt count, capped backoff, abandon, provider ref — **best** | Synchronous "queue" that is a direct call | Outbox table drained by Celery beat | None | SEASON BLACK's design + ZISUN's worker infrastructure |
| **WhatsApp** | Cloud API, template-only, no free-text path — **best** | Two senders — Meta Cloud + Twilio broadcast | Cloud API text + Twilio fallback + signed webhook | — | Four implementations. See `DUP-01` |
| **Email** | — | SMTP mailer, used for complaint dispatch | — | `RESEND_API_KEY` in env, no sender written — **gap** | Gypsy's invite flow is undeliverable today |
| **Push (FCM)** | — | firebase-admin v1 *and* a legacy HTTP path — **defect** | — | — | See `DEF-01` |
| **Background jobs** | Ticker inside the binary (right-sized for 50 msg/month) | APScheduler + Postgres advisory-lock leader election — **best for single-box** | Celery + Redis + beat — **best for scale** | None | Two valid answers at different scales; FYC's leader lock is the transferable bit |
| **Rate limiting** | — | Proxy-aware key function, in-process store — **best key** | Redis sliding window, naive key — **best store** | None | Each has exactly what the other lacks. See `DUP-05` |
| **Caching** | HTTP-level, static renditions | Thread-safe TTL cache, Valkey client, ETag/304 helper — **best** | Redis | Upstash configured, unused | FYC's `core/etag.py` is 60 lines and drops into any FastAPI or Next route |
| **Money** | `money.Minor` integers, Indian digit grouping, no float anywhere — **best** | Numeric hours only | Raw ints named paise, no type, no formatter | Numeric strings + explicit FX rate per expense | Standardise on minor units + a currency tag; Gypsy's FX-rate-at-entry is the multi-currency answer SEASON BLACK's type lacks |
| **Tax (GST)** | Per-piece, ₹2,500 threshold, current to Sept 2025 law, tested — **best** | — | Nothing — zero occurrences of GST/tax/HSN — **critical gap** | — | An Indian commerce platform that cannot compute tax cannot issue an invoice |
| **Payments** | Razorpay redirect, idempotency key with conflict detection, signed webhooks, hourly reconciliation — **best** | — | Razorpay orders, idempotency key, inventory locks, COD ceiling | Stripe schema, no code | SEASON BLACK's `Initiate()` is the reference: replay returns the original, reuse-with-different-details errors |
| **Orders / state machine** | Event-sourced order events + SQL invariants — **best enforcement** | 7-state complaint machine with `OURS`/`THEIRS`/`FINISHED` sets and `next_states()` for UI — **best shape** | 9-state order machine raising HTTP 409 from the domain layer | Trip status enum, no machine | FYC's shape, ZISUN's domain, SEASON BLACK's SQL enforcement |
| **Returns / guarantees** | Exchange-first, five reason codes, restock to original dye lot, 30-wash guarantee logged per lot — **unique** | — | Return status enum only | — | The lot-linked claim is a quality feedback loop, not just a policy |
| **Catalogue** | 2 SKUs, dye-lot traceable, evidence-led product page | — | Categories, variants, media, effective pricing, tsvector search — **best** | Destination catalogue | ZISUN's is the generic one; SEASON BLACK's is deliberately not |
| **Search** | — | Federated across 7 entity types, ILIKE, no ranking | Postgres tsvector with ILIKE fallback — **best** | — | FYC has the right shape and the wrong engine |
| **Media** | Measured format ladder — AVIF + JPEG floor, no WebP, fails closed without alt text — **best doctrine** | Attachments + gallery routers | Presigned R2 upload + CDN base — **best plumbing** | R2 configured, unused | ZISUN's uploader + SEASON BLACK's rendition doctrine |
| **AI services** | — | Gemini, hardcoded vendor, DB cache keyed (org, type, date) — **best caching** | Planned only | OpenRouter, injected completion fn, pure prompt builder, tolerant parser — **best structure** | See `DUP-08` |
| **Activity / feed** | — | `CommunityActivity` + `Follow` + `Comment`, all polymorphic — **best** | Content cards | — | A social substrate that attaches to anything, sitting in a club app |
| **Audit log** | Order events, reconciliation findings | `AuditLog` with old/new values, IP, user agent — **best** | — | — | Directly portable |
| **i18n** | English only (decided, ADR-0006) | 4 languages, server registry mirrored client-side, push localised via `i18n_key` — **best** | None | None | The only real i18n system in the corpus, and it is bilingual-by-schema, not bolt-on |
| **Feature flags / config** | Env + embedded templates | `platform_settings`, theme router, app-meta endpoint — **best** | Pydantic settings | Env | — |
| **Operator surface** | `/ops` consequence-ordered worklist — **best** | Next.js admin, 5 components | Next.js admin with reconciliation page | — | Everyone builds an admin; only SEASON BLACK built a worklist |
| **Offline / low-connectivity** | — | Hive outbox with durable media copies, device tiers from battery + connectivity — **unique** | Offline banner component | — | Nothing else in the corpus comes close |
| **Crash reporting** | Structured logs | Self-hosted: bare-Dio reporter, session dedupe, server-side grouping — **unique** | — | Sentry configured | Built rather than bought, and correctly so for the constraint |
| **App distribution** | — | OTA APK updater handling the split-per-ABI versionCode trap — **unique** | — | — | Play-Store-free distribution, working |
| **CI / quality gates** | SQL invariant suite with `assert_rejected`, design-token contrast lint, copy lint, real-browser UI test — **best by a distance** | 7 workflows: tests, Flutter build, 3 deploys, uptime | Tests against a real database | typecheck / lint / test / format | SEASON BLACK encodes *policy* in CI; the others encode correctness |
| **Agent governance** | Context spine: normative JSON, hard stops on open questions, append-only ADRs with revisit triggers — **unique** | `CLAUDE.md` conventions | Strategy docs | `CLAUDE.md` conventions | See `IDEA-01` |

---

## 4. Reuse matrix

Ranked by value ÷ effort. Effort is founder-hours at weekend pace.

| ID | Capability | From | To | Type | Value | Effort |
|---|---|---|---|---|---|---|
| `REUSE-01` | Per-piece GST engine + money type | SEASON BLACK | ZISUN | Port (Go→Py) | Critical | 1–2 d |
| `REUSE-02` | Transactional outbox with backoff & abandon | SEASON BLACK | FYC, ZISUN, Gypsy | Pattern + port | High | 2–3 d |
| `REUSE-03` | Escalation ladder engine | FYC | SEASON BLACK, new product | Extract to package | High | 4–6 d |
| `REUSE-04` | Operator worklist doctrine | SEASON BLACK | FYC, ZISUN | Architecture | High | 2 d each |
| `REUSE-05` | Context spine + agent operating rules | SEASON BLACK | All three | Method | High | ½ d each |
| `REUSE-06` | Notification preferences + multi-channel fan-out | FYC | Gypsy, ZISUN | Model + service | High | 2 d |
| `REUSE-07` | Injected-dependency AI client + tolerant parser | Gypsy | FYC | Structure | Med-High | 1 d |
| `REUSE-08` | AI content cache keyed (tenant, type, date) | FYC | Gypsy | Model | Med-High | ½ d |
| `REUSE-09` | Multi-tenant kernel: mixin + contextvar + assertion | FYC | Gypsy | Architecture | High | 3 d |
| `REUSE-10` | Progressive profile prompt engine | FYC | Gypsy, ZISUN | Model + catalogue | High | 2 d |
| `REUSE-11` | Proxy-aware client-IP key function | FYC | ZISUN | Code (20 lines) | Med | 1 h |
| `REUSE-12` | Redis sliding-window limiter | ZISUN | FYC | Code | Med | ½ d |
| `REUSE-13` | ETag / 304 helper for list endpoints | FYC | ZISUN, Gypsy | Code (60 lines) | Med | 2 h |
| `REUSE-14` | Unambiguous short-code generator | FYC | ZISUN, SEASON BLACK | Code (30 lines) | Low-Med | 1 h |
| `REUSE-15` | tsvector search with ILIKE fallback | ZISUN | FYC | Technique | Med | 2 d |
| `REUSE-16` | Presigned R2 upload + CDN base | ZISUN | Gypsy, FYC | Code | Med | ½ d |
| `REUSE-17` | Scheduler leader election by advisory lock | FYC | SEASON BLACK | Code (60 lines) | Med | 2 h |
| `REUSE-18` | Audit log with old/new values | FYC | ZISUN, Gypsy | Model | Med | ½ d |
| `REUSE-19` | SQL invariant suite (`assert_rejected`) | SEASON BLACK | ZISUN, FYC | Test technique | High | 2–4 d |
| `REUSE-20` | Design-token + copy lints in CI | SEASON BLACK | FYC | Tooling | Med-High | 2 d |
| `REUSE-21` | Polymorphic Follow / Comment / Activity | FYC | Gypsy | Model | Med | 1 d |
| `REUSE-22` | Multi-currency expense split + settlement graph | Gypsy | FYC | Domain model | Med | 3 d |

### REUSE-01 · Per-piece GST engine and the money type
**SEASON BLACK → ZISUN**

**What exists.** `internal/gst/gst.go` — 65 lines computing Indian GST on apparel *per piece*,
GST-inclusive (extracting tax rather than adding it), in basis points so no float is involved,
with the boundary condition stated explicitly. Alongside it, `internal/money/money.go`: an
integer minor-unit type with checked subtraction and Indian digit grouping (12,34,567 not
1,234,567).

**Why it is reusable.** The hard part is not the arithmetic — it is the domain knowledge, and
it is perishable. The comment records that Notification 9/2025-CT(R) moved the threshold to
₹2,500 per piece on 22 September 2025, and that "every model built before October 2025 uses
the old ₹1,000 threshold and is wrong by roughly ₹94 a unit." That sentence is worth more than
the code.

**Where it goes.** ZISUN has orders, order items with snapshot unit prices, Razorpay,
Shiprocket, an admin panel — and zero occurrences of GST, tax, HSN, CGST or IGST anywhere in
its Python. It cannot issue a compliant invoice. It also derives the per-piece structure for
free: SEASON BLACK's insight that order lines carry no quantity column because tax is assessed
per piece is a schema decision ZISUN should evaluate before it has real orders.

**How.** Port `OnPiece()` and `RateFor()` literally to `app/core/gst.py`; port the money
helpers to a small `Paise` wrapper, or at minimum adopt the Indian grouping formatter. Carry
the ADR references across as comments so provenance survives.

- Effort 1–2 days · Benefit: legal compliance, correct invoices
- Risk: the threshold changes again — keep the citation and add a revisit trigger

### REUSE-02 · The transactional outbox
**SEASON BLACK → FYC, ZISUN, TheGypsy**

**What exists.** `internal/notify/notify.go`, 237 lines, every decision argued in a comment:

- `EnqueueTx` takes the *caller's* transaction — "no order without its confirmation message queued" is only true if both commit together
- `claim()` uses `FOR UPDATE SKIP LOCKED` so overlapping deploys cannot double-send, and increments the attempt count *at claim time* so a crash mid-send burns an attempt instead of retrying forever
- `nextAttemptAfter` backs off 1/4/16/64 minutes *capped at the two-hour business deadline* — "a backoff that grows past that has quietly stopped serving the deadline it exists for"
- Abandon after 6 attempts, loudly, because the consequence is a COD parcel going to an unconfirmed address
- Marked sent *after* the provider returns — at-least-once, chosen deliberately

**What the others have instead.** FYC's `WhatsAppQueueManager` is a class whose docstring says
"for production, this would be backed by Celery or Redis Queue" and whose `enqueue_template`
calls the provider synchronously and returns a boolean. A failed notification is simply lost.
ZISUN has a real outbox table drained by Celery beat, but no attempt count, no backoff and no
abandon state. TheGypsy has nothing.

**How.** Extract as a Python package with the same columns — `attempts`, `send_after`,
`sent_at`, `abandoned_at`, `last_error`, `provider_ref` — and a pluggable `Sender` protocol.
ZISUN already has the Celery worker to drain it; FYC has APScheduler. The schema and the claim
query are the reusable part, not the Go.

- Effort 2–3 days · Benefit: no silently-lost messages anywhere
- Risk: at-least-once means duplicates, and must be stated as SEASON BLACK states it

### REUSE-03 · The escalation ladder engine
**FYC → SEASON BLACK, and a product**

**What exists.** Three files that together form a complete, general case-escalation engine:

- `services/jurisdiction.py` — resolves *which authority owns this* from a hierarchy, walking up to a classified ancestor, and labels the answer `DECLARED`/`INHERITED`/`GUESSED` with a human-readable reason
- `services/complaint_routing.py` — builds a `Ladder` of `Rung`s from configurable `RoutingRule`/`RoutingStep` rows: specific scope beats general, each rung has a wait, unreachable rungs are skipped rather than blocking, and a published portal/helpline is the fallback when nothing is reachable
- `services/complaint_workflow.py` — approve (human gate, recorded), dispatch (the same code path for the first letter and every escalation, so an escalation can never be logged differently), `next_due()`, `history()`

**Why this is not "a civic feature".** Strip the vocabulary and it is: *route a case to an
ordered chain of accountable parties, each with an SLA; detect breaches; require a human to
advance; keep an append-only record of who was told what and when.* That is a grievance
system, a B2B support-escalation matrix, an insurance-claim chain, an RWA complaint tracker, a
compliance workflow.

**Where it goes internally.** SEASON BLACK's vendor problems are the same shape — a Shiprocket
ticket unanswered for four days should climb. So is a ZISUN return dispute. The generalised
interface is `Ladder(case) → [Rung]` plus `dispatch(case, rung) → attempt`.

**Caution.** The three files are welded to `PublicIssue`, `IssueStatus`, `Authority` and
`Department`. Extraction means introducing a small case protocol (`id`, `category`,
`location`, `status`, `current_position`, `next_action_due_at`) and moving letter composition
out to a template. That is the 4–6 days.

### REUSE-04 · The operator worklist
**SEASON BLACK → FYC, ZISUN**

**What exists.** `internal/ops/ops.go` is read-only by design — "the actions live on the
services that already own those invariants… a second path to the same state change is a second
set of rules, and only one of them would have been thought through." Its `Queue` struct's
*field order is the page order*: findings, stuck messages, addresses to confirm, ready to
dispatch, in transit, returns, claims. Rows carry `WaitingFor` and `Overdue()` so the operator
sees the breach instead of computing it. `NeedsAttention()` counts what is *wrong*, not what is
pending. `Empty()` exists so a clear desk says so rather than rendering nine empty headings.

**Why it transfers.** Both other admin panels are CRUD-over-tables. Neither answers "what do I
do now." FYC in particular *already computes* the inputs — `next_due()`, open blood requests,
unreviewed complaints, stuck broadcasts — and never assembles them into one ranked page.

### REUSE-06 · Notification preferences and multi-channel fan-out
**FYC → TheGypsy, ZISUN**

**What exists.** `NotificationPreference` per (user, org) with per-category and per-channel
toggles, auto-created on first read; a `Notification` row written before any send so the in-app
list never depends on delivery; `delivery_channel` recorded as a comma list of what actually
worked; `send_push_only()` as an explicit escape hatch for transient alerts "where blasting
WhatsApp or email on every event would be spammy."

**Where it goes.** TheGypsy is a group-coordination product — vote opened, vote closing,
expense added, settlement requested, someone joined — with no notification system at all. Its
invite flow mints a cryptographic token, writes a `tripMembers` row with status `invited`, and
then stops: there is no email sender anywhere in the repository despite `RESEND_API_KEY` in
`.env.example`. The organiser must copy a URL by hand.

**Take the model, not the service.** FYC's `send_notification` has real problems (see
`AVOID-03`) — the preference model and the write-then-deliver ordering are the parts worth
copying.

### REUSE-07 / REUSE-08 · The AI layer, swapped both ways
**TheGypsy ⇄ FYC**

**Gypsy → FYC (structure).** `lib/ai/openrouter.ts` exports a `ChatCompleteFn` type;
`lib/ai/compatibility.ts` takes that function as an argument. Prompt construction is a pure
function; response parsing is a pure function that clamps scores to 0–100, accepts both a bare
array and a wrapper object, and *drops malformed entries rather than throwing*. The result is
235 lines of AI tests that need no network.

**FYC's version.** `services/ai_service.py` hardcodes a Gemini URL, calls it synchronously, and
repeats the same ```json fence-stripping block three times inline. There is no seam to inject a
stub, so none of it is unit-tested. It also contains an
`asyncio.get_event_loop().run_until_complete()` inside a possibly-running loop, with a comment
admitting the branch does nothing.

**FYC → Gypsy (caching).** `models/ai_content.py` is a 15-line table caching AI output on
`(organization_id, content_type, content_date)`. Gypsy's destination generation is a
multi-second, paid, non-deterministic call with *no cache at all* — every page view of the
destinations screen can regenerate. This is the cheapest high-value transfer in the matrix.

Risk: cache invalidation when preferences change — key on a preference hash, not just the date.

### REUSE-10 · Progressive profile enrichment
**FYC → TheGypsy, ZISUN**

**What exists.** Three pieces that only work together: `ProfileAttribute` (one row per learned
fact, unique per user+key, with `answered_at` so "what did the club look like last year" stays
answerable), `ProfilePromptState` (what was asked, answered, dismissed, and when it was last
*shown*), and a code-resident catalogue with `QUIET_DAYS_AFTER_RESPONSE = 2`,
`QUIET_DAYS_AFTER_DISMISS = 14`, `MAX_DISMISSALS = 3`.

**The doctrine is the valuable half.** `profile_attribute.py` states when a key *graduates* to
a real column: "when a feature needs to query, filter, sort or index by it. `blood_group`
earned one — the donor search filters on it. Education has not… never 'in case', because that
is how a profile table ends up eighty mostly-empty columns wide." Most EAV designs never write
that rule down and rot accordingly.

**Where it goes.** Gypsy asks eight preference questions in one form
(`preferences-form.tsx`, 234 lines) — the exact long-form gate FYC removed. Its AI engine
degrades with each unanswered member, so drip-collection with dismissal budgets is directly on
the critical path. ZISUN's brand needs fit, size and style preferences and has no mechanism to
ask for them.

---

## 5. Solved twice — and who wins

Semantic comparison, not filename comparison.

### DUP-01 · WhatsApp delivery — four implementations

| Implementation | Transport | Retry | Record | Verdict |
|---|---|---|---|---|
| SEASON BLACK `notify/whatsapp.go` + `notify.go` | Cloud API templates, no free-text path | Outbox, capped backoff, abandon | Row per message, provider ref, last error | **winner** |
| FYC `whatsapp_service.py` | Cloud API, provider abstraction, mock fallback | None — "queue" calls inline | None | has a defect (`DEF-02`) |
| FYC `whatsapp_broadcast.py` | Meta group send + Twilio per-member loop | None; 1 s sleep between sends | In-memory dict | two problems (`DEF-03`) |
| ZISUN `services/whatsapp.py` | Cloud API text → Twilio SMS | None | Logs | has the best webhook |

**What each gets right.** SEASON BLACK: durability, and the deliberate refusal of a free-text
path so unreviewed copy cannot reach a customer. FYC: a genuine provider interface (Meta /
Twilio / mock) selected by environment — the only pluggable one. ZISUN: the only HMAC-verified
inbound webhook (`X-Hub-Signature-256` with `hmac.compare_digest`) and the only channel
fallback.

**The ideal.** SEASON BLACK's outbox and template discipline + FYC's provider interface +
ZISUN's signed webhook and SMS fallback. One package, four callers.

### DUP-02 · Push notifications — twice inside one repository

FYC contains `services/notification_service.py` (firebase-admin, FCM v1, preferences, i18n,
Android channel config) *and* `services/notifications.py` (raw HTTP to
`fcm.googleapis.com/fcm/send` with an `Authorization: key=` header — the legacy API Google
decommissioned in June 2024). The legacy module is still imported by `services/birthdays.py`
and `routers/issues.py`.

**Verdict:** not a duplication to reconcile — a dead path to delete. Its only distinctive idea,
FCM *topics* (`org_{slug}_blood`), is worth keeping: topic subscription is genuinely cheaper
than per-user fan-out for club-wide broadcasts, and firebase-admin supports it.

### DUP-03 · State machines — three, with three different layerings

- **FYC** `issue_lifecycle.py` — transition table plus `OURS`/`THEIRS`/`FINISHED` frozensets, `can()`, `check()`, `next_states()` "for building a UI that offers only the buttons that will work". `IllegalTransition` renders the allowed set in its message. Same-state is legal.
- **ZISUN** `order_state_machine.py` — a table and a method that raises `HTTPException(409)`
- **SEASON BLACK** — order events + SQL CHECK constraints; the database refuses the bad state

**Who wins what.** FYC has the best *shape*: the semantic groupings drive queues, and
`next_states()` means the UI cannot offer an illegal action. ZISUN's is the cleanest table but
commits a layering error — a domain module importing FastAPI means the state machine cannot be
used from a Celery task without an HTTP exception escaping into a worker. SEASON BLACK has the
strongest *enforcement*: no application bug can write an impossible state.

**The ideal:** FYC's API surface, raising a domain error the transport translates, with SEASON
BLACK's SQL constraints underneath as a backstop.

### DUP-04 · Authentication — three answers to one question

| | Algorithm | Revocation | Refresh | Distinctive |
|---|---|---|---|---|
| FYC | HS256, shared secret | `token_version` claim vs a user column | Long-lived, `type=refresh` rejected at protected routes | Revocation needs no Redis; multi-tenant claim + header cross-check |
| ZISUN | RS256 keypair, generated in dev, required in prod | JTI denylist in Redis with matching TTL | Raw token to client, hash stored | Public key can be published; refuses to boot prod without keys |
| TheGypsy | Clerk | Vendor | Vendor | Zero lines owned |

**Assessment.** ZISUN's is cryptographically the better design and its production guard is
exemplary. But FYC's `token_version` is the more *right-sized* revocation: one integer column
gives logout-everywhere with no Redis dependency, and FYC's own architecture note says the app
runs on one machine. Gypsy's answer — buy it — is correct for a product with no auth
differentiation, and worth remembering before anyone extracts an "auth package."

**The ideal:** RS256 + JTI, *and* a token version for bulk revocation, behind FYC's
tenant-aware dependency chain.

### DUP-05 · Rate limiting — each has exactly what the other lacks

FYC's `core/rate_limit.py` carries a 40-line comment diagnosing a production bug:
`get_remote_address` returns the fly-proxy address, so "every member in the club shared one
bucket… the sixth person each minute would be told to slow down for something five strangers
did." It also explains why the obvious fix is worse — `--forwarded-allow-ips='*'` takes the
leftmost `X-Forwarded-For` entry, which the caller controls, turning a shared bucket into no
bucket. The fix reads `Fly-Client-IP` only when running on Fly.

**ZISUN's limiter has that exact bug:** `ip = request.client.host`, with no forwarded-header
handling. But ZISUN's store is Redis with a sliding window, so it survives multiple instances —
while FYC's is in-process and its own comment concedes it would multiply by the instance count.

**The ideal:** FYC's `client_ip()` key function (generalised to a configured trusted-proxy
header rather than hardcoding Fly) + ZISUN's Redis window.

### DUP-06 · Unambiguous short codes — the same invention, twice

- **FYC** `core/short_code.py` — 31-char alphabet excluding 0/O/1/I/L, "so a code can be copied off a poster without confusion", collision retry that *widens the code* after four failures
- **TheGypsy** `lib/trips.ts` — 32-char alphabet omitting 0/o/1/l, retry loop keyed on Postgres unique-violation `23505`

Same reasoning, same exclusions, written months apart in two languages, neither aware of the
other. FYC's is slightly better (length widening prevents infinite retry in a crowded space);
Gypsy's collision detection is better (a real unique violation rather than a pre-check with a
race window). Combine both and it is thirty lines never written again.

### DUP-07 · Money — three representations

SEASON BLACK: a real `Minor int64` type with checked subtraction and locale-correct
formatting, but *no currency tag* — fine for an India-only brand, wrong as a shared package.
ZISUN: bare Python `int` named paise by convention, with `amount_paise / 100` float division
appearing in message formatting. TheGypsy: `numeric(10,2)` plus a stored `exchangeRate` and a
base-currency amount frozen at entry time — which is the *correct* multi-currency answer and
the one SEASON BLACK's type cannot express.

**The ideal:** SEASON BLACK's integer discipline + a currency code + Gypsy's rate-at-entry rule.

### DUP-08 · AI response handling — opposite strengths

Gypsy wins on structure and testability; FYC wins on caching, multi-language output and having
a fallback when the key is absent. Neither has retry, token accounting, or a model-choice
policy. A shared `ai/` package would be Gypsy's seam + FYC's cache + something neither has.

### DUP-09 · A doctrine conflict worth resolving deliberately

SEASON BLACK refuses a free-text WhatsApp path on principle: "it would be the one way
unreviewed copy could reach a customer," and its CI runs a copy lint banning manufactured
urgency and dark patterns. FYC does the opposite — `broadcast_to_tenant` pipes every
notification through Gemini with the instruction "make it more engaging, empathetic, and urgent
(if necessary). Include exactly one appropriate emoji" and sends the result unreviewed to every
member.

Both are defensible in context, but they cannot both be the house style — and FYC already
found the boundary itself: the emergency broadcast *deliberately bypasses* the AI rewriter,
because "in an emergency the facts *are* the message, and a rephrasing is latency plus a chance
to be wrong about a blood group." **That exception is the rule in disguise.** The generalisable
policy: AI may rewrite discretionary copy; it may never rewrite copy carrying a fact someone
will act on.

---

## 6. Accidental inventions

Things built as features that are actually reusable capabilities.

### INV-01 · The context spine — governance for AI-built repositories

**Called:** "how this repo works." **Actually:** a general method for making agent-written
software trustworthy.

Five JSON files (`project`, `principles`, `constraints`, `decisions`, `open-questions`), each
ID-addressed, declared normative over prose. The load-bearing mechanism is the one you would
not think to build: **a `null` paired with `"blocked_by": "OQ-###"` is a machine-readable hard
stop.** The stated reason is exact — "agents invent answers because nothing tells them an
answer is missing." Around it: cite IDs instead of paraphrasing, because paraphrases drift;
ADRs are append-only and each carries a *revisit trigger* ("a decision without a revisit
trigger is dogma"); a changelog records a corrected inference rather than editing it away.

**Evidence it works.** `internal/order/pricing.go` returns `ErrMixedTwoUndefined` — the code
*refuses to price* a mixed two-pack because the ADR never specified one, with a comment saying
"escalate rather than inventing a price." An agent hit an undecided question and stopped. That
is the whole thesis, demonstrated in a return value.

### INV-02 · Policy-as-CI — machine-checked brand, design and honesty rules

**Called:** lint scripts. **Actually:** a way to make judgement survive an agent that has never
met you.

- `scripts/css-lint.sh` — parses `tokens.css`, computes WCAG relative luminance in inline Python, and *fails the build* if body text falls below 7:1. Also bans hardcoded colours, durations and px spacing outside the token file
- `scripts/content-lint.sh` — bans dark-pattern and hype copy in templates, and strips comments before matching so the rule can be documented without tripping itself. Written because "an external mockup contained eleven of them"
- `db/tests/*.sql` — `assert_rejected()` proves the schema *refuses* dishonest states rather than merely discouraging them
- `scripts/ui-test.sh` — a real browser, which found tap targets below the 44px the project's own tokens mandate "on code the other two had already passed"

The generalisable claim: *anything you would reject in review, and that an AI will reproduce by
default, belongs in CI.*

### INV-03 · Consent-gated contact disclosure

**Called:** "Ask, don't call" (blood donation). **Actually:** a reusable privacy protocol for
any directory of people.

The old flow handed over a phone number and made the requester dial down a list. The new one
inverts it: pick a person → they get a named request ("Meena asked you for O+") → on accept,
*their number arrives with the yes*; on decline, the number is never disclosed and the decline
stays private. Server-enforced on both halves. A targeted ask deliberately skips the radius and
eligibility filters, because "the requester has already looked at all of that… silently
dropping the request would be the app overruling the human."

Generalises to any marketplace or directory where contact details are the asset. It is the
mechanism that makes a directory shareable without making it harvestable.

### INV-04 · A rare-action budget for high-cost broadcasts

**Called:** emergency broadcast guardrails. **Actually:** a reusable attention-economics
primitive.

Only the requester or an admin; only while the request is open; *blocked once anyone has
accepted*; once per request, never repeatable; a ceiling per club per rolling day. The stated
reason — "three of them in a week and people turn notifications off — which costs the *next*
emergency far more than it costs this one. The cost is never paid by the person who sends it" —
is a clean statement of a tragedy of the commons, and the confirmation dialog "says the size of
the thing before it happens."

### INV-05 · An India-first, low-connectivity mobile kit

Four independent pieces in `mobile/lib/core/services/`:

- `device_profile_service.dart` — a `DeviceTier` (full / balanced / lite / offline) derived live from battery and connectivity, with a generation counter so a late-resolving evaluation cannot overwrite a newer decision
- `sync_service.dart` — a Hive-backed offline outbox that *copies picked images into app-persistent storage first*, because "image_picker returns temp cache paths the OS may purge… a queued post must own a durable copy or it would fail forever after an app restart"
- `error_reporter.dart` — self-hosted crash reporting on a *bare Dio instance*, "deliberately not the app's configured ApiClient: an error raised inside the API layer must not be reported through that same layer, or a failure there becomes an infinite loop"
- `update_service.dart` — Play-Store-free APK updates, comparing semantic version names because "`--split-per-abi` offsets each ABI's versionCode (arm64 +2000…), so a code comparison would report 'up to date' forever"

Each comment describes a trap that costs a real day to find.

### INV-06 · Bilingual-by-construction, not bolt-on

`name_en`/`name_ta` pairs *in the schema* for every user-facing entity, a string registry
mirrored on both server (`core/i18n.py`, four languages) and client
(`lib/core/l10n/registry/`), and push notifications localised through an optional `i18n_key` in
the FCM data payload — with control keys stripped before send so they never leak into the tray.
Missing translations fall back to English "so a language can be filled in progressively —
nothing ever renders blank."

### INV-07 · Dye-lot traceability as a quality feedback loop

The 30-wash guarantee (`internal/returns/guarantee.go`) is framed as marketing but implemented
as instrumentation: "every claim is logged against ITS dye lot, which is what turns the
guarantee into a quality feedback loop rather than only a marketing promise. The lot is never
supplied by a caller; it is copied from the order line." Returns restock to the original lot.
Guarantee identity is the phone number, "stated plainly rather than pretending to a stronger
notion of 'customer' than we actually hold."

Generalises to any batch-manufactured product where defect rates are the signal.

### INV-08 · A polymorphic social substrate

`CommunityActivity`, `Follow` and `Comment` all key on `(entity_type, entity_id)`, so following
a tournament, an event, a team or a news category is one table.
`ActivityEngine.get_timeline()` returns the chronological history of *any* entity. Comments
carry a partial unique index on an idempotency key — "idempotency at the DB boundary."

### INV-09 · Jurisdiction resolution with declared provenance

A hierarchy walk that returns not just an answer but how sure it is and why, with an explicit
refusal to fake precision. Low confidence routes to the human review gate that already exists.

**The pattern, named:** *a derived value carries its own confidence, and low confidence routes
to a human rather than being hidden.* That applies to every inference in the corpus.

### INV-10 · A competition engine

Glicko-2 implemented from the paper with volatility convergence; cricket net-run-rate; a
WebSocket manager with server-authoritative board validation, Fischer increments, EWMA lag
estimation and a capped lag credit ("without a cap, a bad or dishonest connection would be
rewarded with free time"); tournament draw generation and a reaper for abandoned games.

Genuinely good and genuinely specialised — listed for completeness. See `AVOID-06` for the part
that should not travel.

---

## 7. Business mechanisms that transfer

### BIZ-01 · There is no door
**FYC → TheGypsy, ZISUN**

FYC removed a four-screen entry sequence (language → login → register → complete profile,
asking for the phone number three times) in favour of: **the app opens into the app**, and
identity is asked "at the moment something needs a name behind it… and afterwards you land back
exactly where you were." The API already answered those endpoints anonymously; only a redirect
was stopping it.

Gypsy puts Clerk in front of everything under `(protected)` — a trip invitee must create an
account before seeing what they were invited to. Letting an invite token render the trip
read-only before sign-in is the same fix.

### BIZ-02 · The human gate on outbound action
**FYC + SEASON BLACK → everything**

"A person always presses send… The club reads it first." "Reconciliation detects and reports;
it does not silently self-heal." Two products, one operating rule: **the machine may find,
draft, rank and queue; a human authorises anything that leaves the building or moves money.**

### BIZ-03 · Set pricing, not discounting
**SEASON BLACK → ZISUN**

SEASON BLACK's two-pack is priced as a *set*, not a discount, with the justification recorded:
"shipping and packing are shared across the pair… 60% of the ₹177 difference is real avoided
logistics." A three-pack was deferred because 13% "sits inside India's reads-as-a-sale band."

The mechanism to borrow is not the absence of coupons; it is *the requirement that a price
difference correspond to a real cost difference, and that the reason be written down.*

### BIZ-04 · The prepaid-versus-COD economics
**SEASON BLACK → ZISUN**

SEASON BLACK prices a return-to-origin at ~₹232, charges a ₹99 COD handling fee, and requires a
WhatsApp address confirmation within two hours — with the outbox's backoff cap set to that
deadline and the ops queue flagging the breach. ZISUN caps COD at ₹5,000 and stops there; its
strategy document independently identifies COD as "a liability (25–40% RTO)."

Transfer the full control loop: fee, confirmation handshake, delivery-state tracking, and an
operator view that will not let an unconfirmed parcel be dispatched.

### BIZ-05 · Evidence as the product page
**SEASON BLACK → ZISUN**

Products named after their own specification ("the specification IS the product name"), lab
results published per dye lot, and the macro-weave photograph classed as `IsProof()` carrying a
higher quality budget than decorative frames. Single dye lot framed as "an unusual trust asset:
full-batch traceability."

ZISUN's equivalent evidence is measurable — GSM, shrinkage after five washes, colourfastness, a
named mill. Same mechanism, different measurements.

### BIZ-06 · Compute for the founder's day, not the dashboard
**SEASON BLACK → FYC, ZISUN**

SEASON BLACK's constraint set includes the operator: one person, weekend hours, 45–60
orders/month. Architecture follows — an outbox is a table and a ticker, not a broker; the ops
page is a worklist.

*Write the operator constraint into each repository's context as a first-class fact,* the way
`CON-013` does, and let it veto features.

### BIZ-07 · Two-sided reframing beats rebuilding
**FYC → method**

The Serve marketplace document notices that four confused features are really two sides of one
marketplace — supply (`CommunityProfile`) and demand (`Opportunity` + applications) — and that
"both models already exist in the codebase. This is a reframe and reconnect, not a rebuild."

Apply the same lens to Gypsy: trip members are demand, destinations and bookings are supply,
and the affiliate table is already the monetisation edge.

### BIZ-08 · Ask one question, days apart, always dismissable
**FYC → TheGypsy**

"The club would rather have a member with a thin profile than no member." Registration stays
short; the fields the app needs are collected afterwards, one at a time, with a dismissal
budget. Gypsy's product *depends* on complete preferences from every member and asks for all of
them in one form — the highest-risk moment in its funnel, unmitigated.

---

## 8. Products hiding in the code

Ranked by strategic value × evidence already on disk.

### IDEA-01 · The context spine as an operating standard *(rank 1)*

A small, opinionated standard plus tooling: five normative JSON files, ID conventions, an
append-only ADR ledger with mandatory revisit triggers, a linter that fails a build when code
references a `null` guarded by an open question, and a `CLAUDE.md` generator.

- **Evidence** — the whole of SEASON BLACK, and specifically `pricing.go` refusing to invent a price. Also 22,231 lines of docs against 20,096 of code: the cost is already paid
- **Advantage** — almost everyone shipping agent-written code in 2026 has the invented-assumption problem and no vocabulary for it. There is a working answer, a demonstration, and three sibling repositories showing what the absence looks like
- **To build** — the linter and the generator · **Difficulty** low · **Commercial** medium · **Strategic** very high

### IDEA-02 · Ladder — escalation and accountability as a service *(rank 2)*

Configurable escalation chains with SLAs, human-gated dispatch, provenance-carrying routing and
an append-only "who was told what, when" ledger. First market: Indian civic-grievance workflows
for RWAs, municipal wards, NGOs. Second market, same engine: B2B support escalation and
compliance workflows.

- **Evidence** — `complaint_routing.py`, `jurisdiction.py`, `complaint_workflow.py`, the `civic` models, a seeded Kanyakumari directory
- **Advantage** — the hard part is the directory, not the software: knowing a Corporation Commissioner and a Town Panchayat Executive Officer sit at the same rung and are not interchangeable. That is encoded, with a confidence model for when it is a guess
- **Difficulty** medium · **Commercial** medium · **Strategic** high

### IDEA-03 · An Indian D2C commerce core *(rank 3)*

Not a storefront — a correctness layer: per-piece GST current to 2025 law, integer money with
Indian formatting, idempotent payment initiation, reconcile-don't-repair against the gateway,
COD fee + address-confirmation handshake + RTO accounting, exchange-first returns with batch
restock, and a consequence-ordered operator worklist.

- **Evidence** — SEASON BLACK's `gst`, `money`, `payment`, `returns`, `order`, `ops` packages: ~5,000 lines with SQL invariant tests and 567 lines of payment integration tests. ZISUN's absence of all of it is the market evidence
- **Advantage** — Indian tax and COD are where global platforms are thin, and the September 2025 threshold change means most existing implementations are now wrong
- **Difficulty** medium · **Commercial** medium-high · **Strategic** medium

### IDEA-04 · Bharat Mobile Kit *(rank 4)*

An open-source Flutter package set: device-tier adaptation, an offline outbox with durable
media, self-hosted crash reporting with server-side grouping, Play-Store-free OTA updates, and
a four-language registry with progressive fallback.

- **Evidence** — `mobile/lib/core/services/`, all four shipping
- **Advantage** — these problems are invisible to teams building for flagship phones on good networks, which is most package authors
- **Difficulty** low-medium · **Commercial** low direct, high reputational

### IDEA-05 · Community OS — white-label FYC *(rank 5)*

FYC for the next hundred clubs, sold per club. Multi-tenancy is already real —
`Organization`, `TenantModelMixin` on every model, header-based scoping, cross-tenant
assertions, per-tenant social tokens, theme and platform settings. Not a rewrite; a
*de-hardcoding*.

**Honest caveat.** The tenancy is real but not clean — a hardcoded default organisation UUID in
the broadcast service (`AVOID-04`), Kanyakumari-specific directory seeds. Also: multi-tenant
means multi-support, and `CON-013`-style reasoning applies here too.

### IDEA-06 · Consent-first responder network *(rank 6)*

Generalise the blood mechanism into scarce-resource matching with privacy guarantees: a
registry, compatibility rules, an eligibility cooldown, geographic ranking, a targeted ask with
disclosure only on accept, and a rare, budgeted broadcast when targeting fails.

Caveat: competing with Friends2Support and state registries; the moat is the consent protocol,
not the matching.

### IDEA-07 · Progressive profiling as an SDK *(rank 7)*

Two tables, a catalogue format, quiet-day rules and a "next question" endpoint, with the
promotion doctrine as the documentation. Immediately useful in three of the four products —
which is the honest reason to build it. Commercial potential low; internal value high.

---

## 9. What not to reuse

### AVOID-01 · FYC's `services/notifications.py` — delete, don't extract
Targets an FCM endpoint Google decommissioned. Also hardcodes Tamil and English strings inline
— the exact thing `core/i18n.py` exists to prevent — with an untranslated `lang` parameter
defaulting to `"ta"`. Salvage the topic-broadcast idea; delete the file.

### AVOID-02 · The `WhatsAppQueueManager` abstraction — a name that lies
A class called a queue, documented as "for production, this would be backed by Celery," that
calls the provider synchronously and returns a boolean. Worse, it is the *shape* that misleads:
callers believe they enqueued something. If the provider interface is extracted — which is
genuinely good — rename it `WhatsAppProvider` and give it no queue-like method.

### AVOID-03 · FYC's broadcast fan-out loop — do not copy
`NotificationService.broadcast()` loads every user in the tenant and calls
`send_notification()` per user; that method performs a preference lookup (creating and
committing a row on first miss), inserts a notification, *commits*, dispatches FCM
synchronously, then commits again. A minimum of two round-trips and two commits per recipient,
inside a request. And `broadcast_to_tenant()` puts two blocking LLM calls in front of it — on
the critical path of, among other things, a live cricket score update.

Reuse the preference model. Rewrite the delivery as a queued job.

### AVOID-04 · Anything in FYC that hardcodes an organisation — tenancy leak
`whatsapp_broadcast.py` declares `_DEFAULT_ORG_ID = uuid.UUID("8f8b80b7-…")` and uses it as the
default argument to `send_to_members()`. A hardcoded tenant in a multi-tenant system is a
data-leak bug waiting for a second tenant. Likewise `seed_default_contacts()`'s Kanyakumari
phone numbers and `ai_service.py`'s prompt naming Nagercoil. Fine for one club; disqualifying
for `IDEA-05` until they move into tenant configuration.

### AVOID-05 · ZISUN's mock-Razorpay fallback — production hazard
In `initiate_checkout`, when the Razorpay API call raises, the code logs and sets
`razorpay_order_id = f"mock_order_{order.id}"`. In production that produces an order in
`PAYMENT_PENDING` holding inventory, with a gateway reference that does not exist —
indistinguishable from a real one downstream. Dev-mode stubs must be gated on an explicit
non-production flag and never reachable from an exception handler.

### AVOID-06 · In-process live state — a constraint, not a pattern
`chess_ws_manager.py` holds authoritative board state in a process dictionary; its own docstring
concedes "single-process only." That decision is why `fly.toml` pins the app to one machine,
which is why the rate limiter can be in-process, which is why the scheduler needs a leader lock.
It works, and for one club it is the right call — but it is a constraint the rest of the
architecture is bent around, not a reusable real-time pattern.

### AVOID-07 · The `[FOUNDATIONAL]` tables — premature abstraction
`models/workflow.py` (`WorkflowState`, `ApprovalRequest`) and `models/dynamic_forms.py`
(`FormDefinition`, `FormSubmission`) are both docstringed "Planned for future milestone" and
have no service, router or caller. They are what a generic workflow engine looks like when
designed before a use case.

**The irony is instructive:** the real, working, genuinely general workflow engine in that
repository is `complaint_routing.py` — and it exists *because* it was written for one hard
concrete case.

### AVOID-08 · FYC's global search — right shape, wrong engine
Seven sequential `ILIKE '%q%'` queries with a hardcoded `limit(10)` each, no ranking, no index
usable by a leading wildcard, results concatenated in table order. Keep the federated
`SearchResult` envelope; replace the engine (`REUSE-15`).

### AVOID-09 · SEASON BLACK's pricing constants — deliberately specific
`internal/order/pricing.go` hardcodes two SKUs, one bundle and a refusal to price a mixed pair.
Correct design for a two-product brand; a terrible base for a general pricing engine. Extract
`money` and `gst`; leave `pricing` where it is.

### AVOID-10 · ZISUN's ML and recommendation plan — already refuted, in writing
`models/ml.py`, the pgvector plan and the collaborative-filtering roadmap. ZISUN's own strategy
document does the arithmetic and concludes the engine "cannot work for years — by mathematics,
not opinion," needing ~10,000 users and 500K events against roughly zero. Do not port the
intent elsewhere; the same arithmetic applies to Gypsy.

### AVOID-11 · TheGypsy's unbuilt schema — don't mistake tables for capability
`schema/commerce.ts` (affiliate clicks, subscriptions with four Stripe price tiers) and
`schema/organizations.ts` (plans, member limits, Stripe customer IDs) are complete, indexed,
typed — and have no code reading or writing them. When surveying "what do I already have,"
these will look like a billing system and a multi-tenant system. They are a design sketch in
DDL. FYC's tenancy is the one that runs.

### AVOID-12 · The Fly-specific client-IP resolution, copied verbatim
`REUSE-11` is high value, but `_ON_FLY = bool(os.getenv("FLY_APP_NAME"))` and a literal
`Fly-Client-IP` are host-specific. The reusable idea is: *trust a proxy header only when you can
independently verify you are behind that proxy, and prefer a header the proxy sets over one it
appends to.* Parameterise the header name and the detection signal.

---

## 10. Defects found while reading

Not the assignment, but found by tracing the flows. Each is reproducible from the file named.

| ID | Repo | File | Defect | Consequence |
|---|---|---|---|---|
| `DEF-01` | FYC | `backend/app/services/notifications.py` | Posts to `fcm.googleapis.com/fcm/send` with an `Authorization: key=` header — the FCM legacy API, decommissioned June 2024. Still imported by `birthdays.py` and `routers/issues.py` | Birthday pushes, issue-assigned and issue-resolved pushes never arrive. Failures are logged, not raised, so it looks healthy |
| `DEF-02` | FYC | `backend/app/services/whatsapp_service.py` | `MetaCloudWhatsAppProvider.send_template()` accepts a `parameters` dict and never places it in the request body — the payload has a template name and language and no `components` | Any approved template with variables is rejected by Meta or sent with empty placeholders. The `{"title":…, "body":…}` passed by `notification_service` is silently discarded |
| `DEF-03` | FYC | `backend/app/services/whatsapp_broadcast.py` | `send_to_group()` posts `"recipient_type": "group"` to the Cloud API, which has no group-messaging capability on this endpoint | The group half of the daily broadcast cannot succeed; the failure is caught and logged as a warning, and `group_ok` reports false forever |
| `DEF-04` | ZISUN | `backend/app/services/checkout.py` | Razorpay failure falls back to `mock_order_{id}` in all environments | Unpayable orders holding reserved inventory, indistinguishable from real ones (`AVOID-05`) |
| `DEF-05` | ZISUN | `backend/app/middleware/rate_limit.py` | `request.client.host` behind a proxy — the bug FYC diagnosed and fixed | All users share one bucket, or the limit is bypassable, depending on deployment (`DUP-05`) |
| `DEF-06` | FYC | `backend/app/services/ai_service.py` | `generate_news_summary` calls `asyncio.get_event_loop().run_until_complete()`; the running-loop branch is an empty `pass` with a comment acknowledging it | Raises or deadlocks if ever called from an async context; only works from the scheduler thread |
| `DEF-07` | TheGypsy | `apps/web/lib/trips.ts` | Invite tokens are generated and stored; no email sender exists anywhere in the repo despite `RESEND_API_KEY` in `.env.example` | The core "invite your group" loop requires manually copying a URL |

---

## 11. If you do only five things

Ordered by consequence, in the spirit of `internal/ops/ops.go` — money and correctness first,
then things that unblock a product, then things that compound.

| # | Do this | Because | Effort | IDs |
|---|---|---|---|---|
| 1 | Fix the seven defects, starting with FYC's dead push path and ZISUN's mock-payment fallback | Three of them are silent — the systems report success. Nothing else matters while notifications are not arriving | 2–3 d | `DEF-01`…`DEF-07` |
| 2 | Port the GST engine and money type into ZISUN | An Indian commerce platform that cannot compute tax cannot invoice. The knowledge is perishable and already held, current to Sept 2025 | 1–2 d | `REUSE-01` |
| 3 | Extract the outbox as one shared package and put all four WhatsApp senders behind it | Collapses the corpus's worst duplication and removes silent message loss everywhere at once | 3–4 d | `REUSE-02`, `DUP-01`, `AVOID-02` |
| 4 | Give FYC, ZISUN and TheGypsy a context spine and an ADR ledger | Half a day per repository, and it is the mechanism that stops the next agent inventing the next wrong assumption. It is also the thing worth publishing | ½ d each | `REUSE-05`, `INV-01`, `IDEA-01` |
| 5 | Build one worklist page per operating product, replacing the CRUD admin as the landing screen | The only change on this list that gives time back every single day these businesses run | 2 d each | `REUSE-04`, `SHAPE-3` |

**The thing to notice:** every item on that list already exists somewhere in these four
repositories. Not one is new work — they are all *moving work already done to where it is
needed a second time.* That is the state of the corpus: not short of engineering, short of a
shared shelf to put it on.

---

## Provenance and caveats

Claims above name the file they came from. Where a claim rests on an **external** fact it is
marked as such and should be re-verified before acting:

- The FCM legacy HTTP API shutdown (June 2024) — `DEF-01`
- The GST per-piece threshold of ₹2,500 from Notification 9/2025-CT(R), 22 September 2025 — `REUSE-01`, sourced from SEASON BLACK's own `internal/gst/gst.go` comment
- WhatsApp Cloud API group-messaging support — `DEF-03`

Line counts exclude binary assets and were measured with `git ls-files` filtered by extension.
Effort estimates are judgement, not measurement.

---

## Appendix — what this means for FYC Connect

This repository is the corpus's **richest source of ideas and its largest holder of debt** —
often in the same file. It exports more distinct inventions than the other three combined, and
it owns four of the seven defects.

**Fix first (all found here)**

| ID | File | Fix |
|---|---|---|
| `DEF-01` | `backend/app/services/notifications.py` | Dead FCM legacy API. Delete the module; move `birthdays.py` and `routers/issues.py` onto `NotificationService`; port the topic-broadcast idea to firebase-admin |
| `DEF-02` | `backend/app/services/whatsapp_service.py` | `send_template()` drops its `parameters` — add the `components` block to the Meta payload |
| `DEF-03` | `backend/app/services/whatsapp_broadcast.py` | Cloud API has no group send on this endpoint. Either drop the group path or replace it with a per-member template send through the outbox |
| `DEF-06` | `backend/app/services/ai_service.py` | `get_event_loop().run_until_complete()` with an empty running-loop branch |

**Exports (things other repositories should take from here)**

| ID | What | To |
|---|---|---|
| `REUSE-03` | Escalation ladder: `complaint_routing` + `jurisdiction` + `complaint_workflow` | A package, and `IDEA-02` |
| `REUSE-06` | `NotificationPreference` model + write-then-deliver ordering | TheGypsy, ZISUN |
| `REUSE-08` | `models/ai_content.py` — AI cache keyed (tenant, type, date) | TheGypsy |
| `REUSE-09` | Multi-tenant kernel: `TenantModelMixin` + contextvar + cross-tenant assertion | TheGypsy |
| `REUSE-10` | `ProfileAttribute` + `ProfilePromptState` + question catalogue | TheGypsy, ZISUN |
| `REUSE-11` | `core/rate_limit.py` `client_ip()` | ZISUN (see `AVOID-12` — generalise first) |
| `REUSE-13` | `core/etag.py` | ZISUN, TheGypsy |
| `REUSE-14` | `core/short_code.py` | ZISUN, SEASON BLACK |
| `REUSE-17` | `core/scheduler_lock.py` | SEASON BLACK |
| `REUSE-18` | `models/audit.py` | ZISUN, TheGypsy |
| `REUSE-21` | Polymorphic `Follow` / `Comment` / `CommunityActivity` | TheGypsy |
| `INV-05` | `mobile/lib/core/services/` — device tiers, offline outbox, crash reporter, OTA updater | `IDEA-04` |
| `INV-06` | `core/i18n.py` + `lib/core/l10n/registry/` | ZISUN |

**Imports (things worth taking from elsewhere)**

| ID | What | From | Why |
|---|---|---|---|
| `REUSE-02` | Transactional outbox | SEASON BLACK | Replaces `WhatsAppQueueManager`, which loses every failed message (`AVOID-02`) |
| `REUSE-04` | Operator worklist | SEASON BLACK | The inputs already exist — `next_due()`, open blood requests, unreviewed complaints, stuck broadcasts — and are never assembled into one ranked page |
| `REUSE-05` | Context spine | SEASON BLACK | 46 routers and several files whose comments describe a previous agent's confident wrong assumption. This is the strongest case in the corpus |
| `REUSE-07` | Injected `ChatCompleteFn` seam + tolerant parser | TheGypsy | `ai_service.py` has no test seam and repeats fence-stripping three times |
| `REUSE-12` | Redis sliding-window limiter | ZISUN | Only if the single-machine pin is ever lifted (`AVOID-06`) |
| `REUSE-15` | tsvector search | ZISUN | `routers/search.py` is 7 sequential `ILIKE '%q%'` scans (`AVOID-08`) |
| `REUSE-19` | SQL invariant suite | SEASON BLACK | 35 model modules, no schema-level proof that impossible states are refused |
| `REUSE-20` | Design-token + copy lints | SEASON BLACK | There is a Flutter design system with `tokens.dart` and no lint enforcing it |
| `REUSE-22` | Expense split + settlement graph | TheGypsy | Club fund management, event cost-sharing |

**Also fix before `IDEA-05` (white-labelling) is possible**

`AVOID-04` — `_DEFAULT_ORG_ID` hardcoded in `whatsapp_broadcast.py`, Kanyakumari seeds in
`models/directory.py`, and Nagercoil named in the `ai_service.py` complaint prompt. The tenancy
is real; these three make it untrue in practice.

**Decide, don't drift:** `DUP-09`. `broadcast_to_tenant` sends AI-rewritten copy to every member
unreviewed, while the emergency path deliberately bypasses the rewriter. Make that exception the
stated rule: AI may rewrite discretionary copy; never copy carrying a fact someone acts on.
