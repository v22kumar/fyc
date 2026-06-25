# FYC Connect – Product Experience & User Journey Review

## 1. User Journey Analysis

### Level 1 – Citizen (Public User)
*A citizen is someone living in the community who interacts with FYC but isn't an official member.*

- **Why install the app?** To stay informed about local happenings (sports, events, emergencies) and to have a direct line to report civic issues.
- **Why return?** Checking the status of an issue they reported, watching live local cricket scores, or responding to urgent community needs (e.g., blood donation requests).
- **Problems solved:** Provides a centralized, trusted local hub rather than relying on fragmented WhatsApp groups or Facebook posts.
- **What’s missing?** A public emergency broadcast feature (e.g., cyclone warnings) and a localized "community wall" for open discussions.
- **First thing they should see:** A personalized "Happening Now" feed (Live Scores, Urgent Blood Needs, Upcoming Weekend Events).
- **Permissions:** Read-only access to public events, live scores, and announcements. Write access for submitting civic issues and registering for open events.
- **Never visible:** Internal club management, draft tournaments, volunteer tracking dashboards, and administrative approvals.
- **Simplifying workflow:** Civic issue reporting should be a 2-tap process: Take a photo -> Auto-detect location -> Submit. No login required, just phone number verification.

### Level 2 – Club Member / Volunteer
*A verified club member who actively participates in FYC activities.*

- **Why install the app?** It’s the primary tool for coordinating their involvement in the club.
- **Why return?** To see their volunteer schedule, register their sports teams, and track their personal contribution metrics.
- **Problems solved:** Eliminates the chaos of managing team registrations and volunteer sign-ups through WhatsApp messages. 
- **What’s missing?** A "Member Profile" showcasing their impact (e.g., hours volunteered, trees planted, matches played). 
- **First thing they should see:** "Your Action Items" (e.g., "Your team's match is tomorrow at 9 AM", "You are assigned to water trees this Sunday").
- **Permissions:** Can create draft tournaments, register teams, sign up for volunteer slots, and enter live scores (if assigned as scorer).
- **Never visible:** System settings, role management, or ability to publish/delete official events.
- **Simplifying workflow:** One-tap RSVP to volunteer for an event. Automatically syncing their registered match fixtures to their phone's native calendar.

### Level 3 – Club Manager / Event Organizer
*The operational engine of the club, coordinating events and volunteers.*

- **Why install the app?** To manage logistics, communicate with participants, and track event success on the go.
- **Why return?** Daily management tasks—approving teams, updating fixture results, dispatching volunteers to reported civic issues.
- **Problems solved:** Centralizes operations. Currently, managers likely spend hours cross-referencing spreadsheets and WhatsApp messages.
- **What’s missing?** Bulk communication tools (e.g., "Send push notification to all captains in the Cricket Tournament").
- **First thing they should see:** A "Needs Attention" dashboard (Pending team approvals, Unresolved civic issues, Draft tournaments awaiting review).
- **Permissions:** Edit/Publish tournaments, manage fixtures, assign scorers, resolve civic issues, and moderate photo galleries.
- **Never visible:** Super admin settings (modifying core application configurations or deleting the organization).
- **Simplifying workflow:** Auto-generate round-robin fixtures with a single button press. Provide pre-written templates for announcements and event descriptions (partially implemented for tournaments).

### Level 4 – Admin / Leadership
*The strategic leaders guiding the organization's vision.*

- **Why install the app?** To monitor the overarching health, impact, and transparency of the organization.
- **Why return?** Reviewing monthly impact reports, granting high-level approvals, and tracking community growth.
- **Problems solved:** Provides objective data (KPIs) on club performance rather than anecdotal evidence.
- **What’s missing?** Automated monthly impact generation (e.g., "In May, FYC resolved 12 issues, planted 50 trees, and engaged 200 youths in sports").
- **First thing they should see:** High-level metrics: Active Volunteers, Total Community Issues Resolved, Funds/Resources Utilization.
- **Permissions:** Unrestricted access. Can manage roles, configure application settings, and view all audit logs.
- **Simplifying workflow:** Automated generation of PDF reports that can be directly shared with local government officials or sponsors.

---

## 2. Cross-Role Analysis & Permission Model

