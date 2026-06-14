# FYC Connect — PRD Verification Checklist
# Milestone 7: Functional Verification Against PRD

## How to Use
- ✅ = Verified and passing
- ❌ = Failing (note the issue)
- ⏭️ = Skipped / Phase 2

Run all API tests: `cd backend && pytest tests/ -v`
Test suite result: **57 tests passing** (as of Milestone 6)

---

## Module 1: Multi-Tenant Architecture (PRD §6.1)

| Check | Method | Status |
|---|---|---|
| Organization data isolated by `X-Organization-ID` header | `pytest tests/test_tenant.py` | ✅ |
| JWT token scoped to one organization | Token decode check | ✅ |
| Cross-org data access blocked | `test_generate_card_cross_org_denied` | ✅ |
| Organization creation by SUPER_ADMIN only | `test_create_organization_non_admin_denied` | ✅ |

## Module 2: Authentication & OTP (PRD §6.1)

| Check | Method | Status |
|---|---|---|
| OTP send via phone number | `pytest tests/test_auth.py` | ✅ |
| OTP verify returns JWT | `test_otp_verify_*` | ✅ |
| Invalid OTP rejected | `test_otp_verify_invalid_code` | ✅ |
| Password login for admin | `test_admin_password_login_success` | ✅ |
| Wrong password rejected | `test_admin_password_login_failure` | ✅ |
| OTP randomised in production (`OTP_BYPASS_CODE=""`) | Manual check | ✅ |
| Rate limit: 5 OTP requests/minute | slowapi middleware | ✅ |
| Bilingual auth screens (Tamil/English) | Mobile UI | ✅ |

## Module 3: Blood Donor Network (PRD §6.2)

| Check | Method | Status |
|---|---|---|
| Donor registration with blood group | `test_register_blood_donor` | ✅ |
| Invalid blood group rejected | `test_register_donor_invalid_blood_group` | ✅ |
| Duplicate donor blocked | `test_register_donor_duplicate` | ✅ |
| Anonymous donor search (no phone shown) | `test_search_donors_public` | ✅ |
| Unavailable donors excluded from search | `test_search_donors_no_results_for_unavailable` | ✅ |
| Contact request requires authentication | `test_request_contact_unauthenticated_denied` | ✅ |
| Authenticated user can request contact | `test_request_contact_authenticated` | ✅ |
| Availability toggle update | `test_update_availability` | ✅ |
| WhatsApp deep-link on mobile | Flutter UI `url_launcher` | ✅ |
| Bilingual donor hub (Tamil/English) | Mobile UI | ✅ |

## Module 4: Public Issue Triage (PRD §6.3)

| Check | Method | Status |
|---|---|---|
| Anonymous issue submission | `test_submit_issue_anonymous` | ✅ |
| Authenticated issue submission | `test_submit_issue_authenticated` | ✅ |
| Missing org header blocked | `test_submit_issue_no_org_header` | ✅ |
| Issue list with status filter | `test_list_issues` | ✅ |
| Issue state machine: NEW → ASSIGNED | `test_issue_state_machine_assign` | ✅ |
| Invalid transition rejected | `test_issue_invalid_transition` | ✅ |
| Full lifecycle: NEW→ASSIGNED→RESOLVED→CLOSED | `test_issue_full_lifecycle` | ✅ |
| Camera capture on mobile | Flutter `image_picker` | ✅ |
| Photo upload to `/uploads/` | FastAPI media endpoint | ✅ |
| GPS coordinates attached to issue | Mobile `_LocationRow` | ✅ |
| Admin triage board (Next.js) | Manual UI | ✅ |
| Bilingual issue form | Mobile UI | ✅ |

## Module 5: Event Management (PRD §6.4)

| Check | Method | Status |
|---|---|---|
| Executive can create event | `test_create_event_executive` | ✅ |
| Citizen cannot create event | `test_create_event_citizen_denied` | ✅ |
| Invalid dates rejected | `test_create_event_invalid_dates` | ✅ |
| Event listing | `test_list_events` | ✅ |
| Event not found returns 404 | `test_get_event_not_found` | ✅ |
| Volunteer check-in | `test_event_checkin_volunteer` | ✅ |
| Duplicate check-in blocked | `test_event_checkin_duplicate` | ✅ |
| Citizen check-in denied | `test_event_checkin_citizen_denied` | ✅ |
| QR scanner on mobile | Flutter `mobile_scanner` | ✅ |
| Bilingual event cards (upcoming/past) | Mobile + Web UI | ✅ |
| Admin event creation form | Next.js `/dashboard/events` | ✅ |

## Module 6: Digital Membership ID (PRD §6.5)

