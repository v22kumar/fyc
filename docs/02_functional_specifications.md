# Functional Specifications - FYC Connect

## 1. Multi-Platform System Boundaries

The system is separated into three distinct frontend applications, all consuming the unified Python FastAPI backend.

```
                  ┌──────────────────────────────┐
                  │    Astro Public Website      │
                  │   (SEO, Anonymous Users)     │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
┌────────────────────────┐  ┌──────────┐  ┌────────────────────────┐
│   Flutter Mobile App   │  │ FastAPI  │  │   Next.js Admin Portal │
│(Citizens & Volunteers) ├──►  Backend ◄──┤(Admins & Executives)   │
└────────────────────────┘  └────┬─────┘  └────────────────────────┘
                                 │
                                 ▼
                    ┌──────────────────────────┐
                    │   PostgreSQL Database    │
                    └──────────────────────────┘
```

### 1.1. Astro Public Website (SEO Focused, Zero-Install)
* **Access Level:** Anonymous Public Users.
* **Core Pages:** Home (Hero, Achievements, Core Values), About (History, Constitution overview), Gallery, Directory Lookup, Opportunity Hub (read-only), Public Issue Submission, Blood Donor Search.
* **Behavior:** static files compiled server-side (SSG/ISR) for optimal Google search indexing. Dynamic sections (like blood donor search and issue submission) use client-side hydration (Astro islands) to call FastAPI.

### 1.2. Flutter Mobile Application (Android/iOS)
* **Access Level:** Registered Citizens, Volunteers, Club Members, and Executives.
* **Core Features:** Auth, Digital Membership Card, Quick Access Grid, Blood Donor Requests & Contact (deep-links), Public Issue Reporting & Status Tracking, Volunteer Dashboard (Task Assignment, Status update), Gallery upload.
* **Behavior:** Dynamic, rich local caching (ready for Phase 2 offline sync). Accent colors follow the Forest Green `#064e3b` theme.

### 1.3. Next.js Admin Portal (Desktop Web)
* **Access Level:** Executives, Administrators, and Super Administrators.
* **Core Features:** Multi-Tenant Org Switcher, User Management (Verify Citizens, Approve Club Members, Upgrade Volunteers), Public Issue Triage (Status mapping, Volunteer assignments), CMS Manager (Publish Announcements, Edit Directory, Upload Event Banners), Financial ledger, Audit log explorer.
* **Behavior:** Responsive dashboard layouts built with Tailwind CSS, supporting advanced sorting, pagination, and file exports (CSV, PDF).

---

## 2. Screen List

### 2.1. Flutter Mobile Application Screen List
1. **Splash & Language Selection Screen:** Toggle between English and Tamil (primary) with zero-state introduction animations.
2. **OTP Login / Registration Screen:** Dual-language input fields for mobile number, name, and role preference (Citizen/Volunteer).
3. **Home Dashboard Screen (mockup representation):**
   * *Header:* "வணக்கம்! / Vanakkam!" greeting with notification bell.
   * *Hero Carousel:* Banners showcasing active drives (e.g., "Together We Build Better Tomorrow" seedling illustration).
   * *Quick Access Grid:* Blood Donation, Public Issues, Directory, Opportunity Hub, Events, Gallery.
   * *Metrics Banner:* 1500+ Trees, 1200+ Donors, 80+ Events, 5000+ Impacted.
   * *Bottom Tabs:* Home, Updates, Plus (+) Quick Actions, WhatsApp Chats, Profile.
4. **Blood Donation Hub Screen:**
   * Red Banner: "இரத்த தானம் - உங்கள் சிறிய உதவி ஒரு உயிரைக் காப்பாற்றலாம்".
   * Action Cards: "Donor Registration" (உறுப்பினர் பதிவு) and "Blood Request" (இரத்தம் தேவை).
   * Filter Bar: Horizontal buttons for blood types (`A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`).
   * Donor Directory: Scrollable card list showing Name, Location, call button, and WhatsApp deep-link icon (as seen in the mockup for Karthik J, Meena R, Vijay S).
