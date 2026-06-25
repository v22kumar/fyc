# FYC Connect 🌍🏆

Welcome to the **FYC Connect (Friends Youth Club)** platform repository! 

FYC Connect is a comprehensive digital transformation suite built for community organizations to manage social initiatives, track volunteers, run sports tournaments (with live scoring), and foster civic engagement.

---

## 🏗️ System Architecture & Monorepo Structure

This project follows a modern microservice-oriented monorepo structure. It is divided into four primary applications, each tailored for a specific audience and purpose.

| Directory | Service | Technology Stack | Purpose |
| --- | --- | --- | --- |
| `backend/` | **Core API** | Python, FastAPI, PostgreSQL, SQLAlchemy | The central source of truth. Handles authentication, RBAC, business logic, and database interactions. |
| `admin/` | **Admin Dashboard** | Next.js 14, React, TailwindCSS, TypeScript | Secure internal dashboard for Super Admins and Executive Members to manage tournaments, approve community issues, and moderate users. |
| `mobile/` | **Mobile App** | Flutter, Dart, BLoC, Dio | Primary interface for Club Members and Volunteers. Features live cricket scoring, tournament creation, team registration, and community interactions. |
| `web/` | **Public Portal** | Astro.js, TailwindCSS | Blazing fast public-facing website for spectators and citizens to view live scores, report community issues, and learn about FYC. |

---

## ✨ Key Features

### 🏆 Sports Hub & Tournament Management
- **Intelligent Cricket Scoring:** A specialized, one-tap mobile-optimized scoring interface with automatic strike rotation, extras calculations, and undo capabilities.
- **End-to-End Workflow:** Club members can create `DRAFT` tournaments, admins approve them, teams register via the mobile app, and fixtures are automatically generated.
- **Live Sync:** Ball-by-ball updates are instantly synchronized to the Astro public web portal for remote spectators.

### 🤝 Community & Social Initiatives
- **Issue Reporting:** Citizens can report local civic issues (potholes, streetlights) via the web.
- **Blood Donation Registry:** A searchable registry to connect donors in emergencies.
- **Tree Plantation Tracking:** Geotagged tracking of saplings planted by volunteers.
- **Volunteer Management:** Granular role-based access control (RBAC) assigning specific permissions to citizens, verified volunteers, executive members, and admins.

---

## 🚀 Quick Start Guide

To run this project locally, you will need **Python 3.10+**, **Node.js 18+**, **PostgreSQL**, and the **Flutter SDK**.

### 1. Database Setup
1. Create a local PostgreSQL database named `fyc`.
2. Ensure you have the `DATABASE_URL` ready (e.g., `postgresql://postgres:password@localhost:5432/fyc`).

### 2. Backend (FastAPI)
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install poetry
poetry install
# Run migrations
alembic upgrade head
# Start server
uvicorn app.main:app --reload --port 8000
```
> The API will be available at `http://localhost:8000/docs`.

### 3. Admin Portal (Next.js)
```bash
cd admin
npm install
npm run dev
```
> The Admin dashboard will be available at `http://localhost:3000`.

### 4. Web Portal (Astro)
```bash
cd web
npm install
npm run dev
```
> The public website will be available at `http://localhost:4321`.

### 5. Mobile App (Flutter)
```bash
cd mobile
flutter pub get
# Run on an emulator or connected device
flutter run
```

---

## 🔒 Authentication & Default Credentials

The platform uses JWT-based authentication. An `X-Organization-ID` header is required for all API requests to support multi-tenancy.

**Default Super Admin:**
- **Email:** `vrn2252@gmail.com`
- **Password:** `V22@kumar`
- *(These credentials will grant you full access across the Flutter App and Admin Panel.)*

---

## 🚢 Deployment

The entire stack is configured for seamless deployment to **Fly.io** using **GitHub Actions**.

- `.github/workflows/fly-deploy.yml`: Automatically builds and deploys the FastAPI backend container to Fly.io on `push` to `main`.
- `.github/workflows/admin-deploy.yml`: Automatically builds and deploys the Next.js Admin Panel to Fly.io.

Static assets (like the Android APK) are securely managed and routed directly via the backend API.

---

## 📄 License

© 2026 Friends Youth Club. All Rights Reserved.