| Check | Method | Status |
|---|---|---|
| Admin generates membership card | `test_generate_membership_card` | ✅ |
| Duplicate card blocked | `test_generate_card_duplicate` | ✅ |
| Cross-org card generation denied | `test_generate_card_cross_org_denied` | ✅ |
| Non-admin cannot generate card | `test_non_admin_cannot_generate_card` | ✅ |
| Member retrieves own card | `test_get_my_card` | ✅ |
| Missing card returns 404 | `test_get_my_card_not_found` | ✅ |
| Public QR verification | `test_verify_membership_card` | ✅ |
| Invalid card returns 404 | `test_verify_nonexistent_card` | ✅ |
| Admin card list (org-scoped) | `test_list_membership_cards_admin` | ✅ |
| Non-admin list denied | `test_list_membership_cards_non_admin_denied` | ✅ |
| Flip-card UI on mobile | Flutter `MembershipCardScreen` | ✅ |
| Public verify page | Astro `/verify` | ✅ |

## Module 7: Bilingual Configuration (PRD §2)

| Check | Method | Status |
|---|---|---|
| Tamil (ta) locale complete | `strings_ta.dart` — 72 keys | ✅ |
| English (en) locale complete | `strings_en.dart` — 72 keys | ✅ |
| JSON translation files (OTA-ready) | `assets/translations/ta.json` + `en.json` | ✅ |
| No hardcoded strings in Dart files | `python scripts/check_hardcoded_strings.py` | ✅ |
| Language toggle on web (Tamil/English) | Astro `data-ta`/`data-en` | ✅ |
| Language persisted across sessions | `localStorage.fyc_lang` | ✅ |
| All blood donor screens bilingual | Mobile UI | ✅ |
| All issue screens bilingual | Mobile UI | ✅ |
| Membership card bilingual | Mobile UI | ✅ |

## Module 8: Admin CMS (PRD §6.6)

| Check | Method | Status |
|---|---|---|
| Admin login with password | Next.js `/login` → JWT | ✅ |
| Auth guard on all dashboard routes | `layout.tsx` redirect | ✅ |
| Issues triage board | `/dashboard/issues` | ✅ |
| Status transition buttons | `IssueDetailDrawer` | ✅ |
| Volunteer assignment | Dropdown in drawer | ✅ |
| Photo preview in triage | `<img src={photoUrl}>` | ✅ |
| GPS → Google Maps link | Triage drawer | ✅ |
| Events management | `/dashboard/events` | ✅ |
| Members list with role filter | `/dashboard/members` | ✅ |
| Membership card generation | `/dashboard/membership` | ✅ |
| Media upload (S3-compatible) | `/api/v1/media/upload` | ✅ |

## Module 9: Deployment & Infrastructure (PRD §7)

| Check | Method | Status |
|---|---|---|
| Backend Dockerfile builds | `docker build ./backend` | ✅ |
| Web Dockerfile builds (Astro SSG) | `docker build ./web` | ✅ |
| Admin Dockerfile builds (Next.js) | `docker build ./admin` | ✅ |
| Full stack docker-compose | `docker compose up -d` | ✅ |
| PostgreSQL health check | compose healthcheck | ✅ |
| Nginx reverse proxy config | `nginx/nginx.conf` | ✅ |
| DB init script | `backend/scripts/init_db.py` | ✅ |
| `.env.example` documented | `.env.example` | ✅ |
| SSL via Let's Encrypt | `docs/deployment_guide.md` | ✅ |
| Backup/restore documented | `docs/deployment_guide.md` | ✅ |

---

## Phase 2 Features (Out of Scope for MVP)

| Feature | PRD Reference | Status |
|---|---|---|
| Green FYC tree tracking | §2.2 | ⏭️ Phase 2 |
| Opportunity Hub (scholarship scraper) | §2.2 | ⏭️ Phase 2 |
| Volunteer hours ledger + PDF certs | §2.2 | ⏭️ Phase 2 |
| Offline mobile cache (SQLite sync) | §2.2 | ⏭️ Phase 2 |
| Firebase push notifications | §2.1 | ⏭️ Phase 2 |
| WhatsApp Business API integration | §2.3 | ⏭️ Phase 3 |
| SaaS multi-tenant onboarding | §2.3 | ⏭️ Phase 3 |
| Advanced analytics dashboard | §2.3 | ⏭️ Phase 3 |

---

## Test Suite Summary

```
Backend: 57 tests, 0 failures (pytest)
CI lint: python scripts/check_hardcoded_strings.py → 0 violations
```

**MVP Phase 1 is feature-complete and verified.**
