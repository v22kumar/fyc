# Project Roadmap & Scope Specification

## 1. Phased Product Scope Boundaries

To ensure immediate utility, low risk, and rapid delivery, the development of FYC Connect is split into three logical phases.

```
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 1: MVP SCOPE                                              │
│ - Bilingual Core (Tamil/English via translation keys)            │
│ - OTP Authentication & Profile Management                       │
│ - Blood Donor Network (Search, request, wa.me deep links)        │
│ - Public Issue Triage (New, Assigned, Under Review, Resolved...) │
│ - Membership Management (Bilingual IDs, QR generation)           │
│ - Basic Event Co-ordination & Media Gallery                      │
│ - Admin CMS (Announcements, Directory contacts, Banner uploads)  │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 2: COMMUNITY ENGAGEMENT & OFFLINE ENGINE                  │
│ - Opportunity Hub (Exam notification, scholarship scraping)      │
│ - Green FYC (Sapling registration, geo-tracking, CO2 dashboard)  │
│ - Volunteer Skills Matrix & Hours Calculation Ledger             │
│ - Verifiable Digital Certificates (signed PDFs + verification QR) │
│ - Mobile Offline Cache & DB Sync Engine                          │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 3: ENTERPRISE & SAAS MULTI-TENANCY EXPANSION               │
│ - Multi-Tenant SaaS onboarding (NGOs, Clubs, Village orgs)        │
│ - Document Repository (Meeting minutes, constitutions, reports)  │
│ - Advanced Analytics & Impact Dashboards                        │
│ - WhatsApp Business API Automated Notification triggers          │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. Detailed Phase Breakdown

### 2.1. Phase 1: MVP Scope (Current Development Target)
The MVP focus is on solving critical core communication bottlenecks:
* **Authentication:** Mobile number registration verified via OTP. Scoped by Tenant Organization ID.
* **Bilingual UI:** Every page and administrative input supports Tamil and English, powered by static json locale catalogs.
* **Blood Donation:** Searchable database filtered by District and Taluk. Call and WhatsApp button deep links to donor (`wa.me`) immediately, avoiding expensive APIs.
* **Public Issues:** Citizen records issue with geolocation coordinates and camera capture. Admin assigns the issue, tracking through the state machine.
* **Event Management:** Admin logs event, generates check-in QR codes. Members check-in via mobile.
* **Notifications:** Push notifications sent through Firebase Cloud Messaging for urgent blood requests and event changes.

### 2.2. Phase 2: Community Engagement & Caching
* **Opportunity Hub (SNO-003):** Automate job, exam, and scholarship listings via cron-based FastAPI scrapers.
* **Green FYC:** Plant trees, track growth, log longitude/latitude. Show survival rate (e.g. 85%) on public dashboard.
* **Volunteer Hours Ledger:** Accrued hours tracked when checked in to drives. Generate PDF certificates.
* **Offline Caching (SNO-014):** Cache emergency contacts and events locally in sqlite (Flutter) to function when networks fail.

### 2.3. Phase 3: SaaS & Scale
* **SaaS Tenancy:** Multi-tenant domain routing. Admin dashboard gets configuration panels for custom organization branding.
* **Document Repository:** Cloud storage integration for club constitutions, auditing PDFs, and board meeting minutes.
* **Advanced Analytics:** Metabase or custom dashboard charts displaying monthly issues logged/resolved, active donors by region.

---

## 3. Technology Stack Specification

| Component | Technology | Rationale |
|---|---|---|
| **Mobile App** | **Flutter (Dart)** | Matches high-fidelity visual expectations (Forest Green theme), native Android performance, single code base for future iOS launch. |
| **Public Web** | **Astro (JS/TS)** | Superior SEO, fast load times for anonymous users searching contacts or blood availability without installation. |
| **Admin Portal**| **Next.js (React)** | Premium dashboard experience, rich library ecosystem (charts, datagrids), fast local updates. |
| **Backend APIs**| **FastAPI (Python)**| Extremely performant asynchronous request handling. Aligns with internal developer Python expertise (SNO-001). |
| **Database** | **PostgreSQL** | Standard open-source relational database. Essential for managing complex geographic hierarchy and multi-tenant scoping. |
| **Caching/Queue**| **Redis** | In-memory key-value cache. Manages notification queues and translation catalog updates. |
| **File Storage** | **S3 / MinIO** | Stores public issues photos, member profile avatars, and event banner graphics. |

---

## 4. Development Timeline & Milestones (16-Week Estimate)

```
Milestone 1: Backend Core & Multi-Tenant Setup (Weeks 1-2)
████████ 12%
Milestone 2: Database Design & Astro Web Base (Weeks 3-4)
        ████████ 25%
Milestone 3: Flutter Mobile Base & Blood Donation Hub (Weeks 5-7)
                ████████████ 44%
Milestone 4: Public Issues State Machine & Triage (Weeks 8-10)
                            ████████████ 62%
Milestone 5: Event Management & Digital Membership ID (Weeks 11-12)
                                        ████████ 75%
Milestone 6: Bilingual Configuration & Testing (Weeks 13-14)
                                                ████████ 87%
Milestone 7: Deployment & Verification (Weeks 15-16)
                                                        ████████ 100%
```

### 4.1. Detailed Milestones
* **Weeks 1-2:** Spin up PostgreSQL. Scaffold FastAPI framework. Set up tenant middleware and security/JWT routines.
* **Weeks 3-4:** Create database tables. Implement Astro static website layout. Write anonymous search logic.
* **Weeks 5-7:** Scaffold Flutter app layout. Implement BLoC logic for OTP login. Build Blood Donation registration forms and WhatsApp deep-linking widgets.
* **Weeks 8-10:** Develop camera API capture on Flutter. Setup S3 media upload. Integrate the issue workflow state machine. Build the Admin Board in Next.js for triage.
* **Weeks 11-12:** Build membership schema. Program membership card views. Write QR code scanner logic in Flutter.
* **Weeks 13-14:** Sync translation keys (`ta.json`, `en.json`). Conduct integration testing across web, admin, and mobile.
* **Weeks 15-16:** Dockerize services. Deploy to VPS. Perform functional verification against PRD.

---

## 5. Risks & Mitigation Strategy

| Risk Category | Identified Risk | Impact | Mitigation Strategy |
|---|---|---|---|
| **Tech Adoption** | Citizens refuse to install mobile app on storage-constrained phones. | High | **Astro Public Website:** Zero-install entry point. Citizens can submit issues and search blood donors anonymously from mobile browsers. |
| **Bilingual Overhead**| Hardcoded strings slip into UI, breaking Tamil compatibility. | Medium | **Linter & CI Checks:** Program local linter checks in Flutter and Next.js that fail build processes if hardcoded user-facing strings are detected outside localized asset files. |
| **Spam Submission** | False or abusive public issues reported. | High | **Volunteer Triage:** System does not publish issues to public maps until an Admin verifies them or assigns them to a volunteer. |
| **Network Loss** | Poor connectivity in village wards stops issue logging. | Medium | **Phase 2 Offline Sync:** Cache database actions locally. Allow queueing offline reports; sync automatically when connection restores. |
| **Operational Costs** | High cloud hosting costs break budget. | High | **FastAPI & VPS:** Low CPU footprint. FastAPI backend, Astro web, and PostgreSQL can run comfortably on a single $5/month VPS. |