- **Are permissions correct?** The recent update allowing Club Members to create `DRAFT` tournaments (pending Manager approval) is excellent. It encourages grassroots initiative while maintaining quality control. 
- **Confusing Workflows:** The transition between Web, Flutter, and Admin Panel can be disjointed. For instance, requiring scorers to open a web browser from Flutter to score a cricket match is a functional bridge, but native integration would feel more premium.
- **Unnecessary Approvals:** If a tournament is explicitly marked as "Open Registration," team approvals should be completely automated until the maximum team limit is reached, removing the Manager's burden.
- **Intuitive Navigation:** The app needs a unified "Bottom Navigation Bar" for all roles, dynamically showing tabs based on role (e.g., Citizens see: Home, Sports, Report Issue. Managers see: Home, Sports, Manage, Approvals).

---

## 3. Real-World Workflow Review

1. **Reporting a Pothole:** Currently straightforward, but needs push notifications updating the citizen when the status changes from `PENDING` -> `IN_PROGRESS` -> `RESOLVED`. Without this, citizens feel their report went into a black hole.
2. **Blood Donation:** Needs an "Urgent Blast" feature. When a request is made, a push notification should bypass the standard feed and immediately alert users with matching blood types within a 10km radius.
3. **Draft Tournament Creation:** The markdown templates significantly speed this up. The missing link is an automated push notification to the Manager saying "New Draft Tournament requires approval."
4. **Scoring a Live Match:** The 1-tap web scorer is highly efficient. However, spectators relying on 3-second HTTP polling on the Astro site will drain server resources during high-traffic matches.

---

## 4. Engagement & Retention Strategy

To transform FYC Connect from a utility into a daily habit:
- **Gamification & Badges:** Award digital badges for "Civic Hero" (reported 5 resolved issues), "Green Thumb" (planted 10 trees), or "Sports MVP." 
- **Personalized Push Notifications:** "Your team plays in 2 hours!" or "A blood donor is urgently needed at City Hospital."
- **Community Leaderboards:** Display top volunteers of the month on the public web portal to foster healthy competition and recognition.
- **Rich Media Galleries:** Allow members to upload photos to a shared "Tournament Gallery" that citizens can swipe through.

---

## 5. Dashboard & Analytics Recommendations

**For Managers:**
- **Operational Dashboard:** Real-time metrics on pending registrations, unassigned fixtures, and open civic issues categorized by severity.

**For Leadership (Admins):**
- **Impact Analytics:** Visual charts showing the Month-over-Month growth in civic issues resolved, active volunteer hours, and spectator engagement during tournaments.
- **Audit Logs:** A security dashboard showing who approved which teams, changed match results, or elevated user roles.

---

## 6. Prioritized Roadmap

### 🔴 High Priority (Immediate Usability & Adoption)
1. **Push Notifications Infrastructure:** Implement Firebase Cloud Messaging (FCM) to alert citizens of issue resolutions, alert managers of pending approvals, and alert players of match timings.
2. **One-Tap Civic Reporting:** Allow citizens to report issues via Flutter without forcing an account creation (use anonymous device IDs or just phone OTP).
3. **Automated "Open" Registrations:** Update backend logic to automatically approve teams for "Open" tournaments until `max_teams` is hit.

### 🟡 Medium Priority (Efficiency & Management)
1. **Native Flutter Cricket Scorer:** Port the React-based one-tap scorer into a native Flutter screen to avoid bouncing users to a web browser.
2. **WebSocket Live Scoring:** Replace HTTP short-polling on the Astro Web portal with WebSockets (Socket.io/FastAPI WebSockets) to reduce server load and provide true sub-second real-time updates.
3. **Automated Fixture Generation UI:** Ensure the admin panel's "Generate Fixtures" button supports complex routing (e.g., balancing Byes in Knockout formats).

### 🟢 Future Enhancements (Growth & Scale)
1. **Automated Impact Reports:** Auto-generate monthly PDF newsletters summarizing FYC's impact to share with local sponsors.
2. **Emergency Blood Donor Proximity Blasts:** Use geolocation to ping users when an urgent blood request matches their profile nearby.
3. **Volunteer Gamification Profile:** A dedicated screen showing badges, hours volunteered, and event attendance streaks.

---
*By focusing on these workflow optimizations and engagement strategies, FYC Connect will evolve from a digital filing cabinet into the living, breathing heartbeat of the community.*
