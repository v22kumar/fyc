# V2 API Contracts

What V2 consumes and what it adds. Existing endpoints are documented as-is;
new/changed ones list the target shape so mobile and backend stay in lock-step.

## Existing — consumed as-is

| Endpoint | Returns (relevant fields) | Used by |
|----------|---------------------------|---------|
| `GET /community/stats` | `total_volunteers`, `total_events`, `total_blood_donations`, `total_trees_planted`, `total_issues_solved` | stats counters |
| `GET /community/feed?limit=` | merged events + tournaments + resolved issues, date-sorted | community feed |
| `GET /events` | `EventOut`: title/desc, `event_start/end`, `banner_url`, `registration_count`, `requires_registration`, `registration_deadline`, `max_participants` | upcoming events |
| `GET /announcements?category=` | `AnnouncementOut`: title/body, `banner_url`, `is_pinned`, `category`, `expires_at`; pinned-first | hero carousel |
| `GET /search?q=&types=` | grouped results: user/event/tournament/team/issue/blood_donor/announcement | universal search |
| `GET /fixtures/{id}/cricket` | live `match_state` JSON | live sports (per-fixture) |

## Changed

### `GET /community/stats` (Phase 2.5)
Add: `total_members`, `total_schools`. Consider a short server-side cache (counts
run live per call today). Additive to `CommunityStatsOut`.

### `Announcement` model + `GET /announcements` (Phase 2.1)
Add columns (additive — startup reconcile handles them):
- **`is_featured: bool`** — the **one canonical** carousel-inclusion flag.
  `NOT NULL`, server default `false`. GET responses always return it; writes
  default to `false` unless an admin sets it true. (`is_pinned` is left as-is
  and only affects list ordering, never carousel membership — the two are
  orthogonal.)
- `cta_route: str?` (nullable) — deep-link target (e.g. `/sports`, `/blood-donation`).
- `cta_label: str?` (nullable) — button text.

Extend `AnnouncementCategory` with: `TOURNAMENT`, `FESTIVAL`, `VOLUNTEER_DRIVE`,
`GOVT` (keep existing). `auto_announce` should set `banner_url` where an image
exists.

**Carousel query** (`GET /announcements?featured=true`): `is_featured == true`
AND (`expires_at IS NULL` OR `expires_at > now`), ordered `is_pinned` desc then
`created_at` desc, capped at 8.

### `GET /search` (Phase 3.5)
Add result branches: `OPPORTUNITY` (jobs) and `SCHOOL`. Same 10-per-type,
`?types=` pattern as existing branches. News stays RSS (out of the SQL search).

## New

### `GET /sports/live` (Phase 2.2)
Cross-tournament aggregate for the Home live strip (no such endpoint today).
```json
{
  "live":     [{ "fixture_id": "…", "tournament_name": "…", "sport": "cricket", "team_a": "…", "team_b": "…", "match_state_summary": "142/4 (17.2)" }],
  "upcoming": [{ "fixture_id": "…", "tournament_name": "…", "sport": "cricket", "team_a": "…", "team_b": "…", "scheduled_at": "2026-07-14T09:30:00Z" }],
  "results":  [{ "fixture_id": "…", "tournament_name": "…", "sport": "cricket", "team_a": "…", "team_b": "…", "result": "Eagles won by 12 runs" }]
}
```
Tenant-scoped. Deterministic so mobile and backend agree exactly:
- **`live`** = all fixtures with `status == LIVE`, ordered `updated_at` desc
  (most recently scored first). No cap (typically few).
- **`upcoming`** = next fixtures with `status == UPCOMING` and `scheduled_at >= now`,
  ordered `scheduled_at` asc, tie-break `fixture_id` asc; **default 5, max 10**
  (`?upcoming_limit=`).
- **`results`** = fixtures `status == COMPLETED` within the **last 7 days**,
  ordered `updated_at` desc, tie-break `fixture_id` asc; **default 5, max 10**
  (`?results_limit=`).

### `GET /me/continue` (Phase 3.1)
Aggregator of the signed-in user's in-progress items (hide section when empty).
```json
{ "items": [{ "type": "…", "title": "…", "subtitle": "…", "cta_route": "…", "progress": 0.6 }] }
```
Stitches existing partial states: member `DRAFT` tournaments, `PENDING` team
registrations, open issues. A small `Draft` store may be added for half-finished
forms if needed.

### `GET /me/recommendations` (Phase 3.3)
Personalized suggestions.
```json
{ "recommendations": [{ "type": "…", "title": "…", "reason": "…", "cta_route": "…", "score": 0.82 }] }
```
v1 signals: nearby blood camp (via `geography_id`), tournament registration
closing soon, opportunity matching the user. Read-only scoring service; no writes.

### Today's-info proxies (Phase 4.4)
Fuel price, AQI, rain alert — follow the existing weather/gold proxy pattern
(backend-cached upstream fetch), same `ApiClient` consumption on mobile.

## Conventions
- **Tenant isolation is mandatory, always.** Every endpoint resolves a tenant
  (`require_tenant_id`) and filters by `organization_id`. "Public" means only
  that authentication may be omitted — it never means cross-tenant: a public
  endpoint still requires the `X-Organization-ID` header and returns only that
  org's rows.
- Contact/PII fields never appear on public/unauthenticated responses.
- Schema changes are additive; rely on the startup column-reconcile — no
  destructive migrations.