5. **Report Public Issue Screen:** Camera interface for taking issue photo, category selection dropdown (Road, Water, Streetlight, Garbage, Safety), description text area, automatic GPS coordinates retrieval, and confirmation dialog.
6. **My Reported Issues / Track Status Screen:** Chronological list of logged issues with color-coded status pills:
   * *Submitted:* Blue
   * *Assigned:* Purple
   * *Under Review:* Orange
   * *Resolved:* Green
7. **Digital Membership Card Screen:** Displays member name, active designation (e.g., President, Member), photo, unique QR code, and validity dates with a glossy glassmorphic card design.
8. **Volunteer Task Dashboard Screen:** Displays tasks assigned to the volunteer, task detail pages, check-in/out button, and resolution submission panel.
9. **Updates & Announcement Feed Screen:** Dynamic scrollable feed showing announcements, directory details, upcoming events, and opportunity listings.

### 2.2. Astro Public Website Page List
1. **Landing Home Page:** Rich SEO content, core statistics, quick button to "Submit a Public Issue" or "Search Blood Donors".
2. **About FYC Page:** History from 1998, core milestones, structure, and values.
3. **Public Directory Page:** Interactive searchable grid of Tamil Nadu government office emergency contacts, hospitals, schools.
4. **Opportunity Hub Page:** Dynamic public feed of government exams (TNPSC, UPSC), banking, scholarships, job updates.
5. **Anonymous Blood Search Page:** Search tool that displays donor names, blood groups, and locations, but masks contact numbers behind an "Install App/Login to Request Contact" button.
6. **Web Public Issue Submission Page:** Form allowing citizens to submit local public safety issues directly from their browsers without downloading the mobile application.

### 2.3. Next.js Admin Portal Screen List
1. **Multi-Tenant Login Screen:** Admin login with organization ID domain matching.
2. **Main Dashboard:** Overview of issues logged/resolved, active donors, active volunteers, total members, event timelines, and system audits.
3. **Member Directory & Approval Screen:** Management table of registration requests with "Approve", "Reject", or "Assign Designation" controls.
4. **Issue Management Triage Panel:** Board/Table layout showing reported issues. Includes a map showing issue coordinates, volunteer matching dropdown, escalation options, and comments log.
5. **Volunteer Skill Registry Screen:** Manage volunteer hours, search volunteers by skills matrix, review activity history, and generate digital certificates.
6. **CMS Content Editor Screen:** Rich text editors for creating announcements, editing government emergency directories, posting opportunity updates, and managing mobile event banners.
7. **System Audit Logs Screen:** Read-only datagrid showing system-wide activities: login events, donor contact extraction logs, status change details, and tenant configurations.

---

## 3. Navigation & User Journey Map

```
                  ┌──────────────────────┐
                  │ Splash & Lang Selection│
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │    Mobile OTP Auth   │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │    Home Dashboard    │
                  └─────┬──────────┬─────┘
                        │          │
         ┌──────────────┘          └──────────────┐
         ▼                                        ▼
┌──────────────────┐                     ┌──────────────────┐
│   Quick Access   │                     │   Bottom Tabs    │
└────────┬─────────┘                     └────────┬─────────┘
         │                                        │
         ├─► Blood Donation                       ├─► Home
         ├─► Public Issues                        ├─► Updates / Feed
         ├─► Public Directory                     ├─► Quick Action (+)
         ├─► Opportunity Hub                      ├─► WA Community Link
         ├─► Events & Gallery                     └─► Member Profile (ID)
         └─► Members Directory
```

---

## 4. Enhanced Workflows

### 4.1. Public Issue Workflow State Machine (SNO-008)

```
       ┌──────────────┐
       │   New/Subm   │◄─────────────────────────────┐ (Resubmit)
       └──────┬───────┘                              │
              │ (Admin Triage / Assign)              │
              ▼                                      │
       ┌──────────────┐                              │
       │   Assigned   ├──────────────────────┐       │
       └──────┬───────┘                      │       │
              │                              │       │
              ▼ (On-Site Verification)       │       │
       ┌──────────────┐                      │       │
  ┌───►│ Under Review │                      │       │
  │    └──────┬───────┘                      │       │
  │           │ (Request Action)             │       │
  │           ▼                              │       │
  │    ┌──────────────┐                      │       │
  │    │  Escalated   │                      │       │
  │    └──────┬───────┘                      │ (Reject / Span)
  │           │                              ▼
  │           │ (Resolved)            ┌──────────────┐
  │           └──────────────────────►│   Rejected   │
  │                                   └──────────────┘
  │ (Reopen)                                 ▲
  ├──────────────────────────────────────────┤
  │                                          │ (Verify / Confirm)
  │           ┌──────────────┐               ▼
  └───────────┤   Resolved   ├────────►┌──────────────┐
              └──────────────┘         │    Closed     │
                                       └──────────────┘
```

