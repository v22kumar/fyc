# FYC Connect - Product Planning & Architecture Specification

Welcome to the **FYC Connect** planning and architecture workspace. This directory contains the complete product blueprint, functional specifications, system architecture designs, and development roadmap for digitally transforming the Friends Youth Club (FYC) community service platform.

---

## 📂 Project Planning Deliverables

The documentation is organized into the following modules. Click on any file link below to view the detailed specifications:

### 1. 📋 [Product Requirements Document (PRD)](file:///c:/WorkStation/FYC_Connect/docs/01_product_requirements_document.md)
* **Executive Summary:** FYC history, vision, and digital transformation goals.
* **User Personas:** Detailed profiles of stakeholders (Citizens, Volunteers, Club Members, Admin).
* **Roles & Permissions Matrix (RBAC):** Permission mappings across all 7 user types.
* **Product Success Metrics (KPIs):** Measurable targets for user acquisition, donors, issues, trees, and events.

### 2. ⚙️ [Functional Specifications](file:///c:/WorkStation/FYC_Connect/docs/02_functional_specifications.md)
* **Multi-Platform Boundaries:** Astro Public Website, Flutter Mobile App, and Next.js Admin Portal.
* **Detailed Workflows:** Public Issue Lifecycle state machine and Volunteer Management / Membership processes.
* **Bilingual Architecture:** Details on localizing forms, labels, error messages, and notifications using Tamil/English translation keys.
* **Screen & Navigation Map:** Grid of screens and global navigation flow matching mockup visual designs.

### 3. 🏗️ [System Architecture & Design](file:///c:/WorkStation/FYC_Connect/docs/03_system_architecture.md)
* **System Context Diagram:** High-level interactions using Mermaid diagrams.
* **Database Entity Design (ERD):** Fully normalized PostgreSQL schema supporting Multi-Organization Tenancy, Geographic Hierarchy, and Audit Trails.
* **API Contract Specification:** FastAPI REST API contracts and OpenAPI request/response schema specifications.
* **Security & Auth Model:** OAuth2, JWT token flow, role-based database constraints, and row-level tenant security.
* **Deployment Architecture:** Scalable Docker-Compose infrastructure on VPS.

### 4. 🗺️ [Project Roadmap & Scope](file:///c:/WorkStation/FYC_Connect/docs/04_project_roadmap.md)
* **MVP Scope (Phase 1):** Auth, Membership, Blood Donation, Public Issues, Event Management, Notifications, and Gallery.
* **Future Phases (Phase 2 & 3):** Opportunity Hub, Green FYC, Offline Sync Engine, Document Repository, and Advanced Analytics.
* **Technology Stack Details:** FastAPI, Flutter, Next.js, Astro, PostgreSQL.
* **Development Timeline:** Milestone breakdown, resource estimates, and key risks & mitigations.

---

## 🎨 Design Theme & Core Aesthetics

FYC Connect leverages a modern, responsive design theme tailored for community engagement:
* **Primary Color:** `#064e3b` (Forest Green - representing community growth and Green FYC).
* **Accent Color:** `#991b1b` (Crimson Red - representing Blood Donation and urgency).
* **Bilingual First:** Tamil is the primary default language, with a seamless toggle to English.
* **Clean Card Layouts:** Responsive mobile-first cards, soft shadows, rounded corners (`16px`), and high-contrast typography.
