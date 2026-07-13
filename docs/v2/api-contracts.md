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
Add columns (nullable, additive — startup reconcile handles them):
- `is_featured: bool` (or reuse `is_pinned`) — carousel inclusion.
- `cta_route: str?` — deep-link target (e.g. `/sports`, `/blood-donation`).
- `cta_label: str?` — button text.
Extend `AnnouncementCategory` with: `TOURNAMENT`, `FESTIVAL`, `VOLUNTEER_DRIVE`,
`GOVT` (keep existing). `auto_announce` should set `banner_url` where an image
exists. Carousel query: featured + not-expired, ordered.

### `GET /search` (Phase 3.5)
Add result branches: `OPPORTUNITY` (jobs) and `SCHOOL`. Same 10-per-type,
`?types=` pattern as existing branches. News stays RSS (out of the SQL search).

## New

### `GET /sports/live` (Phase 2.2)
Cross-tournament aggregate for the Home live strip (no such endpoint today).
```
{
  "live":     [{ fixture_id, tournament_name, sport, team_a, team_b, match_state_summary }],
  "upcoming": [{ fixture_id, tournament_name, sport, team_a, team_b, scheduled_at }],
  "results":  [{ fixture_id, tournament_name, sport, team_a, team_b, result }]
}
```
Tenant-scoped. `live` = fixtures with `status == LIVE`; `upcoming` = next N by
`scheduled_at`; `results` = recent `COMPLETED`.

### `GET /me/continue` (Phase 3.1)
Aggregator of the signed-in user's in-progress items (hide section when empty).
```
{ "items": [{ type, title, subtitle, cta_route, progress? }] }
```
Stitches existing partial states: member `DRAFT` tournaments, `PENDING` team
registrations, open issues. A small `Draft` store may be added for half-finished
forms if needed.

### `GET /me/recommendations` (Phase 3.3)
Personalized suggestions.
```
{ "recommendations": [{ type, title, reason, cta_route, score }] }
```
v1 signals: nearby blood camp (via `geography_id`), tournament registration
closing soon, opportunity matching the user. Read-only scoring service; no writes.

### Today's-info proxies (Phase 4.4)
Fuel price, AQI, rain alert — follow the existing weather/gold proxy pattern
(backend-cached upstream fetch), same `ApiClient` consumption on mobile.

## Conventions
- All list endpoints tenant-scoped via `require_tenant_id` unless explicitly public.
- Contact/PII fields never appear on public/unauthenticated responses.
- Schema changes are additive; rely on the startup column-reconcile — no
  destructive migrations.
