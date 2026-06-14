# Product Requirements Document (PRD) - FYC Connect

## 1. Executive Summary

### 1.1. About Friends Youth Club (FYC)
Friends Youth Club (FYC) is a social welfare organization established in 2000, with roots in community service dating back to 1998 in Tamil Nadu, India. For over 25 years, FYC has actively served local communities through:
* **National celebrations:** Organising flag-hoisting and community events on Independence Day.
* **Social welfare:** Supporting underprivileged groups, conducting blood drives, and responding to emergency public needs.
* **Community development:** Facilitating infrastructure improvements and liaison with local governments.
* **Environmental protection:** Running tree plantation campaigns and cleaning drives.
* **Educational support:** Guiding students, sharing examination notices, and offering scholarship assistance.

### 1.2. Problem Statement
Despite its active ground presence, FYC operations are heavily reliant on manual processes:
* Community issues (like road repairs or street light outages) are reported via disjointed channels (WhatsApp, phone calls), making tracking and resolution difficult to monitor.
* Blood donation requests rely on broad WhatsApp forwards, which lack structured search and expose donor phone numbers publicly without access control.
* Member records, event planning, and financial transparency tracking exist in offline spreadsheets, creating overhead for club executives.
* Public outreach is constrained by the lack of an search-engine-optimized (SEO) public web presence.

### 1.3. Project Goal (Digital Transformation)
The goal of **FYC Connect** is to digitally transform the club into a modern, multi-tenant, bilingual platform. The platform will bridge the gap between citizens, volunteers, and club administration, providing structured, transparent, and scalable tools for local community development.

---

## 2. Product Vision
To build a **mobile-first, web-accessible, multi-tenant** community coordination ecosystem that enables citizens to report local issues, connect with blood donors, and access government directories, while empowering FYC (and other future NGOs) with event coordination, membership records, and transparent financial reporting.

### 2.1. Core Principles
* **Mobile-First & Android-First:** Developed with Flutter to ensure a premium native experience on budget Android devices.
* **Public Web Discoverability:** Built with Astro for the public website to maximize search engine optimization (SEO) and allow zero-install public actions.
* **Bilingual from Day 1:** Seamless support for Tamil (primary) and English (secondary) across all user interfaces, notifications, forms, and administrative logs.
* **Multi-Tenant Ready:** Architected to support multiple youth clubs, village associations, and NGOs under a shared SaaS infrastructure.
* **Accountability & Privacy:** Audited action history for all workflow updates, combined with secure role-based data access (RBAC).

---

## 3. Product Success Metrics (KPIs)
To measure the real-world impact and adoption of the FYC Connect platform, the following Key Performance Indicators (KPIs) are defined for the first 12 months post-launch:

| Metric | Target Value | Description | Priority |
|---|---|---|---|
| **Registered Users** | 500+ | Total registered citizens, volunteers, and members on the mobile platform. | High |
| **Blood Donors** | 200+ | Verified donors registered in the blood network across target districts. | High |
| **Public Issues Logged** | 100+ | Public infrastructure/safety concerns submitted by citizens. | High |
| **Issue Resolution Rate** | 75% | Percentage of logged issues successfully resolved and closed. | Medium |
| **Active Club Members** | 100+ | Active club members managing events, directory, and approvals. | High |
| **Annual Events Hosted** | 25+ | Community events, drives, and meetings coordinated through the platform. | High |
| **Trees Registered** | 1000+ | (Phase 2) Total saplings registered and geo-tracked in Green FYC. | Medium |

---

## 4. User Personas

### 4.1. Anbarasan - The Public Citizen (Astro Web / Flutter App)
* **Demographics:** 34-year-old shop owner in Nagercoil. Speaks Tamil fluently, limited English. Uses an entry-level Android phone.
* **Needs:** Wants to report a water supply leak on his street quickly without downloading a heavy app or creating a complex account. Wants to find an O+ blood donor in an emergency.
* **Frustrations:** Hard to find verified government contact numbers. Reports issues to local councilors but never receives updates.

### 4.2. Kavitha - The Volunteer (Flutter App)
* **Demographics:** 21-year-old college student. Fluent in Tamil and conversational English. Highly active on mobile.
* **Needs:** Wants to contribute to community development, track her volunteering hours, and earn digital certificates to bolster her resume. Needs a clear view of issues assigned to her.
* **Frustrations:** WhatsApp groups are cluttered; details about volunteer drives get lost in chat threads.

### 4.3. R. Prathap - The Club President / Executive Member (Next.js Admin Portal / App)
* **Demographics:** 45-year-old business owner, club leader. Fully bilingual.
* **Needs:** Wants to approve new club member requests, audit event expenses, and view community impact metrics (trees planted, blood requests fulfilled) to share in annual reports.
* **Frustrations:** Spends hours calling members to confirm event attendance and tracking sponsorships in paper notebooks.