* **Workflow Rules:**
  1. **Anonymous Submission:** Citizen creates issue → Saved as `New`. Automated notifications sent to local area volunteers.
  2. **Assignment:** Executive Member assigns to a specific Volunteer → Status transitions to `Assigned`.
  3. **Verification:** Volunteer inspects the site and changes status to `Under Review`.
  4. **Escalation:** If the issue requires government involvement (e.g., local corporate department), volunteer tags it as `Escalated`.
  5. **Resolution:** Volunteer resolves issue, uploads proof photo → Status changes to `Resolved`.
  6. **Closure:** Administrator reviews verification photo, closes issue → Status changes to `Closed`. If the resolution is poor, Admin can re-open to `Under Review`.
  7. **Spam Triage:** Admin can transition `New` or `Assigned` to `Rejected` at any time if it is spam or outside service boundaries.

### 4.2. Volunteer Management & Hours Ledger (SNO-004)
* **Registration:** Volunteers select "Volunteer" during registration and select skills (e.g., Blood drive coordinator, Environment planter, First Aid responder, Content writer).
* **Hours Ledger Calculation:**
  * When joining an event (e.g., Blood donation camp), the volunteer checks in via QR code.
  * When the event ends, check-out calculates `Volunteering Hours = Checkout Time - Checkin Time`.
  * System updates volunteer metadata: `Accrued Hours`, `Completed Activities`.
* **Digital Certificates:** Once a volunteer achieves milestone hours (e.g., 25, 50, 100 hours), the admin portal generates a digital certificate:
  * PDF compiled on-the-fly containing Name, Tenant Organization, Hours, and a secure validation QR code pointing to the public website validation URL (`https://fycconnect.org/verify/cert/<uuid>`).

---

## 5. Bilingual Localization Architecture (SNO-017)

### 5.1. Database Translation Key Schema
Rather than storing hardcoded Tamil/English text fields, localizable content (Announcement content, Directory labels, Hub categories) utilizes a standard localization JSON structure in PostgreSQL:
```json
{
  "tn_upsc_group4": {
    "title": {
      "ta": "TNPSC குரூப் 4 தேர்வு",
      "en": "TNPSC Group 4 Examination"
    },
    "description": {
      "ta": "விண்ணப்பிக்க கடைசி தேதி: 15 மே 2024. தகுதி: 10வது வகுப்பு.",
      "en": "Last date to apply: 15 May 2024. Eligibility: 10th Standard."
    }
  }
}
```

### 5.2. Localization Integration Strategy
1. **API Localization Negotiation:** All HTTP requests from frontends pass the `Accept-Language` header (e.g., `Accept-Language: ta` or `Accept-Language: en`). FastAPI backend intercepts this and returns fields matching the requested language, falling back to Tamil (`ta`) if unspecified.
2. **Static Label Localization (JSON files):** UI labels, error messages, and forms use key-based mapping.
   * `ta.json`:
     ```json
     {
       "dashboard.title": "வணக்கம்!",
       "blood.register_as_donor": "குருதி தானம் செய்ய விரும்புகிறேன்",
       "error.validation_failed": "உள்ளீடு தவறானது, மீண்டும் சரிபார்க்கவும்"
     }
     ```
   * `en.json`:
     ```json
     {
       "dashboard.title": "Vanakkam!",
       "blood.register_as_donor": "Register as Donor",
       "error.validation_failed": "Validation failed, please check inputs"
     }
     ```
3. **Local Push Notifications:** Backend pushes localized payloads based on the user's stored language preference (`ta`/`en`) in their profile table.