---

## 5. User Roles & Permissions Matrix
The system supports a hierarchical Role-Based Access Control (RBAC) model across 7 distinct user types:

| Module / Action | Public User (Unreg.) | Registered Citizen | Volunteer | Club Member | Executive Member | Admin | Super Admin |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Language Toggle (Tamil/English)** | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **View Public Events & Gallery** | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **Search Blood Donors (No Phone)** | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **Submit Blood Request** | No | Yes | Yes | Yes | Yes | Yes | Yes |
| **Request Phone/WhatsApp Contact** | No | Yes | Yes | Yes | Yes | Yes | Yes |
| **Report Public Issue** | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **Track My Reported Issues** | No | Yes | Yes | Yes | Yes | Yes | Yes |
| **Assign/Update Issue Status** | No | No | Yes | No | Yes | Yes | Yes |
| **Register Tree Plantation** | No | Yes | Yes | Yes | Yes | Yes | Yes |
| **View Digital Membership Card** | No | No | No | Yes | Yes | Yes | Yes |
| **Create Events & Manage Budgets** | No | No | No | No | Yes | Yes | Yes |
| **Approve Memberships** | No | No | No | No | No | Yes | Yes |
| **Manage CMS Content & Directory** | No | No | No | No | No | Yes | Yes |
| **Manage Tenant Organizations** | No | No | No | No | No | No | Yes |
| **View Activity Logs / Audit Trails** | No | No | No | No | No | Yes | Yes |

---

## 6. Functional Requirements (MVP & Future Phases)

### 6.1. Authentication & Tenant Management (MVP)
* **Multi-Tenancy:** The system must restrict data access based on the logged-in user's organization scope (e.g., FYC Nagercoil, Youth Club B).
* **Bilingual Auth:** Registration, OTP screens, and password reset flows must support Tamil and English.
* **Mobile Sign-in:** Citizen and volunteer signup must support mobile OTP-based login (secure and convenient for regional users) or email.

### 6.2. Blood Donation Network (MVP)
* **Registration:** Users can register as donors, detailing blood group, location (geographic hierarchy), availability status, and last donation date.
* **Search Filters:** Users can filter donors by blood group and geographic location (District/Taluk/Village).
* **Privacy Controls:** Anonymous public users see donor names and locations but cannot access contact details. Registered citizens must request contact, which generates a log entry.
* **Contact Integration:** Click-to-call and click-to-WhatsApp deep links (`wa.me`) directly opening chat with the donor.

### 6.3. Public Issue Reporting (MVP)
* **Anonymous/Registered Submissions:** Users can submit issues from the website (Astro) anonymously or from the app (Flutter). Submissions include category (Road, Water, Street light, Garbage, Safety), description, photo upload, and location coordinates.
* **Geographic Scoping:** Issue is logged against the geographic hierarchy (District, Taluk, Village, Ward).
* **State Machine Workflow:** Transitions strictly from `New` → `Assigned` → `Under Review` (or `Escalated`) → `Resolved` → `Closed` (or `Rejected`).
* **Volunteer Assignment:** Admin/Executive assigns the issue to local volunteers. Volunteers receive push notifications and can update the issue status to `Resolved` with verification photos.

### 6.4. Event & Membership Management (MVP)
* **Digital Identity:** Members receive a membership number, role, and QR code displayed on a digital membership card within the mobile app.
* **Event Creation:** Executive members can create events (title, Tamil/English description, location, dates, banner image, volunteer slots).
* **Attendance Tracking:** Volunteers and members check in via QR code scan at the event venue.
* **Media Gallery:** Public gallery showing photos uploaded from completed events.

### 6.5. Communications & CMS (MVP)
* **Admin CMS:** Web-based control to publish announcements, manage public directory entries, edit job/scholarship notices, and upload event banners without code updates.
* **Notifications:** Send push notifications (English/Tamil translations) for emergency blood requests, issue updates, and club announcements.

### 6.6. Future Phase Modules (Phases 2 & 3)
* **Opportunity Hub (Phase 2):** Scrapers and data aggregation tools to pull public exam announcements (TNPSC, UPSC, Banking), scholarships, and government schemes.
* **Green FYC (Phase 2):** Geo-tagged tree registration, growth photos, and carbon absorption statistics dashboard.
* **Offline Sync Engine (Phase 2):** Sqlite sync system in Flutter for offline directory lookup and caching of local issue registrations.
* **Document Repository (Phase 3):** Document repository for storing official club constitutions, meeting minutes, and financial transparency audits.
